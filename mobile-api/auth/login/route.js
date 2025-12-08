import { db } from '@/utils';
import { USERS, USER_PROFILES, ORG_USERS, ORGANISATIONS, ROLES } from '@/utils/schema/schema';
import { eq, and } from 'drizzle-orm';
import bcrypt from 'bcryptjs';
import { NextResponse } from 'next/server';

/**
 * POST /api/mobile-api/auth/login
 * Login user with email and password
 */
export async function POST(request) {
  try {
    const body = await request.json();
    const { email, password } = body;

    // Validation
    if (!email || !password) {
      return NextResponse.json(
        { success: false, message: 'Email and password are required' },
        { status: 400 }
      );
    }

    // Find user by email
    const user = await db
      .select()
      .from(USERS)
      .where(eq(USERS.email, email))
      .limit(1);

    if (!user || user.length === 0) {
      return NextResponse.json(
        { success: false, message: 'Invalid email or password' },
        { status: 401 }
      );
    }

    const userData = user[0];

    // Check if user is active
    if (userData.status !== 'active') {
      return NextResponse.json(
        { success: false, message: 'Account is suspended or deleted' },
        { status: 403 }
      );
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, userData.password_hash);

    if (!isPasswordValid) {
      return NextResponse.json(
        { success: false, message: 'Invalid email or password' },
        { status: 401 }
      );
    }

    // Get user profile
    const profile = await db
      .select()
      .from(USER_PROFILES)
      .where(eq(USER_PROFILES.user_id, userData.id))
      .limit(1);

    // Get user organizations and roles
    const userOrgs = await db
      .select({
        org_id: ORG_USERS.org_id,
        role_id: ORG_USERS.role_id,
        is_primary_admin: ORG_USERS.is_primary_admin,
        org_name: ORGANISATIONS.name,
        org_type: ORGANISATIONS.type,
        role_name: ROLES.name,
        role_display_name: ROLES.display_name,
      })
      .from(ORG_USERS)
      .leftJoin(ORGANISATIONS, eq(ORG_USERS.org_id, ORGANISATIONS.id))
      .leftJoin(ROLES, eq(ORG_USERS.role_id, ROLES.id))
      .where(
        and(
          eq(ORG_USERS.user_id, userData.id),
          eq(ORG_USERS.status, 'active')
        )
      );

    // Check if PINs are set
    const hasPinsSet = profile[0]?.safe_pin_hash && profile[0]?.danger_pin_hash;

    // Prepare response
    const response = {
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: userData.id,
          email: userData.email,
          status: userData.status,
          timezone: userData.timezone,
          created_at: userData.created_at,
        },
        profile: profile[0] ? {
          id: profile[0].id,
          full_name: profile[0].full_name,
          phone: profile[0].phone,
          profile_pic_url: profile[0].profile_pic_url,
          emergency_contact_name: profile[0].emergency_contact_name,
          emergency_contact_phone: profile[0].emergency_contact_phone,
          has_pins_set: hasPinsSet,
        } : null,
        organizations: userOrgs,
        // Flag for onboarding
        needs_pin_setup: !hasPinsSet,
      },
    };

    return NextResponse.json(response, { status: 200 });

  } catch (error) {
    console.error('Login error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}