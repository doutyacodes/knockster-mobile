<?php
/**
 * MASTER SAFETY CHECK-IN CRON (RUNS EVERY MINUTE)
 * This single file contains:
 * - DB connection
 * - FCM notification service
 * - Cron job to create check-ins
 * - Push alert trigger
 * - Snooze reminder + escalation alert helpers
 *
 * RUN VIA CRON EVERY MINUTE:
 * * * * * /usr/bin/php /path/to/safety-checkin-cron.php >> /var/log/safety.log 2>&1
 */

// -------------------------------------------
// 🔹 1) DATABASE CONNECTION
// -------------------------------------------
date_default_timezone_set('UTC'); // can change per-org if needed

$pdo = new PDO(
    "mysql:host=localhost;dbname=devuser_knockster_safety;charset=utf8mb4",
    "devuser_knockster_safety",
    "devuser_knockster_safety",
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);


// -------------------------------------------
// 🔹 2) FIREBASE — PUSH NOTIFICATION SERVICE
// -------------------------------------------
require_once __DIR__ . "/vendor/autoload.php";

use Kreait\Firebase\Factory;

$firebase = (new Factory)->withServiceAccount(__DIR__ . "/firebase/firebase-key.json");
$messaging = $firebase->createMessaging();

/**
 * Send notification to a device
 */
function sendToDevice($deviceToken, $title, $body, $data = [])
{
    global $messaging;

    try {
        $message = [
            'token' => $deviceToken,
            'notification' => [
                'title' => $title,
                'body'  => $body
            ],
            'data' => array_map('strval', $data)
        ];
        $messaging->send($message);
        return true;
    } catch (Throwable $e) {
        return $e->getMessage();
    }
}

/**
 * Send notification to all active devices of a user
 */
function sendToUser($userId, $title, $body, $data = [])
{
    global $pdo;

    $stmt = $pdo->prepare("SELECT device_token FROM user_devices WHERE user_id = :uid AND is_active = 1");
    $stmt->execute([':uid' => $userId]);
    $devices = $stmt->fetchAll(PDO::FETCH_COLUMN);

    if (!$devices) return ['success' => false, 'message' => 'No devices'];

    $success = 0;
    foreach ($devices as $token) {
        $result = sendToDevice($token, $title, $body, $data);
        if ($result === true) $success++;
    }

    return ['success' => $success > 0];
}

/**
 * Log notification record
 */
function logNotification($checkinId, $userId, $type, $status, $error = null)
{
    global $pdo;

    $stmt = $pdo->prepare("
        INSERT INTO notification_logs(checkin_id, user_id, notification_type, delivery_status, error_message, sent_at)
        VALUES(:cid, :uid, :type, :status, :error, NOW())
    ");

    $stmt->execute([
        ':cid' => $checkinId,
        ':uid' => $userId,
        ':type' => $type,
        ':status' => $status,
        ':error' => $error
    ]);
}

/**
 * Primary notification used in job
 */
function sendCheckinAlert($userId, $checkinId, $label, $scheduledTime)
{
    $title = "⏰ Safety Check-in Required";
    $body = "Time for your $label check-in";

    $result = sendToUser($userId, $title, $body, [
        'type' => 'checkin_alert',
        'checkin_id' => (string)$checkinId,
        'label' => $label,
        'scheduled_time' => $scheduledTime
    ]);

    logNotification($checkinId, $userId, "initial_checkin", $result["success"] ? "sent" : "failed");
}


// -------------------------------------------
// 🔹 3) CHECK-IN CRON JOB
// -------------------------------------------
echo "🕐 Running safety check-in job...\n";

try {
    $now = new DateTime();
    $currentTime = $now->format("H:i");
    $currentDay = strtolower($now->format("l"));
    $today = $now->format("Y-m-d");

    echo "⏰ $currentTime | $currentDay\n";

    $stmt = $pdo->prepare("
        SELECT * FROM safety_timings
        WHERE is_active = 1
          AND DATE_FORMAT(time,'%H:%i') = :time
    ");
    $stmt->execute([':time' => $currentTime]);

    $timings = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($timings as $timing) {
        try {
            $activeDays = json_decode($timing["active_days"], true);
            if (!in_array($currentDay, $activeDays)) continue;

            // Prevent duplicate for today
            $stmt2 = $pdo->prepare("
                SELECT id FROM safety_checkins
                WHERE user_id = :uid AND timing_id = :tid AND checkin_date = :cd
                LIMIT 1
            ");
            $stmt2->execute([
                ':uid' => $timing['user_id'],
                ':tid' => $timing['id'],
                ':cd' => $today
            ]);

            if ($stmt2->fetch()) continue;

            // Create new check-in
            $stmt3 = $pdo->prepare("
                INSERT INTO safety_checkins(user_id, timing_id, org_id, checkin_date, scheduled_time, status, snooze_count)
                VALUES(:uid, :tid, :org, :cd, :st, 'pending', 0)
            ");
            $stmt3->execute([
                ':uid' => $timing['user_id'],
                ':tid' => $timing['id'],
                ':org' => $timing['org_id'],
                ':cd' => $today,
                ':st' => $timing['time']
            ]);

            $checkinId = $pdo->lastInsertId();
            echo "➕ Created check-in $checkinId for user {$timing['user_id']}\n";

            // Push alert
            sendCheckinAlert($timing['user_id'], $checkinId, $timing['label'], $timing['time']);
            echo "📨 Alert sent\n";

        } catch (Throwable $e) {
            echo "⛔ Error in timing {$timing['id']}: {$e->getMessage()}\n";
        }
    }

    echo "✔ Job finished\n\n";

} catch (Throwable $e) {
    echo "❌ Cron failure: {$e->getMessage()}\n";
}
