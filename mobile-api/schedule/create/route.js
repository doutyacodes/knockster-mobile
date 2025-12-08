import { db } from '@/utils';
import { SAFETY_TIMINGS, ORG_USERS } from '@/utils/schema/schema';
import { eq, and } from 'drizzle-orm';
import { NextResponse } from 'next/server';

/**
 * POST /api/mobile-api/schedule/create
 * Create a new safety timing schedule
 */
export async function POST(request) {
  try {
    const body = await request.json();
    const { user_id, label, time, active_days } = body;

    // Validation
    if (!user_id || !label || !time || !active_days) {
      return NextResponse.json(
        { success: false, message: 'user_id, label, time, and active_days are required' },
        { status: 400 }
      );
    }

    // Validate active_days is an array
    if (!Array.isArray(active_days) || active_days.length === 0) {
      return NextResponse.json(
        { success: false, message: 'active_days must be a non-empty array' },
        { status: 400 }
      );
    }

    // Validate days
    const validDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    const invalidDays = active_days.filter(day => !validDays.includes(day.toLowerCase()));

    if (invalidDays.length > 0) {
      return NextResponse.json(
        { success: false, message: `Invalid days: ${invalidDays.join(', ')}` },
        { status: 400 }
      );
    }

    // Validate time format (HH:MM:SS or HH:MM)
    const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/;
    if (!timeRegex.test(time)) {
      return NextResponse.json(
        { success: false, message: 'Invalid time format. Use HH:MM or HH:MM:SS' },
        { status: 400 }
      );
    }

    // Get user's primary organization
    const userOrg = await db
      .select()
      .from(ORG_USERS)
      .where(
        and(
          eq(ORG_USERS.user_id, user_id),
          eq(ORG_USERS.status, 'active')
        )
      )
      .limit(1);

    if (!userOrg || userOrg.length === 0) {
      return NextResponse.json(
        { success: false, message: 'User is not associated with any organization' },
        { status: 404 }
      );
    }

    const org_id = userOrg[0].org_id;

    // Normalize active_days to lowercase
    const normalizedDays = active_days.map(day => day.toLowerCase());

    // Create safety timing
    const result = await db
      .insert(SAFETY_TIMINGS)
      .values({
        user_id,
        org_id,
        label,
        time,
        active_days: JSON.stringify(normalizedDays),
        is_active: true,
      });

    return NextResponse.json(
      {
        success: true,
        message: 'Schedule created successfully',
        data: {
          timing_id: result[0].insertId,
          user_id,
          org_id,
          label,
          time,
          active_days: normalizedDays,
        },
      },
      { status: 201 }
    );

  } catch (error) {
    console.error('Schedule creation error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}