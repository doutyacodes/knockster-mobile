import { db } from '@/utils';
import { SAFETY_TIMINGS, ORGANISATIONS } from '@/utils/schema/schema';
import { eq, and } from 'drizzle-orm';
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
 * PUT /api/mobile-api/schedule/user/[userId]
 * Update an existing timing
 */
export async function PUT(request, { params }) {
  try {
    const { userId } = params;
    const body = await request.json();
    const { timing_id, label, time, active_days } = body;

    if (!userId || !timing_id) {
      return NextResponse.json(
        { success: false, message: 'User ID and timing_id are required' },
        { status: 400 }
      );
    }

    // Validate active_days if provided
    if (active_days) {
      if (!Array.isArray(active_days) || active_days.length === 0) {
        return NextResponse.json(
          { success: false, message: 'active_days must be a non-empty array' },
          { status: 400 }
        );
      }

      const validDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      const invalidDays = active_days.filter(day => !validDays.includes(day.toLowerCase()));

      if (invalidDays.length > 0) {
        return NextResponse.json(
          { success: false, message: `Invalid days: ${invalidDays.join(', ')}` },
          { status: 400 }
        );
      }
    }

    // Validate time format if provided
    if (time) {
      const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/;
      if (!timeRegex.test(time)) {
        return NextResponse.json(
          { success: false, message: 'Invalid time format. Use HH:MM or HH:MM:SS' },
          { status: 400 }
        );
      }
    }

    // Build update object with only provided fields
    const updateData = {};
    if (label !== undefined) updateData.label = label;
    if (time !== undefined) updateData.time = time;
    if (active_days !== undefined) {
      const normalizedDays = active_days.map(day => day.toLowerCase());
      updateData.active_days = JSON.stringify(normalizedDays);
    }

    // Update the timing
    await db
      .update(SAFETY_TIMINGS)
      .set(updateData)
      .where(
        and(
          eq(SAFETY_TIMINGS.id, timing_id),
          eq(SAFETY_TIMINGS.user_id, parseInt(userId))
        )
      );

    return NextResponse.json(
      {
        success: true,
        message: 'Schedule updated successfully',
        data: updateData,
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Update schedule error:', error);
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