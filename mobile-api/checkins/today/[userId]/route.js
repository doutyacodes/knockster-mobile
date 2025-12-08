import { db } from '@/utils';
import { SAFETY_CHECKINS, SAFETY_TIMINGS } from '@/utils/schema/schema';
import { eq, and, sql } from 'drizzle-orm';
import { NextResponse } from 'next/server';

/**
 * GET /api/mobile-api/checkins/today/[userId]
 * Get today's check-ins for a user
 */
export async function GET(request, { params }) {
  try {
    const { userId } = params;

    if (!userId) {
      return NextResponse.json(
        { success: false, message: 'User ID is required' },
        { status: 400 }
      );
    }

    // Get today's date
    const today = new Date();
    const todayStr = today.toISOString().split('T')[0]; // YYYY-MM-DD

    // Get all check-ins for today
    const checkins = await db
      .select({
        id: SAFETY_CHECKINS.id,
        timing_id: SAFETY_CHECKINS.timing_id,
        checkin_date: SAFETY_CHECKINS.checkin_date,
        scheduled_time: SAFETY_CHECKINS.scheduled_time,
        status: SAFETY_CHECKINS.status,
        user_response_time: SAFETY_CHECKINS.user_response_time,
        pin_type_used: SAFETY_CHECKINS.pin_type_used,
        snooze_count: SAFETY_CHECKINS.snooze_count,
        last_snooze_at: SAFETY_CHECKINS.last_snooze_at,
        created_at: SAFETY_CHECKINS.created_at,
        timing_label: SAFETY_TIMINGS.label,
      })
      .from(SAFETY_CHECKINS)
      .leftJoin(SAFETY_TIMINGS, eq(SAFETY_CHECKINS.timing_id, SAFETY_TIMINGS.id))
      .where(
        and(
          eq(SAFETY_CHECKINS.user_id, parseInt(userId)),
          sql`DATE(${SAFETY_CHECKINS.checkin_date}) = ${todayStr}`
        )
      )
      .orderBy(SAFETY_CHECKINS.scheduled_time);

    // Get statistics
    const stats = {
      total: checkins.length,
      pending: checkins.filter(c => c.status === 'pending' || c.status === 'snoozed').length,
      completed: checkins.filter(c => c.status === 'acknowledged_safe').length,
      danger: checkins.filter(c => c.status === 'acknowledged_danger').length,
      missed: checkins.filter(c => c.status === 'escalated_no_response').length,
    };

    return NextResponse.json(
      {
        success: true,
        data: {
          checkins,
          stats,
          date: todayStr,
        },
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Get today checkins error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}