import { db } from '@/utils';
import { 
  SAFETY_ALERTS, 
  SAFETY_CHECKINS, 
  USER_PROFILES, 
  USERS,
  ADMIN_CALL_LOGS,
  AUDIT_LOGS
} from '@/utils/schema/schema';
import { eq } from 'drizzle-orm';
import { NextResponse } from 'next/server';

/**
 * GET /api/mobile-api/alerts/[alertId]
 * Get detailed information about a specific alert
 */
export async function GET(request, { params }) {
  try {
    const { alertId } = params;

    if (!alertId) {
      return NextResponse.json(
        { success: false, message: 'Alert ID is required' },
        { status: 400 }
      );
    }

    // Get alert with all related details
    const alert = await db
      .select({
        // Alert details
        alert_id: SAFETY_ALERTS.id,
        alert_type: SAFETY_ALERTS.alert_type,
        priority: SAFETY_ALERTS.priority,
        alert_status: SAFETY_ALERTS.alert_status,
        alert_sent_at: SAFETY_ALERTS.alert_sent_at,
        resolved_at: SAFETY_ALERTS.resolved_at,
        resolved_by: SAFETY_ALERTS.resolved_by,
        resolution_notes: SAFETY_ALERTS.resolution_notes,
        
        // Check-in details
        checkin_id: SAFETY_CHECKINS.id,
        checkin_date: SAFETY_CHECKINS.checkin_date,
        scheduled_time: SAFETY_CHECKINS.scheduled_time,
        checkin_status: SAFETY_CHECKINS.status,
        user_response_time: SAFETY_CHECKINS.user_response_time,
        snooze_count: SAFETY_CHECKINS.snooze_count,
        
        // User details
        user_id: USERS.id,
        user_email: USERS.email,
        user_name: USER_PROFILES.full_name,
        user_phone: USER_PROFILES.phone,
        user_profile_pic: USER_PROFILES.profile_pic_url,
        emergency_contact_name: USER_PROFILES.emergency_contact_name,
        emergency_contact_phone: USER_PROFILES.emergency_contact_phone,
      })
      .from(SAFETY_ALERTS)
      .leftJoin(SAFETY_CHECKINS, eq(SAFETY_ALERTS.checkin_id, SAFETY_CHECKINS.id))
      .leftJoin(USERS, eq(SAFETY_ALERTS.user_id, USERS.id))
      .leftJoin(USER_PROFILES, eq(USERS.id, USER_PROFILES.user_id))
      .where(eq(SAFETY_ALERTS.id, parseInt(alertId)))
      .limit(1);

    if (!alert || alert.length === 0) {
      return NextResponse.json(
        { success: false, message: 'Alert not found' },
        { status: 404 }
      );
    }

    const alertData = alert[0];

    // Get call logs for this alert
    const callLogs = await db
      .select({
        id: ADMIN_CALL_LOGS.id,
        admin_id: ADMIN_CALL_LOGS.admin_id,
        call_time: ADMIN_CALL_LOGS.call_time,
        call_status: ADMIN_CALL_LOGS.call_status,
        call_duration_seconds: ADMIN_CALL_LOGS.call_duration_seconds,
        notes: ADMIN_CALL_LOGS.notes,
        admin_name: USER_PROFILES.full_name,
      })
      .from(ADMIN_CALL_LOGS)
      .leftJoin(USER_PROFILES, eq(ADMIN_CALL_LOGS.admin_id, USER_PROFILES.user_id))
      .where(eq(ADMIN_CALL_LOGS.alert_id, parseInt(alertId)))
      .orderBy(ADMIN_CALL_LOGS.call_time);

    return NextResponse.json(
      {
        success: true,
        data: {
          alert: alertData,
          call_logs: callLogs,
        },
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Get alert detail error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}

/**
 * PUT /api/mobile-api/alerts/[alertId]
 * Update alert status (acknowledge, in progress, resolve)
 */
export async function PUT(request, { params }) {
  try {
    const { alertId } = params;
    const body = await request.json();
    const { admin_id, status, notes } = body;

    if (!alertId || !admin_id || !status) {
      return NextResponse.json(
        { success: false, message: 'alert_id, admin_id, and status are required' },
        { status: 400 }
      );
    }

    // Validate status
    const validStatuses = ['acknowledged', 'in_progress', 'resolved', 'false_alarm'];
    if (!validStatuses.includes(status)) {
      return NextResponse.json(
        { success: false, message: 'Invalid status' },
        { status: 400 }
      );
    }

    const now = new Date();
    const updateData = {
      alert_status: status,
      updated_at: now,
    };

    // If resolving, add resolution details
    if (status === 'resolved' || status === 'false_alarm') {
      updateData.resolved_at = now;
      updateData.resolved_by = admin_id;
      updateData.resolution_notes = notes || null;

      // Also update the related check-in
      const alert = await db
        .select()
        .from(SAFETY_ALERTS)
        .where(eq(SAFETY_ALERTS.id, parseInt(alertId)))
        .limit(1);

      if (alert && alert.length > 0) {
        await db
          .update(SAFETY_CHECKINS)
          .set({
            status: 'resolved',
            resolved_at: now,
            resolved_by: admin_id,
            updated_at: now,
          })
          .where(eq(SAFETY_CHECKINS.id, alert[0].checkin_id));
      }
    }

    // Update alert
    await db
      .update(SAFETY_ALERTS)
      .set(updateData)
      .where(eq(SAFETY_ALERTS.id, parseInt(alertId)));

    // Log action in audit logs
    await db
      .insert(AUDIT_LOGS)
      .values({
        user_id: admin_id,
        action: `alert_${status}`,
        entity_type: 'safety_alert',
        entity_id: parseInt(alertId),
        details: JSON.stringify({ status, notes }),
      });

    return NextResponse.json(
      {
        success: true,
        message: `Alert ${status} successfully`,
        data: {
          alert_id: parseInt(alertId),
          status,
          resolved_at: updateData.resolved_at || null,
        },
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Update alert error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}