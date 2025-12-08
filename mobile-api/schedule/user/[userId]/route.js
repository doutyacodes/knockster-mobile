import { db } from '@/utils';
import { SAFETY_TIMINGS, ORGANISATIONS } from '@/utils/schema/schema';
import { eq } from 'drizzle-orm';
import { NextResponse } from 'next/server';

/**
 * GET /api/mobile-api/schedule/user/[userId]
 * Get all safety timings for a user
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

    // Get all safety timings for user with organization details
    const timings = await db
      .select({
        id: SAFETY_TIMINGS.id,
        label: SAFETY_TIMINGS.label,
        time: SAFETY_TIMINGS.time,
        active_days: SAFETY_TIMINGS.active_days,
        is_active: SAFETY_TIMINGS.is_active,
        created_at: SAFETY_TIMINGS.created_at,
        org_id: SAFETY_TIMINGS.org_id,
        org_name: ORGANISATIONS.name,
        org_type: ORGANISATIONS.type,
      })
      .from(SAFETY_TIMINGS)
      .leftJoin(ORGANISATIONS, eq(SAFETY_TIMINGS.org_id, ORGANISATIONS.id))
      .where(eq(SAFETY_TIMINGS.user_id, parseInt(userId)));

    // Parse active_days JSON strings
    const parsedTimings = timings.map(timing => ({
      ...timing,
      active_days: typeof timing.active_days === 'string' 
        ? JSON.parse(timing.active_days) 
        : timing.active_days,
    }));

    return NextResponse.json(
      {
        success: true,
        data: {
          timings: parsedTimings,
          total: parsedTimings.length,
        },
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Get schedules error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}

/**
 * DELETE /api/mobile-api/schedule/user/[userId]
 * Delete a specific timing (pass timing_id in body)
 */
export async function DELETE(request, { params }) {
  try {
    const { userId } = params;
    const body = await request.json();
    const { timing_id } = body;

    if (!userId || !timing_id) {
      return NextResponse.json(
        { success: false, message: 'User ID and timing_id are required' },
        { status: 400 }
      );
    }

    // Delete the timing
    await db
      .delete(SAFETY_TIMINGS)
      .where(
        and(
          eq(SAFETY_TIMINGS.id, timing_id),
          eq(SAFETY_TIMINGS.user_id, parseInt(userId))
        )
      );

    return NextResponse.json(
      {
        success: true,
        message: 'Schedule deleted successfully',
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Delete schedule error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}