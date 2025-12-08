# Missing Backend Implementation Requirements

This document outlines the **essential backend features** that need to be implemented to complete the Knockster safety check-in system with Firebase Cloud Messaging (FCM) support.

---

## 🔥 CRITICAL: Firebase Cloud Messaging Integration

### 1. Firebase Admin SDK Setup

**File**: `lib/firebase-admin.js` or similar

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

module.exports = admin;
```

**Requirements:**
- Install `firebase-admin` package: `npm install firebase-admin`
- Download Firebase service account key from Firebase Console
- Add to `.gitignore` to keep credentials secure

---

## 📱 1. Device Token Registration Endpoint

**Status**: ❌ **MISSING**

### Endpoint: `POST /api/mobile-api/devices/register`

**Purpose**: Register or update user's device FCM token for push notifications

**Request Body**:
```json
{
  "user_id": 123,
  "device_token": "fcm_token_string_here",
  "device_type": "android" // or "ios"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Device token registered successfully"
}
```

**Implementation Logic**:
1. Check if device token already exists for this user
2. If exists, update `last_used_at` and `is_active = true`
3. If not exists, insert new record
4. Mark other devices for same user as `is_active = false` (optional: single device per user)
5. Use `USER_DEVICES` table from schema

**Database Table** (Already in schema):
```javascript
export const USER_DEVICES = mysqlTable("user_devices", {
  id: int("id").primaryKey().autoincrement(),
  user_id: int("user_id").notNull(),
  device_token: varchar("device_token", { length: 255 }).notNull(),
  device_type: mysqlEnum("device_type", ["ios", "android"]).notNull(),
  device_name: varchar("device_name", { length: 100 }),
  is_active: boolean("is_active").default(true).notNull(),
  last_used_at: timestamp("last_used_at").defaultNow(),
  created_at: timestamp("created_at").defaultNow(),
});
```

**File Location**: `mobile-api/devices/register/route.js`

---

## 🔔 2. Firebase Push Notification Service

**Status**: ❌ **MISSING**

### Service File: `services/push-notification-service.js`

**Purpose**: Send push notifications via FCM when safety alerts are triggered

**Key Functions**:

#### a) Send to Single Device
```javascript
async function sendToDevice(deviceToken, notification, data) {
  const message = {
    token: deviceToken,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: data,
    android: {
      priority: 'high',
      notification: {
        channelId: 'safety_checkin_channel',
        sound: 'default',
        priority: 'max',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          'content-available': 1,
        },
      },
    },
  };

  return await admin.messaging().send(message);
}
```

#### b) Send to User (All Devices)
```javascript
async function sendToUser(userId, notification, data) {
  // Get all active devices for user
  const devices = await db
    .select()
    .from(USER_DEVICES)
    .where(
      and(
        eq(USER_DEVICES.user_id, userId),
        eq(USER_DEVICES.is_active, true)
      )
    );

  const promises = devices.map(device =>
    sendToDevice(device.device_token, notification, data)
  );

  return await Promise.allSettled(promises);
}
```

#### c) Send to Topic (Admin Alerts)
```javascript
async function sendToTopic(topic, notification, data) {
  const message = {
    topic: topic,
    notification: {
      title: notification.title,
      body: notification.body,
    },
    data: data,
  };

  return await admin.messaging().send(message);
}
```

**Use Cases**:
1. **Initial Check-in Alert**: Send to user when scheduled check-in time arrives
2. **Snooze Reminders**: Send after 5 minutes if user snoozed
3. **Admin Alerts**: Send to all admins when danger PIN entered or no response
4. **Final Escalation**: Send after 3 snoozes with no response

---

## ⏰ 3. Scheduled Check-in Job/Cron

**Status**: ❌ **MISSING**

### Cron Job: Check and Trigger Alerts

**Purpose**: Automatically create check-ins and send notifications at scheduled times

**Implementation**: Use `node-cron` or similar

```javascript
const cron = require('node-cron');

// Run every minute
cron.schedule('* * * * *', async () => {
  console.log('🕐 Running safety check-in job...');

  const now = new Date();
  const currentTime = now.toTimeString().substring(0, 5); // "HH:MM"
  const currentDay = now.toLocaleDateString('en-US', { weekday: 'lowercase' }); // "monday"
  const today = now.toISOString().split('T')[0]; // "YYYY-MM-DD"

  // Find all active timings that match current time and day
  const timings = await db
    .select()
    .from(SAFETY_TIMINGS)
    .where(
      and(
        eq(SAFETY_TIMINGS.is_active, true),
        sql`TIME(${SAFETY_TIMINGS.time}) = ${currentTime}`
      )
    );

  for (const timing of timings) {
    const activeDays = JSON.parse(timing.active_days);

    if (!activeDays.includes(currentDay)) {
      continue; // Skip if not active today
    }

    // Check if check-in already created for today
    const existing = await db
      .select()
      .from(SAFETY_CHECKINS)
      .where(
        and(
          eq(SAFETY_CHECKINS.user_id, timing.user_id),
          eq(SAFETY_CHECKINS.timing_id, timing.id),
          sql`DATE(${SAFETY_CHECKINS.checkin_date}) = ${today}`
        )
      )
      .limit(1);

    if (existing.length > 0) {
      continue; // Already created
    }

    // Create new check-in
    const checkin = await db
      .insert(SAFETY_CHECKINS)
      .values({
        user_id: timing.user_id,
        timing_id: timing.id,
        org_id: timing.org_id,
        checkin_date: today,
        scheduled_time: timing.time,
        status: 'pending',
        snooze_count: 0,
      });

    const checkinId = checkin[0].insertId;

    // Send push notification
    try {
      await sendToUser(timing.user_id, {
        title: '⏰ Safety Check-in Required',
        body: `Time for your ${timing.label} check-in`,
      }, {
        type: 'checkin_alert',
        checkin_id: checkinId.toString(),
        label: timing.label,
        scheduled_time: timing.time,
      });

      // Log notification
      await db.insert(NOTIFICATION_LOGS).values({
        checkin_id: checkinId,
        user_id: timing.user_id,
        notification_type: 'initial_checkin',
        sent_at: new Date(),
        delivery_status: 'sent',
      });

      console.log(`✅ Check-in alert sent to user ${timing.user_id}`);
    } catch (error) {
      console.error(`❌ Failed to send notification: ${error.message}`);
    }
  }
});
```

**Requirements**:
- Install: `npm install node-cron`
- Run continuously (use PM2 or similar in production)
- Consider timezone handling for accurate scheduling

---

## 🚨 4. Snooze Reminder Job

**Status**: ❌ **MISSING**

### Cron Job: Send Reminders After Snooze

**Purpose**: Send reminders 5 minutes after user snoozes

**Implementation**:

```javascript
// Run every minute
cron.schedule('* * * * *', async () => {
  console.log('🔁 Running snooze reminder job...');

  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

  // Find all snoozed check-ins that need reminder
  const snoozedCheckins = await db
    .select()
    .from(SAFETY_CHECKINS)
    .where(
      and(
        eq(SAFETY_CHECKINS.status, 'snoozed'),
        sql`${SAFETY_CHECKINS.last_snooze_at} <= ${fiveMinutesAgo}`
      )
    );

  for (const checkin of snoozedCheckins) {
    const snoozeNumber = checkin.snooze_count;

    if (snoozeNumber >= 3) {
      // Max snoozes reached - escalate
      await escalateToAdmins(checkin);
    } else {
      // Send reminder
      try {
        await sendToUser(checkin.user_id, {
          title: '⏰ Check-in Reminder',
          body: `Please complete your safety check-in (${3 - snoozeNumber} snoozes remaining)`,
        }, {
          type: 'checkin_alert',
          checkin_id: checkin.id.toString(),
        });

        // Log snooze
        await db.insert(SAFETY_SNOOZE_LOGS).values({
          checkin_id: checkin.id,
          snooze_number: snoozeNumber + 1,
          sent_at: new Date(),
        });

        console.log(`✅ Snooze reminder sent for checkin ${checkin.id}`);
      } catch (error) {
        console.error(`❌ Failed to send snooze reminder: ${error.message}`);
      }
    }
  }
});

async function escalateToAdmins(checkin) {
  // Update check-in status
  await db
    .update(SAFETY_CHECKINS)
    .set({
      status: 'escalated_no_response',
      updated_at: new Date(),
    })
    .where(eq(SAFETY_CHECKINS.id, checkin.id));

  // Create critical alert
  const alert = await db
    .insert(SAFETY_ALERTS)
    .values({
      checkin_id: checkin.id,
      user_id: checkin.user_id,
      org_id: checkin.org_id,
      alert_type: 'no_response_after_snooze',
      priority: 'high',
      alert_status: 'pending',
      alert_sent_at: new Date(),
    });

  // Send to admin topic
  await sendToTopic(`org_${checkin.org_id}_alerts`, {
    title: '🚨 No Response Alert',
    body: `User has not responded after 3 snooze attempts`,
  }, {
    type: 'admin_alert',
    alert_id: alert[0].insertId.toString(),
    priority: 'high',
  });

  console.log(`🚨 Escalated checkin ${checkin.id} to admins`);
}
```

---

## 🛡️ 5. Danger PIN Alert (Already Partially Implemented)

**Status**: ⚠️ **NEEDS COMPLETION**

**Current**: Backend creates alert in `checkins/verify/route.js` (line 140)
**Missing**: Actually send push notification to admins

**Add to** `checkins/verify/route.js` after line 143:

```javascript
// Send push notification to admins
try {
  await sendToTopic(`org_${checkinData.org_id}_alerts`, {
    title: '🚨 CRITICAL: Danger PIN Entered',
    body: `A user has entered their danger PIN - immediate action required`,
  }, {
    type: 'admin_alert',
    alert_id: alertResult[0].insertId.toString(),
    alert_type: 'danger_pin_entered',
    priority: 'critical',
    user_id: checkinData.user_id.toString(),
  });

  console.log('✅ Admin alert sent successfully');
} catch (notifError) {
  console.error('❌ Failed to send admin notification:', notifError);
}
```

---

## 📊 6. API Endpoint: Get User's Org ID

**Status**: ⚠️ **NEEDED FOR ADMIN TOPIC SUBSCRIPTIONS**

### Endpoint: `GET /api/mobile-api/users/[userId]/organization`

**Purpose**: Get user's primary organization for topic subscription

**Response**:
```json
{
  "success": true,
  "data": {
    "org_id": 1,
    "org_name": "Acme Corp",
    "role": "org_admin"
  }
}
```

**File Location**: `mobile-api/users/[userId]/organization/route.js`

---

## 🔐 7. Firebase Configuration Files

**Status**: ❌ **MISSING**

### Files Needed:

1. **Backend**: `serviceAccountKey.json`
   - Download from Firebase Console → Project Settings → Service Accounts → Generate New Private Key
   - Add to `.gitignore`

2. **Flutter Android**: `android/app/google-services.json`
   - Download from Firebase Console → Android App → Download google-services.json

3. **Flutter iOS**: `ios/Runner/GoogleService-Info.plist`
   - Download from Firebase Console → iOS App → Download GoogleService-Info.plist

### Firebase Console Setup:
1. Create Firebase project at https://console.firebase.google.com
2. Add Android app (package name from `android/app/build.gradle`)
3. Add iOS app (bundle ID from Xcode)
4. Enable Cloud Messaging

---

## 🧪 8. Testing Endpoints

**Status**: ⚠️ **RECOMMENDED FOR DEVELOPMENT**

### Endpoint: `POST /api/mobile-api/test/send-notification`

**Purpose**: Manually trigger notification for testing

**Request**:
```json
{
  "user_id": 123,
  "type": "checkin_alert",
  "checkin_id": 456
}
```

**Use**: Testing notifications without waiting for scheduled times

---

## 📝 Implementation Priority

### Phase 1: CRITICAL (Must Have)
1. ✅ Device token registration endpoint
2. ✅ Firebase Admin SDK setup
3. ✅ Push notification service functions
4. ✅ Scheduled check-in job

### Phase 2: HIGH (Core Features)
5. ✅ Snooze reminder job
6. ✅ Complete danger PIN alert notification
7. ✅ Firebase config files

### Phase 3: MEDIUM (Enhancement)
8. ⚠️ Get user organization endpoint
9. ⚠️ Test notification endpoint
10. ⚠️ Notification delivery tracking & retry logic

---

## 🚀 Quick Start Commands

```bash
# Install required packages
npm install firebase-admin node-cron

# Create Firebase service file
touch lib/firebase-admin.js

# Create notification service
touch services/push-notification-service.js

# Create device registration endpoint
mkdir -p mobile-api/devices/register
touch mobile-api/devices/register/route.js

# Create cron jobs
touch jobs/safety-checkin-job.js
touch jobs/snooze-reminder-job.js

# Add to main server file
# Import and start cron jobs in server.js or app.js
```

---

## 📖 Additional Resources

- **Firebase Admin SDK Docs**: https://firebase.google.com/docs/admin/setup
- **FCM Send Messages**: https://firebase.google.com/docs/cloud-messaging/send-message
- **Node-Cron**: https://www.npmjs.com/package/node-cron
- **Drizzle ORM**: https://orm.drizzle.team/docs/overview

---

## ⚠️ Important Notes

1. **Security**: Never commit `serviceAccountKey.json` to version control
2. **Timezones**: Consider user timezones when scheduling (use `users.timezone` field)
3. **Error Handling**: Log failed notifications to `NOTIFICATION_LOGS` table
4. **Rate Limiting**: Be mindful of FCM quota limits (1 million messages/day on free tier)
5. **Testing**: Test on real devices - emulators have limited FCM support
6. **Production**: Use PM2 or similar to keep cron jobs running 24/7

---

## ✅ Checklist Before Production

- [ ] Firebase project created
- [ ] Service account key downloaded and secured
- [ ] Android app registered in Firebase
- [ ] iOS app registered in Firebase
- [ ] Device registration endpoint tested
- [ ] Check-in notification working
- [ ] Snooze reminders working
- [ ] Danger PIN alerts working
- [ ] Admin topic subscriptions working
- [ ] Cron jobs running continuously
- [ ] Error logging implemented
- [ ] Notification delivery tracking working

---

**Last Updated**: 2025-12-04
**Flutter App Version**: Using Firebase Cloud Messaging v15.1.3
**Backend**: Next.js API with Drizzle ORM
