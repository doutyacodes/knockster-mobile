<?php
/**
 * MASTER SNOOZE REMINDER CRON (RUNS EVERY MINUTE)
 * Includes:
 * - DB connection
 * - FCM notification service
 * - Snooze reminder processor
 * - Escalation logic for max snoozes
 *
 * CRON:
 * * * * * /usr/bin/php /path/to/snooze-reminder-cron.php >> /var/log/snooze.log 2>&1
 */

date_default_timezone_set('UTC');

// 🔹 1) DATABASE CONNECTION
$pdo = new PDO(
    "mysql:host=localhost;dbname=devuser_knockster_safety;charset=utf8mb4",
    "devuser_knockster_safety",
    "devuser_knockster_safety",
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);


// 🔹 2) FIREBASE — PUSH NOTIFICATIONS
require_once __DIR__ . "/vendor/autoload.php";
use Kreait\Firebase\Factory;

$firebase = (new Factory)->withServiceAccount(__DIR__ . "/firebase/firebase-key.json");
$messaging = $firebase->createMessaging();

function sendToDevice($deviceToken, $title, $body, $data = []) {
    global $messaging;
    try {
        $messaging->send([
            'token' => $deviceToken,
            'notification' => ['title' => $title, 'body' => $body],
            'data' => array_map('strval', $data)
        ]);
        return true;
    } catch (Throwable $e) {
        return $e->getMessage();
    }
}

function sendToUser($userId, $title, $body, $data = []) {
    global $pdo;
    $stmt = $pdo->prepare("SELECT device_token FROM user_devices WHERE user_id = :uid AND is_active = 1");
    $stmt->execute([':uid' => $userId]);
    $devices = $stmt->fetchAll(PDO::FETCH_COLUMN);
    if (!$devices) return false;
    foreach ($devices as $token) sendToDevice($token, $title, $body, $data);
    return true;
}

function sendToAdminTopic($orgId, $title, $body, $data = []) {
    global $messaging;
    $topic = "org_{$orgId}_alerts";
    try {
        $messaging->send([
            'topic' => $topic,
            'notification' => ['title' => $title, 'body' => $body],
            'data' => array_map('strval', $data)
        ]);
        return true;
    } catch (Throwable $e) {
        return $e->getMessage();
    }
}


// 🔹 3) HELPER NOTIFICATION WRAPPERS
function sendSnoozeReminderNotif($checkin, $snoozeNumber, $remaining) {
    $title = "⏰ Check-in Reminder";
    $body = "Please complete your safety check-in ($remaining snoozes remaining)";
    return sendToUser($checkin['user_id'], $title, $body, [
        'type' => 'checkin_alert',
        'checkin_id' => (string)$checkin['id']
    ]);
}

function sendNoResponseAdminAlert($checkinId, $orgId, $userName, $alertId) {
    $title = "🚨 No Response Alert";
    $body = "$userName has not responded after 3 snoozes";
    return sendToAdminTopic($orgId, $title, $body, [
        'type' => 'admin_alert',
        'alert_id' => (string)$alertId,
        'alert_type' => 'no_response_after_snooze',
        'priority' => 'high'
    ]);
}


// 🔹 4) START JOB
echo "🔔 Running snooze reminder job...\n";

try {
    $fiveMinutesAgo = date("Y-m-d H:i:s", time() - 5 * 60);

    // Find snoozed check-ins needing reminders
    $stmt = $pdo->prepare("
        SELECT * FROM safety_checkins
        WHERE status = 'snoozed'
          AND last_snooze_at <= :time
    ");
    $stmt->execute([':time' => $fiveMinutesAgo]);
    $list = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo "📋 Found " . count($list) . " check-ins to process\n";

    foreach ($list as $checkin) {
        try {
            $snoozeCount = $checkin['snooze_count'];

            if ($snoozeCount >= 3) {
                // 5) ESCALATE
                echo "🚨 Max snoozes reached — escalating {$checkin['id']}\n";

                // Update status
                $pdo->prepare("
                    UPDATE safety_checkins
                    SET status = 'escalated_no_response', updated_at = NOW()
                    WHERE id = :id
                ")->execute([':id' => $checkin['id']]);

                // Create alert
                $pdo->prepare("
                    INSERT INTO safety_alerts(checkin_id, user_id, org_id, alert_type, priority, alert_status, alert_sent_at)
                    VALUES (:cid, :uid, :oid, 'no_response_after_snooze', 'high', 'pending', NOW())
                ")->execute([
                    ':cid' => $checkin['id'],
                    ':uid' => $checkin['user_id'],
                    ':oid' => $checkin['org_id']
                ]);
                $alertId = $pdo->lastInsertId();

                // Fetch user name for alert message
                $stmtU = $pdo->prepare("
                    SELECT COALESCE(user_profiles.full_name, 'Unknown User') AS full_name
                    FROM users
                    LEFT JOIN user_profiles ON users.id = user_profiles.user_id
                    WHERE users.id = :uid
                ");
                $stmtU->execute([':uid' => $checkin['user_id']]);
                $userName = $stmtU->fetchColumn();

                sendNoResponseAdminAlert($checkin['id'], $checkin['org_id'], $userName, $alertId);
                echo "📨 Admin alert sent for {$checkin['id']}\n";
                continue;
            }

            // 6) SEND SNOOZE REMINDER
            $remaining = 3 - $snoozeCount;
            echo "📱 Sending snooze reminder " . ($snoozeCount + 1) . " for {$checkin['id']}\n";

            $sent = sendSnoozeReminderNotif($checkin, $snoozeCount + 1, $remaining);

            // Log snooze attempt
            $pdo->prepare("
                INSERT INTO safety_snooze_logs(checkin_id, snooze_number, sent_at, notification_delivered)
                VALUES(:cid, :num, NOW(), :delivered)
            ")->execute([
                ':cid' => $checkin['id'],
                ':num' => $snoozeCount + 1,
                ':delivered' => $sent ? 1 : 0
            ]);

            echo "✅ Snooze reminder logged\n";

        } catch (Throwable $e) {
            echo "❌ Error processing checkin {$checkin['id']}: {$e->getMessage()}\n";
        }
    }

    echo "✔ Snooze reminder job complete\n\n";

} catch (Throwable $e) {
    echo "❌ Fatal job error: {$e->getMessage()}\n";
}
