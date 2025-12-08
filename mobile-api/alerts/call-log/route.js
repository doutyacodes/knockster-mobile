import { db } from '@/utils';
import { ADMIN_CALL_LOGS } from '@/utils/schema/schema';
import { NextResponse } from 'next/server';

/**
 * POST /api/mobile-api/alerts/call-log
 * Log an admin call to a user
 */
export async function POST(request) {
  try {
    const body = await request.json();
    const { 
      alert_id, 
      admin_id, 
      user_id, 
      call_status, 
      call_duration_seconds, 
      notes 
    } = body;

    // Validation
    if (!alert_id || !admin_id || !user_id || !call_status) {
      return NextResponse.json(
        { success: false, message: 'alert_id, admin_id, user_id, and call_status are required' },
        { status: 400 }
      );
    }

    // Validate call_status
    const validStatuses = [
      'initiated',
      'ringing',
      'attended_safe',
      'attended_not_safe',
      'not_attended',
      'failed'
    ];

    if (!validStatuses.includes(call_status)) {
      return NextResponse.json(
        { success: false, message: 'Invalid call_status' },
        { status: 400 }
      );
    }

    // Create call log
    const result = await db
      .insert(ADMIN_CALL_LOGS)
      .values({
        alert_id,
        admin_id,
        user_id,
        call_status,
        call_duration_seconds: call_duration_seconds || null,
        notes: notes || null,
      });

    return NextResponse.json(
      {
        success: true,
        message: 'Call logged successfully',
        data: {
          call_log_id: result[0].insertId,
          alert_id,
          call_status,
        },
      },
      { status: 201 }
    );

  } catch (error) {
    console.error('Call log error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}