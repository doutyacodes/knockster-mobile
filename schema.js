import {
  boolean,
  date,
  datetime,
  decimal,
  float,
  int,
  json,
  mysqlEnum,
  mysqlTable,
  primaryKey,
  text,
  time,
  timestamp,
  uniqueIndex,
  unique,
  varchar,
  uniqueKeyName,
  index,
  double,
} from "drizzle-orm/mysql-core";

export const USERS = mysqlTable("users", {
  id: int("id").primaryKey().autoincrement(),

  email: varchar("email", { length: 150 }).notNull().unique(),
  password_hash: varchar("password_hash", { length: 255 }).notNull(),

  // NEW: User status management
  status: mysqlEnum("status", ["active", "suspended", "deleted"])
    .default("active")
    .notNull(),

  // NEW: Timezone support for accurate scheduling
  timezone: varchar("timezone", { length: 50 }).default("UTC"),

  created_at: timestamp("created_at").defaultNow(),
  updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
});

export const USER_PROFILES = mysqlTable("user_profiles", {
  id: int("id").primaryKey().autoincrement(),

  user_id: int("user_id")
    .notNull()
    .unique()
    .references(() => USERS.id, { onDelete: "cascade" }),

  full_name: varchar("full_name", { length: 150 }),
  phone: varchar("phone", { length: 20 }),
  profile_pic_url: varchar("profile_pic_url", { length: 255 }),

  // CHANGED: PINs should be hashed, not stored in plain text
  safe_pin_hash: varchar("safe_pin_hash", { length: 255 }),
  danger_pin_hash: varchar("danger_pin_hash", { length: 255 }),

  // NEW: Emergency contact information
  emergency_contact_name: varchar("emergency_contact_name", { length: 150 }),
  emergency_contact_phone: varchar("emergency_contact_phone", { length: 20 }),

  created_at: timestamp("created_at").defaultNow(),
  updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
});

export const ROLES = mysqlTable("roles", {
  id: int("id").primaryKey().autoincrement(),
  name: varchar("name", { length: 50 }).notNull().unique(), // super_admin, org_admin, moderator, user
  display_name: varchar("display_name", { length: 100 }),

  created_at: timestamp("created_at").defaultNow(),
});

export const USER_ROLES = mysqlTable("user_roles", {
  id: int("id").primaryKey().autoincrement(),

  user_id: int("user_id")
    .notNull()
    .references(() => USERS.id, { onDelete: "cascade" }),
  role_id: int("role_id")
    .notNull()
    .references(() => ROLES.id, { onDelete: "cascade" }),

  created_at: timestamp("created_at").defaultNow(),
});

export const ORGANISATIONS = mysqlTable("organisations", {
  id: int("id").primaryKey().autoincrement(),

  name: varchar("name", { length: 200 }).notNull(),
  type: varchar("type", { length: 100 }), // optional: school, IT, mall
  profile_pic_url: varchar("profile_pic_url", { length: 255 }),

  address: varchar("address", { length: 255 }),
  contact_email: varchar("contact_email", { length: 150 }),
  contact_phone: varchar("contact_phone", { length: 20 }),

  // NEW: Organization status
  status: mysqlEnum("status", ["active", "suspended", "deleted"])
    .default("active")
    .notNull(),

  created_at: timestamp("created_at").defaultNow(),
  updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
});

export const ORG_USERS = mysqlTable("org_users", {
  id: int("id").primaryKey().autoincrement(),

  org_id: int("org_id")
    .notNull()
    .references(() => ORGANISATIONS.id, { onDelete: "cascade" }),
  user_id: int("user_id")
    .notNull()
    .references(() => USERS.id, { onDelete: "cascade" }),

  role_id: int("role_id")
    .notNull()
    .references(() => ROLES.id),
  is_primary_admin: boolean("is_primary_admin").default(false),

  // NEW: Track when user joined/left organization
  joined_at: timestamp("joined_at").defaultNow(),
  left_at: timestamp("left_at"),
  status: mysqlEnum("status", ["active", "inactive"])
    .default("active")
    .notNull(),

  created_at: timestamp("created_at").defaultNow(),
  updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
});

export const SAFETY_TIMINGS = mysqlTable("safety_timings", {
  id: int("id").primaryKey().autoincrement(),

  user_id: int("user_id")
    .notNull()
    .references(() => USERS.id, { onDelete: "cascade" }),
  org_id: int("org_id")
    .notNull()
    .references(() => ORGANISATIONS.id, { onDelete: "cascade" }),

  label: varchar("label", { length: 50 }).notNull(), // morning_checkin, evening_checkin, etc.
  time: time("time").notNull(),

  // NEW: Critical - Days of week selection
  // Stored as JSON array: ["monday", "tuesday", "wednesday", "thursday", "friday"]
  active_days: json("active_days").notNull().$type(),

  // NEW: Allow users to temporarily disable a timing
  is_active: boolean("is_active").default(true).notNull(),

  created_at: timestamp("created_at").defaultNow(),
  updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
});

// NEW: Table to track notification delivery
export const NOTIFICATION_LOGS = mysqlTable("notification_logs", {
  id: int("id").primaryKey().autoincrement(),

  checkin_id: int("checkin_id")
    .notNull()
    .references(() => SAFETY_CHECKINS.id, { onDelete: "cascade" }),
  user_id: int("user_id")
    .notNull()
    .references(() => USERS.id),

  notification_type: mysqlEnum("notification_type", [
    "initial_checkin",
    "snooze_reminder_1",
    "snooze_reminder_2",
    "snooze_reminder_3",
    "admin_alert",
  ]).notNull(),

  // Push notification details
  device_token: varchar("device_token", { length: 255 }),
  sent_at: timestamp("sent_at").defaultNow(),
  delivery_status: mysqlEnum("delivery_status", ["sent", "delivered", "failed"])
    .default("sent")
    .notNull(),

  // For failed notifications
  error_message: text("error_message"),
});

export const SAFETY_CHECKINS = mysqlTable(
  "safety_checkins",
  {
    id: int("id").primaryKey().autoincrement(),

    user_id: int("user_id")
      .notNull()
      .references(() => USERS.id, { onDelete: "cascade" }),
    timing_id: int("timing_id")
      .notNull()
      .references(() => SAFETY_TIMINGS.id, { onDelete: "cascade" }),
    org_id: int("org_id")
      .notNull()
      .references(() => ORGANISATIONS.id, { onDelete: "cascade" }),

    checkin_date: date("checkin_date").notNull(),
    scheduled_time: time("scheduled_time").notNull(),

    status: mysqlEnum("status", [
      "pending",
      "acknowledged_safe",
      "acknowledged_danger",
      "snoozed",
      "escalated_no_response",
      "resolved",
    ])
      .notNull()
      .default("pending"),

    // When user actually responded
    user_response_time: timestamp("user_response_time"),

    // NEW: Track which PIN was used
    pin_type_used: mysqlEnum("pin_type_used", ["safe", "danger"]),

    snooze_count: int("snooze_count").default(0).notNull(), // 0, 1, 2, 3
    last_snooze_at: timestamp("last_snooze_at"),

    // NEW: Final resolution details
    resolved_at: timestamp("resolved_at"),
    resolved_by: int("resolved_by").references(() => USERS.id), // admin who resolved it

    created_at: timestamp("created_at").defaultNow(),
    updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
  },
  (table) => ({
    // Index for efficient queries
    userDateIdx: index("user_date_idx").on(table.user_id, table.checkin_date),
    statusIdx: index("status_idx").on(table.status),
  })
);

// Each automatic snooze attempt is logged
export const SAFETY_SNOOZE_LOGS = mysqlTable("safety_snooze_logs", {
  id: int("id").primaryKey().autoincrement(),

  checkin_id: int("checkin_id")
    .notNull()
    .references(() => SAFETY_CHECKINS.id, { onDelete: "cascade" }),

  snooze_number: int("snooze_number").notNull(), // 1, 2, 3
  sent_at: timestamp("sent_at").defaultNow(),

  // NEW: Track if snooze notification was delivered
  notification_delivered: boolean("notification_delivered").default(true),
});

export const SAFETY_ALERTS = mysqlTable(
  "safety_alerts",
  {
    id: int("id").primaryKey().autoincrement(),

    checkin_id: int("checkin_id")
      .notNull()
      .references(() => SAFETY_CHECKINS.id, { onDelete: "cascade" }),
    user_id: int("user_id")
      .notNull()
      .references(() => USERS.id),
    org_id: int("org_id")
      .notNull()
      .references(() => ORGANISATIONS.id),

    alert_type: mysqlEnum("alert_type", [
      "danger_pin_entered",
      "no_response_after_snooze",
      "admin_call_failed",
      "manual_alert",
    ]).notNull(),

    // NEW: Alert priority and status
    priority: mysqlEnum("priority", ["low", "medium", "high", "critical"])
      .default("medium")
      .notNull(),
    alert_status: mysqlEnum("alert_status", [
      "pending",
      "acknowledged",
      "in_progress",
      "resolved",
      "false_alarm",
    ])
      .default("pending")
      .notNull(),

    alert_sent_at: timestamp("alert_sent_at").defaultNow(),

    // NEW: Resolution tracking
    resolved_at: timestamp("resolved_at"),
    resolved_by: int("resolved_by").references(() => USERS.id),
    resolution_notes: text("resolution_notes"),

    created_at: timestamp("created_at").defaultNow(),
    updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
  },
  (table) => ({
    statusIdx: index("alert_status_idx").on(table.alert_status),
    orgIdx: index("org_idx").on(table.org_id),
  })
);

// NEW: Escalation chain for organizations
export const ORG_ESCALATION_CHAIN = mysqlTable("org_escalation_chain", {
  id: int("id").primaryKey().autoincrement(),

  org_id: int("org_id")
    .notNull()
    .references(() => ORGANISATIONS.id, { onDelete: "cascade" }),
  admin_id: int("admin_id")
    .notNull()
    .references(() => USERS.id),

  // Order of escalation (1 = first contact, 2 = second, etc.)
  escalation_order: int("escalation_order").notNull(),

  // Time to wait before escalating to next person (in minutes)
  wait_time_minutes: int("wait_time_minutes").default(5).notNull(),

  is_active: boolean("is_active").default(true).notNull(),

  created_at: timestamp("created_at").defaultNow(),
  updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
});

export const ADMIN_CALL_LOGS = mysqlTable("admin_call_logs", {
  id: int("id").primaryKey().autoincrement(),

  alert_id: int("alert_id")
    .notNull()
    .references(() => SAFETY_ALERTS.id, { onDelete: "cascade" }),

  admin_id: int("admin_id")
    .notNull()
    .references(() => USERS.id),
  user_id: int("user_id")
    .notNull()
    .references(() => USERS.id),

  call_time: timestamp("call_time").defaultNow(),

  call_status: mysqlEnum("call_status", [
    "initiated",
    "ringing",
    "attended_safe",
    "attended_not_safe",
    "not_attended",
    "failed",
  ]).notNull(),

  // NEW: Call duration for attended calls
  call_duration_seconds: int("call_duration_seconds"),

  notes: text("notes"),

  created_at: timestamp("created_at").defaultNow(),
});

// NEW: Device tokens for push notifications
export const USER_DEVICES = mysqlTable(
  "user_devices",
  {
    id: int("id").primaryKey().autoincrement(),

    user_id: int("user_id")
      .notNull()
      .references(() => USERS.id, { onDelete: "cascade" }),

    device_token: varchar("device_token", { length: 255 }).notNull(),
    device_type: mysqlEnum("device_type", ["ios", "android"]).notNull(),
    device_name: varchar("device_name", { length: 100 }),

    is_active: boolean("is_active").default(true).notNull(),

    last_used_at: timestamp("last_used_at").defaultNow(),
    created_at: timestamp("created_at").defaultNow(),
  },
  (table) => ({
    deviceTokenIdx: uniqueIndex("device_token_idx").on(table.device_token),
  })
);

// NEW: Audit log for sensitive actions
export const AUDIT_LOGS = mysqlTable(
  "audit_logs",
  {
    id: int("id").primaryKey().autoincrement(),

    user_id: int("user_id").references(() => USERS.id),
    org_id: int("org_id").references(() => ORGANISATIONS.id),

    action: varchar("action", { length: 100 }).notNull(), // login, pin_change, alert_resolved, etc.
    entity_type: varchar("entity_type", { length: 50 }), // user, alert, checkin, etc.
    entity_id: int("entity_id"),

    ip_address: varchar("ip_address", { length: 45 }),
    user_agent: varchar("user_agent", { length: 255 }),

    details: json("details"), // Additional context as JSON

    created_at: timestamp("created_at").defaultNow(),
  },
  (table) => ({
    userIdx: index("audit_user_idx").on(table.user_id),
    actionIdx: index("audit_action_idx").on(table.action),
    createdIdx: index("audit_created_idx").on(table.created_at),
  })
);

// NEW: App settings and configurations
export const APP_SETTINGS = mysqlTable(
  "app_settings",
  {
    id: int("id").primaryKey().autoincrement(),

    org_id: int("org_id").references(() => ORGANISATIONS.id, {
      onDelete: "cascade",
    }),

    setting_key: varchar("setting_key", { length: 100 }).notNull(),
    setting_value: text("setting_value").notNull(),

    // Settings can be global or org-specific
    is_global: boolean("is_global").default(false).notNull(),

    created_at: timestamp("created_at").defaultNow(),
    updated_at: timestamp("updated_at").defaultNow().onUpdateNow(),
  },
  (table) => ({
    settingKeyIdx: index("setting_key_idx").on(table.setting_key),
  })
);
