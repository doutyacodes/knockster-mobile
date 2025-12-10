# 📱 Knockster - How It Works

**A Human-Friendly Guide to Understanding the Safety Check-in System**

---

## 🎯 What is Knockster?

Knockster is a **safety check-in app** designed for organizations (schools, companies, malls, etc.) to ensure the safety of their employees, students, or members. Think of it as a digital "buddy system" that regularly checks if everyone is okay.

---

## 🌟 The Core Concept

Imagine you work at a company that cares about your safety. Every day at specific times (like 9 AM and 6 PM), the app sends you a notification asking: **"Are you safe?"**

You simply enter your PIN, and that's it! The system knows you're okay.

**But here's the clever part:** You have **TWO different PINs**:
- 🟢 **Safe PIN** - Use this when everything is fine
- 🔴 **Danger PIN** - Use this when you're in trouble but can't openly ask for help

When you enter the danger PIN, **the app looks exactly the same** - it says "success" just like the safe PIN. But secretly, it immediately alerts your organization's administrators that you need help.

This is called a **"silent alert"** - perfect for situations where someone might be forcing you to check in.

---

## 👤 The User Journey

### **Step 1: Getting Started**

1. **Sign Up / Login**
   - You receive an email and password from your organization
   - Open the app and log in
   - The app stays logged in, so you don't have to log in every time

2. **Set Up Your Two PINs**
   - The app asks you to create two different PINs (4-6 digits)
   - **Safe PIN**: Your normal "I'm okay" PIN
   - **Danger PIN**: Your secret "I need help" PIN
   - They must be different from each other
   - The app stores them securely (encrypted/hashed)

3. **Create Your Check-in Schedule**
   - Choose what times you want to be checked on (e.g., 9:00 AM, 6:00 PM)
   - Select which days (Monday-Friday, or specific days)
   - You can have multiple schedules (like one for weekdays, one for weekends)

### **Step 2: Daily Check-ins**

**Every day at your scheduled times, here's what happens:**

1. **🔔 You Get a Notification**
   - Your phone buzzes/rings with a safety check-in alert
   - The notification says something like: "⏰ Time for your Morning Check-in"

2. **📱 You Open the App**
   - The app shows a PIN entry screen
   - You see:
     - A security icon at the top
     - An advertisement banner (for future monetization)
     - "Safety Check-in Required" message
     - A numeric keypad to enter your PIN

3. **🔢 You Enter Your PIN**
   - If you're safe: Enter your **Safe PIN**
   - If you're in danger: Enter your **Danger PIN**
   - The app shows dots (•••) as you type for privacy

4. **✅ You Tap "Confirm Safety"**
   - The app verifies your PIN with the server
   - You see a green checkmark: "Check-in Successful!"
   - You're done! That's it.

**What you don't see:**
- If you used the danger PIN, administrators are immediately alerted
- But the app looks exactly the same to anyone watching
- This is your secret way to call for help without anyone knowing

### **Step 3: Managing Your Schedule**

You can always:
- **View** all your scheduled check-in times
- **Edit** the time or days
- **Delete** schedules you don't need anymore
- **Add** new schedules anytime

---

## 🚨 What Happens If You Don't Check In?

Life gets busy - you might forget or miss a notification. Here's what happens:

### **The Automatic Snooze System**

**This happens automatically - you don't control it:**

1. **First Snooze (5 minutes later)**
   - You don't respond to the check-in notification
   - After 5 minutes, the system automatically marks it as "snoozed"
   - You get a **reminder notification**: "⏰ Check-in Reminder - 2 snoozes remaining"

2. **Second Snooze (5 minutes after that)**
   - Still no response?
   - Another automatic snooze
   - Another reminder: "⏰ Check-in Reminder - 1 snooze remaining"

3. **Third Snooze (5 minutes after that)**
   - Still no response?
   - Final automatic snooze
   - Final reminder: "⏰ Check-in Reminder - Last chance!"

4. **No Response After 3 Snoozes (Total: 15 minutes)**
   - The system escalates to administrators
   - Creates a **HIGH priority alert**
   - Admins receive notifications: "🚨 [Your Name] has not responded after 3 reminders"
   - Status changes to "escalated_no_response"

**Important:** You can't manually snooze. The system does it automatically to ensure you don't ignore safety checks.

---

## 👨‍💼 The Admin Side (Behind the Scenes)

Your organization has administrators who monitor everyone's safety. Here's what they see:

### **Admin Dashboard**

**Statistics Overview:**
- 📊 Total active alerts
- 🔴 Critical alerts (danger PIN used)
- 🟠 High priority (no response after 3 snoozes)
- 📈 Alert breakdown by type

**Recent Alerts List:**
- Who needs attention
- What type of alert (danger PIN, no response, etc.)
- How long ago
- Current status

### **When You Use the Danger PIN**

1. **Immediate Alert Created**
   - Type: "Danger PIN Entered"
   - Priority: **CRITICAL**
   - Status: Pending

2. **Admins Get Notified**
   - Push notification to all admins
   - Shows your name and situation
   - Includes your emergency contact information

3. **Admins Can:**
   - **Call you** directly (logged in system)
   - Mark alert status:
     - "Acknowledged" - We've seen it
     - "In Progress" - We're handling it
     - "Resolved" - Situation handled
     - "False Alarm" - Mistake or test
   - Add notes about the situation
   - View all previous alerts for you

### **When You Don't Respond (3 Snoozes)**

1. **High Priority Alert Created**
   - Type: "No Response After Snooze"
   - Priority: **HIGH**
   - Status: Pending

2. **Admins Get Notified**
   - "🚨 [Your Name] hasn't responded in 15 minutes"
   - They can follow the escalation chain:
     - Call you first
     - Call your emergency contact
     - Take other predefined actions

---

## 🔐 The Dual PIN Security Feature

This is the **most important safety feature** of Knockster.

### **Why Two PINs?**

Imagine these scenarios:

**Scenario 1: Workplace Harassment**
- Someone is making you uncomfortable at work
- They're watching you
- You need help but can't openly ask
- **Solution:** Enter your danger PIN
- It looks like a normal check-in
- But security is quietly notified

**Scenario 2: Kidnapping or Coercion**
- Someone forces you to check in
- They're watching your screen
- You can't call for help
- **Solution:** Use your danger PIN
- The kidnapper sees "success"
- But police/security are alerted

**Scenario 3: Domestic Violence**
- You're in an unsafe home situation
- Someone monitors your phone
- You need help discreetly
- **Solution:** Danger PIN during check-in
- Looks normal to the abuser
- Help is on the way

### **How It's Designed to Be Undetectable**

1. **Identical Response**
   - Both PINs show: ✅ "Check-in Successful"
   - Same green checkmark animation
   - Same "Your safety has been confirmed" message
   - No difference in timing

2. **Server-Side Silent Alert**
   - The danger PIN only creates an alert on the server
   - Nothing changes on your screen
   - No indication that something different happened

3. **No User History**
   - The app doesn't show which PIN you used
   - No logs visible to users
   - Only admins can see the PIN type in the database

---

## 🔄 The Complete Technical Flow

Here's what happens behind the scenes (simplified):

### **Daily at Your Scheduled Time**

```
1. ⏰ Server Clock Hits 9:00 AM
   ↓
2. 🔍 Server Checks: "Who has a 9 AM check-in?"
   ↓
3. ✅ Finds You (because you set 9 AM on Mondays)
   ↓
4. 📝 Creates a Check-in Record:
   - User: You
   - Time: 9:00 AM
   - Date: Today
   - Status: Pending
   ↓
5. 🔔 Sends Push Notification to Your Phone:
   - Title: "⏰ Safety Check-in Required"
   - Body: "Time for your Morning Check-in"
   - Data: Check-in ID, Time, Label
   ↓
6. 📱 Your Phone Receives It:
   - Shows full-screen notification (if emergency settings)
   - Makes sound/vibration
   - Wakes up the screen
```

### **When You Enter Your PIN**

```
1. 🔢 You Type: 1-2-3-4
   ↓
2. 📤 App Sends to Server:
   - Check-in ID: 12345
   - PIN: "1234"
   ↓
3. 🔐 Server Compares PIN:
   - Checks against Safe PIN hash
   - Checks against Danger PIN hash
   ↓
4a. ✅ If Safe PIN Matched:
    - Update status: "acknowledged_safe"
    - Record time you responded
    - Send success response
    ↓
4b. 🚨 If Danger PIN Matched:
    - Update status: "acknowledged_danger"
    - Record time you responded
    - CREATE CRITICAL ALERT
    - Notify all admins
    - Send same success response (looks identical)
    ↓
5. 📱 App Shows Success:
   - Green checkmark animation
   - "Check-in Successful"
   - "Your safety has been confirmed"
```

### **The Automatic Snooze System**

```
Every Minute, Server Checks:
   ↓
1. 🔍 Find all "pending" check-ins
   ↓
2. ❓ Has it been 5 minutes since last snooze?
   ↓
3a. ✅ Yes, and snooze_count < 3:
    - Mark as "snoozed"
    - Increment snooze_count (0→1, 1→2, 2→3)
    - Send reminder notification
    - Log the snooze
    ↓
3b. 🚨 Yes, and snooze_count >= 3:
    - Mark as "escalated_no_response"
    - Create HIGH priority alert
    - Notify all admins
    - Add to escalation chain
```

---

## 📊 Check-in Statuses Explained

When you view your check-ins, you'll see different statuses:

| Status | What It Means | What You See |
|--------|---------------|--------------|
| **Pending** 🟡 | Waiting for your response | Orange "Pending" badge |
| **Snoozed** 🟠 | Auto-snoozed, reminder sent | Orange "Pending" badge |
| **Completed** 🟢 | You checked in with safe PIN | Green "Completed" badge |
| **Missed** 🔴 | No response after 3 snoozes | Red "Missed" badge |
| **Resolved** ⚪ | Admin marked as resolved | Grey "Resolved" badge |

**Note:** You never see "acknowledged_danger" - that's only visible to admins.

---

## 🏗️ System Architecture (Simple Version)

### **Three Main Parts:**

1. **📱 Mobile App (Flutter)**
   - What you interact with
   - Runs on your phone (iOS/Android)
   - Shows notifications
   - Collects your PIN entry
   - Sends data to the server

2. **☁️ Backend Server (Next.js API)**
   - The brain of the system
   - Stores all data in a database
   - Checks PINs
   - Creates alerts
   - Manages schedules

3. **🔔 Firebase (Google's Push Notification Service)**
   - Delivers notifications to your phone
   - Works even when app is closed
   - Fast and reliable

### **How They Work Together:**

```
Your Phone (Flutter App)
        ↕️
    Internet
        ↕️
Backend Server (Next.js API)
        ↕️
    Database (MySQL)
        ↕️
Firebase (Notifications)
        ↕️
    Internet
        ↕️
Your Phone (Notification)
```

---

## ⏰ The Cron Jobs (Automated Tasks)

Two automated scripts run **every minute** on the server:

### **1. Safety Check-in Creator**

**Runs:** Every minute
**Does:**
- Checks current time: "Is it 9:00 AM?"
- Checks current day: "Is it Monday?"
- Looks for all users with 9 AM Monday schedules
- Creates check-in records for each user
- Sends push notifications immediately

**Example:**
```
9:00 AM - Server runs script
"Who needs a 9 AM Monday check-in?"
- John Doe ✅
- Jane Smith ✅
- Bob Johnson ✅

Creates 3 check-ins → Sends 3 notifications
```

### **2. Snooze Reminder & Escalation**

**Runs:** Every minute
**Does:**
- Finds all "snoozed" check-ins
- Checks: "Has it been 5 minutes since last snooze?"
- If yes and snooze < 3: Send reminder
- If yes and snooze >= 3: Escalate to admins

**Example:**
```
9:05 AM - Server finds John's check-in
Status: pending (no response yet)
Last snooze: Never
Action: Mark as "snoozed", send reminder 1

9:10 AM - Still no response
Snooze count: 1
Action: Send reminder 2

9:15 AM - Still no response
Snooze count: 2
Action: Send reminder 3

9:20 AM - Still no response
Snooze count: 3
Action: ESCALATE! Notify admins!
```

---

## 🔒 Privacy & Security

### **What's Encrypted/Hashed:**

1. **PINs** - Stored using bcrypt (one-way hashing)
   - Even admins can't see your actual PINs
   - They can only verify if entered PIN matches

2. **Passwords** - Also bcrypt hashed
   - Nobody can see your actual password

3. **Push Notifications** - Sent over HTTPS
   - Encrypted in transit

### **What Admins Can See:**

- ✅ Your name and profile information
- ✅ Your check-in history
- ✅ Alert records (including danger PIN alerts)
- ✅ Which check-ins you completed
- ✅ Emergency contact information
- ❌ Your actual PIN numbers
- ❌ Your password

### **Data Stored:**

Everything is logged for safety and accountability:
- When you logged in
- When you checked in
- What time you responded
- Which PIN type you used (safe/danger)
- Admin actions (calls made, notes added)
- Notification delivery status

**Why?** In case of a real emergency, this creates a complete timeline of events.

---

## 🎨 Why It Looks The Way It Does

### **Design Choices:**

1. **Simple PIN Entry**
   - Large numbers, easy to tap
   - No keyboard distractions
   - Quick to use in emergency

2. **Minimal UI**
   - No complicated menus during check-in
   - Just: Icon → PIN → Submit
   - Reduces stress in crisis situations

3. **Identical Success Messages**
   - Both PINs look the same
   - Green checkmark = success (always)
   - No way for attacker to know

4. **Advertisement Space**
   - Future monetization
   - Helps keep app affordable
   - Non-intrusive placement

5. **Images from Pexels**
   - Professional security-themed visuals
   - Makes app feel trustworthy
   - Will be replaced with custom branding

---

## 📱 Key Features Summary

### **For Users:**
- ✅ Set custom check-in schedules
- ✅ Two PIN system (safe + danger)
- ✅ Push notifications
- ✅ View today's check-ins
- ✅ See completion history
- ✅ Update schedules anytime
- ✅ Secure logout

### **For Admins:**
- ✅ Real-time alert dashboard
- ✅ Alert prioritization
- ✅ Call logging
- ✅ Status updates
- ✅ User management
- ✅ Organization settings
- ✅ Emergency contact chains

### **Automated:**
- ✅ Check-in creation at scheduled times
- ✅ Push notification delivery
- ✅ Automatic snooze reminders (3 attempts)
- ✅ Escalation after no response
- ✅ Admin alerting for danger PINs

---

## 🚀 Real-World Use Cases

### **1. Corporate Office**
- Daily check-ins for remote workers
- Safety for employees working alone
- Late-night security for night shift
- Travel safety for field workers

### **2. Schools & Universities**
- Student safety check-ins
- Dorm security monitoring
- Campus late-night safety
- Study abroad programs

### **3. Healthcare Facilities**
- Night shift nurse safety
- Lone worker protection
- Parking lot security
- On-call staff check-ins

### **4. Retail & Service**
- Closing shift safety
- Lone manager security
- Cash handling protection
- Late-night workers

### **5. Personal Safety**
- Domestic violence situations
- Dating safety ("check on me in 1 hour")
- Elderly care monitoring
- Teenage safety check-ins

---

## ❓ Frequently Asked Questions

### **"What if I forget my PIN?"**
Contact your organization's admin - they can reset it for you.

### **"Can I change my PINs?"**
Yes! Through the settings menu (feature coming soon).

### **"What if I'm just sleeping and miss a check-in?"**
You'll get 3 reminder notifications over 15 minutes. If you still don't respond, admins will call you. Just answer and explain!

### **"What if I accidentally use the danger PIN?"**
Admins will call you. Just tell them it was a mistake. They can mark it as "false alarm."

### **"Can I disable check-ins when I'm on vacation?"**
Yes! You can delete or pause your schedules anytime.

### **"What if my phone dies during a check-in?"**
The system will escalate after 15 minutes, and admins will try to contact you. Charge your phone! 🔋

### **"Does this drain my battery?"**
No - push notifications are very battery-efficient. The app only runs when you open it.

### **"What if I don't have internet?"**
You need internet to send the check-in. If offline, you can't complete it, which will escalate to admins.

### **"Is my data secure?"**
Yes - all PINs and passwords are hashed (one-way encrypted), and all communication uses HTTPS.

---

## 🎯 The Bottom Line

**Knockster is a digital safety net.**

It's like having someone check on you regularly, but automated. The dual PIN system gives you a secret way to call for help even when someone is watching you.

The goal is simple: **Make sure you're safe, and if you're not, get you help immediately.**

---

## 📞 Technical Support

If you need help:
1. **Contact your organization's admin** - They manage your account
2. **Report issues** - [GitHub Issues](https://github.com/anthropics/claude-code/issues)
3. **Feedback** - Your safety is our priority, and we want to improve!

---

**Built with care for your safety. 🛡️**

*Version 1.0 - Last Updated: December 2024*
