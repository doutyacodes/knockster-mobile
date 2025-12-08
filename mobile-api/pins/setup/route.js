import { db } from '@/utils';
import { USER_PROFILES, AUDIT_LOGS } from '@/utils/schema/schema';
import { eq } from 'drizzle-orm';
import bcrypt from 'bcryptjs';
import { NextResponse } from 'next/server';

/**
 * POST /api/mobile-api/pins/setup
 * Set or update user's safe and danger PINs
 */
export async function POST(request) {
  try {
    const body = await request.json();
    const { user_id, safe_pin, danger_pin } = body;

    // Validation
    if (!user_id || !safe_pin || !danger_pin) {
      return NextResponse.json(
        { success: false, message: 'user_id, safe_pin, and danger_pin are required' },
        { status: 400 }
      );
    }

    // Validate PIN format (4-6 digits)
    const pinRegex = /^\d{4,6}$/;
    if (!pinRegex.test(safe_pin)) {
      return NextResponse.json(
        { success: false, message: 'Safe PIN must be 4-6 digits' },
        { status: 400 }
      );
    }

    if (!pinRegex.test(danger_pin)) {
      return NextResponse.json(
        { success: false, message: 'Danger PIN must be 4-6 digits' },
        { status: 400 }
      );
    }

    // PINs must be different
    if (safe_pin === danger_pin) {
      return NextResponse.json(
        { success: false, message: 'Safe PIN and Danger PIN must be different' },
        { status: 400 }
      );
    }

    // Hash PINs
    const safe_pin_hash = await bcrypt.hash(safe_pin, 10);
    const danger_pin_hash = await bcrypt.hash(danger_pin, 10);

    // Update user profile
    await db
      .update(USER_PROFILES)
      .set({
        safe_pin_hash,
        danger_pin_hash,
        updated_at: new Date(),
      })
      .where(eq(USER_PROFILES.user_id, user_id));

    // Log the action in audit logs
    await db
      .insert(AUDIT_LOGS)
      .values({
        user_id,
        action: 'pin_setup',
        entity_type: 'user_profile',
        entity_id: user_id,
        details: JSON.stringify({ action: 'PINs set successfully' }),
      });

    return NextResponse.json(
      {
        success: true,
        message: 'PINs set successfully',
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('PIN setup error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}

/**
 * PUT /api/mobile-api/pins/setup
 * Update existing PINs (requires old PIN verification)
 */
export async function PUT(request) {
  try {
    const body = await request.json();
    const { user_id, old_safe_pin, new_safe_pin, new_danger_pin } = body;

    // Validation
    if (!user_id || !old_safe_pin || !new_safe_pin || !new_danger_pin) {
      return NextResponse.json(
        { success: false, message: 'All fields are required' },
        { status: 400 }
      );
    }

    // Get current user profile
    const profile = await db
      .select()
      .from(USER_PROFILES)
      .where(eq(USER_PROFILES.user_id, user_id))
      .limit(1);

    if (!profile || profile.length === 0) {
      return NextResponse.json(
        { success: false, message: 'User profile not found' },
        { status: 404 }
      );
    }

    // Verify old safe PIN
    const isOldPinValid = await bcrypt.compare(old_safe_pin, profile[0].safe_pin_hash);

    if (!isOldPinValid) {
      return NextResponse.json(
        { success: false, message: 'Old PIN is incorrect' },
        { status: 401 }
      );
    }

    // Validate new PIN format
    const pinRegex = /^\d{4,6}$/;
    if (!pinRegex.test(new_safe_pin) || !pinRegex.test(new_danger_pin)) {
      return NextResponse.json(
        { success: false, message: 'PINs must be 4-6 digits' },
        { status: 400 }
      );
    }

    // New PINs must be different
    if (new_safe_pin === new_danger_pin) {
      return NextResponse.json(
        { success: false, message: 'Safe PIN and Danger PIN must be different' },
        { status: 400 }
      );
    }

    // Hash new PINs
    const safe_pin_hash = await bcrypt.hash(new_safe_pin, 10);
    const danger_pin_hash = await bcrypt.hash(new_danger_pin, 10);

    // Update user profile
    await db
      .update(USER_PROFILES)
      .set({
        safe_pin_hash,
        danger_pin_hash,
        updated_at: new Date(),
      })
      .where(eq(USER_PROFILES.user_id, user_id));

    // Log the action
    await db
      .insert(AUDIT_LOGS)
      .values({
        user_id,
        action: 'pin_update',
        entity_type: 'user_profile',
        entity_id: user_id,
        details: JSON.stringify({ action: 'PINs updated successfully' }),
      });

    return NextResponse.json(
      {
        success: true,
        message: 'PINs updated successfully',
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('PIN update error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}