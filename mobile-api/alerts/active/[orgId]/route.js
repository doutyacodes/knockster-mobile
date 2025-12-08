import { db } from '@/utils';
import { SAFETY_ALERTS, SAFETY_CHECKINS, USER_PROFILES, USERS } from '@/utils/schema/schema';
import { eq, and, or } from 'drizzle-orm';
import { NextResponse } from 'next/server';

/**
 * GET /api/mobile-api/alerts/active/[orgId]
 * Get all active alerts for an organization
 */
export async function GET(request, { params }) {
  try {
    const { orgId } = params;

    if (!orgId) {
      return NextResponse.json(
        { success: false, message: 'Organization ID is required' },
        { status: 400 }
      );
    }

    // Get active alerts with user details
    const alerts = await db
      .select({
        // Alert details
        alert_id: SAFETY_ALERTS.id,
        alert_type: SAFETY_ALERTS.alert_type,
        priority: SAFETY_ALERTS.priority,
        alert_status: SAFETY_ALERTS.alert_status,
        alert_sent_at: SAFETY_ALERTS.alert_sent_at,
        resolved_at: SAFETY_ALERTS.resolved_at,
        resolution_notes: SAFETY_ALERTS.resolution_notes,
        
        // Check-in details
        checkin_id: SAFETY_CHECKINS.id,
        checkin_date: SAFETY_CHECKINS.checkin_date,
        scheduled_time: SAFETY_CHECKINS.scheduled_time,
        checkin_status: SAFETY_CHECKINS.status,
        
        // User details
        user_id: USERS.id,
        user_email: USERS.email,
        user_name: USER_PROFILES.full_name,
        user_phone: USER_PROFILES.phone,
        user_profile_pic: USER_PROFILES.profile_pic_url,
      })
      .from(SAFETY_ALERTS)
      .leftJoin(SAFETY_CHECKINS, eq(SAFETY_ALERTS.checkin_id, SAFETY_CHECKINS.id))
      .leftJoin(USERS, eq(SAFETY_ALERTS.user_id, USERS.id))
      .leftJoin(USER_PROFILES, eq(USERS.id, USER_PROFILES.user_id))
      .where(
        and(
          eq(SAFETY_ALERTS.org_id, parseInt(orgId)),
          or(
            eq(SAFETY_ALERTS.alert_status, 'pending'),
            eq(SAFETY_ALERTS.alert_status, 'acknowledged'),
            eq(SAFETY_ALERTS.alert_status, 'in_progress')
          )
        )
      )
      .orderBy(SAFETY_ALERTS.alert_sent_at);

    // Categorize alerts by priority
    const categorized = {
      critical: alerts.filter(a => a.priority === 'critical'),
      high: alerts.filter(a => a.priority === 'high'),
      medium: alerts.filter(a => a.priority === 'medium'),
      low: alerts.filter(a => a.priority === 'low'),
    };

    // Statistics
    const stats = {
      total: alerts.length,
      critical: categorized.critical.length,
      high: categorized.high.length,
      medium: categorized.medium.length,
      low: categorized.low.length,
      danger_pin_alerts: alerts.filter(a => a.alert_type === 'danger_pin_entered').length,
      no_response_alerts: alerts.filter(a => a.alert_type === 'no_response_after_snooze').length,
    };

    return NextResponse.json(
      {
        success: true,
        data: {
          alerts,
          categorized,
          stats,
        },
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Get active alerts error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}