import { db } from '@/utils';
import { SAFETY_CHECKINS, USER_PROFILES, SAFETY_ALERTS, NOTIFICATION_LOGS } from '@/utils/schema/schema';
import { eq } from 'drizzle-orm';
import bcrypt from 'bcryptjs';
import { NextResponse } from 'next/server';

/**
 * POST /api/mobile-api/checkins/verify
 * Verify PIN for a check-in
 * CRITICAL: Danger PIN must look identical to Safe PIN response
 */
export async function POST(request) {
  try {
    const body = await request.json();
    const { checkin_id, pin } = body;

    // Validation
    if (!checkin_id || !pin) {
      return NextResponse.json(
        { success: false, message: 'checkin_id and pin are required' },
        { status: 400 }
      );
    }

    // Validate PIN format
    const pinRegex = /^\d{4,6}$/;
    if (!pinRegex.test(pin)) {
      return NextResponse.json(
        { success: false, message: 'Invalid PIN format' },
        { status: 400 }
      );
    }

    // Get check-in details
    const checkin = await db
      .select()
      .from(SAFETY_CHECKINS)
      .where(eq(SAFETY_CHECKINS.id, checkin_id))
      .limit(1);

    if (!checkin || checkin.length === 0) {
      return NextResponse.json(
        { success: false, message: 'Check-in not found' },
        { status: 404 }
      );
    }

    const checkinData = checkin[0];

    // Get user profile with PINs
    const profile = await db
      .select()
      .from(USER_PROFILES)
      .where(eq(USER_PROFILES.user_id, checkinData.user_id))
      .limit(1);

    if (!profile || profile.length === 0) {
      return NextResponse.json(
        { success: false, message: 'User profile not found' },
        { status: 404 }
      );
    }

    const profileData = profile[0];

    // Check if PINs are set
    if (!profileData.safe_pin_hash || !profileData.danger_pin_hash) {
      return NextResponse.json(
        { success: false, message: 'PINs not set up for this user' },
        { status: 400 }
      );
    }

    // Verify against both PINs
    const isSafePin = await bcrypt.compare(pin, profileData.safe_pin_hash);
    const isDangerPin = await bcrypt.compare(pin, profileData.danger_pin_hash);

    if (!isSafePin && !isDangerPin) {
      return NextResponse.json(
        { success: false, message: 'Invalid PIN' },
        { status: 401 }
      );
    }

    const now = new Date();

    // Handle SAFE PIN
    if (isSafePin) {
      await db
        .update(SAFETY_CHECKINS)
        .set({
          status: 'acknowledged_safe',
          pin_type_used: 'safe',
          user_response_time: now,
          updated_at: now,
        })
        .where(eq(SAFETY_CHECKINS.id, checkin_id));

      // IMPORTANT: Same response for both safe and danger
      return NextResponse.json(
        {
          success: true,
          message: 'Check-in completed successfully',
          data: {
            checkin_id,
            status: 'completed',
            timestamp: now,
          },
        },
        { status: 200 }
      );
    }

    // Handle DANGER PIN - SILENT ALERT
    if (isDangerPin) {
      // Update check-in
      await db
        .update(SAFETY_CHECKINS)
        .set({
          status: 'acknowledged_danger',
          pin_type_used: 'danger',
          user_response_time: now,
          updated_at: now,
        })
        .where(eq(SAFETY_CHECKINS.id, checkin_id));

      // Create CRITICAL alert
      const alertResult = await db
        .insert(SAFETY_ALERTS)
        .values({
          checkin_id,
          user_id: checkinData.user_id,
          org_id: checkinData.org_id,
          alert_type: 'danger_pin_entered',
          priority: 'critical',
          alert_status: 'pending',
          alert_sent_at: now,
        });

      // TODO: Send push notification to admins
      // This should be handled by a separate notification service
      // For now, just log it
      console.log('🚨 CRITICAL ALERT: Danger PIN entered by user', checkinData.user_id);

      // Log notification attempt
      await db
        .insert(NOTIFICATION_LOGS)
        .values({
          checkin_id,
          user_id: checkinData.user_id,
          notification_type: 'admin_alert',
          sent_at: now,
          delivery_status: 'sent',
        });

      // IMPORTANT: Return IDENTICAL response to safe PIN
      // This is critical so attacker doesn't know danger PIN was entered
      return NextResponse.json(
        {
          success: true,
          message: 'Check-in completed successfully',
          data: {
            checkin_id,
            status: 'completed',
            timestamp: now,
          },
        },
        { status: 200 }
      );
    }

  } catch (error) {
    console.error('Check-in verify error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}

/**
 * POST /api/mobile-api/checkins/snooze
 * Snooze a check-in
 */
export async function PUT(request) {
  try {
    const body = await request.json();
    const { checkin_id } = body;

    if (!checkin_id) {
      return NextResponse.json(
        { success: false, message: 'checkin_id is required' },
        { status: 400 }
      );
    }

    // Get check-in
    const checkin = await db
      .select()
      .from(SAFETY_CHECKINS)
      .where(eq(SAFETY_CHECKINS.id, checkin_id))
      .limit(1);

    if (!checkin || checkin.length === 0) {
      return NextResponse.json(
        { success: false, message: 'Check-in not found' },
        { status: 404 }
      );
    }

    const checkinData = checkin[0];

    // Check if max snooze attempts reached (3)
    if (checkinData.snooze_count >= 3) {
      return NextResponse.json(
        { success: false, message: 'Maximum snooze attempts reached' },
        { status: 400 }
      );
    }

    const now = new Date();

    // Update check-in
    await db
      .update(SAFETY_CHECKINS)
      .set({
        status: 'snoozed',
        snooze_count: checkinData.snooze_count + 1,
        last_snooze_at: now,
        updated_at: now,
      })
      .where(eq(SAFETY_CHECKINS.id, checkin_id));

    return NextResponse.json(
      {
        success: true,
        message: 'Check-in snoozed',
        data: {
          checkin_id,
          snooze_count: checkinData.snooze_count + 1,
          remaining_snoozes: 3 - (checkinData.snooze_count + 1),
        },
      },
      { status: 200 }
    );

  } catch (error) {
    console.error('Snooze error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}