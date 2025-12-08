import { db } from '@/utils';
import { USERS, USER_PROFILES, USER_ROLES } from '@/utils/schema/schema';
import { eq } from 'drizzle-orm';
import bcrypt from 'bcryptjs';
import { NextResponse } from 'next/server';

/**
 * POST /api/mobile-api/auth/register
 * Register new user
 */
export async function POST(request) {
  try {
    const body = await request.json();
    const { email, password, full_name, phone } = body;

    // Validation
    if (!email || !password) {
      return NextResponse.json(
        { success: false, message: 'Email and password are required' },
        { status: 400 }
      );
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return NextResponse.json(
        { success: false, message: 'Invalid email format' },
        { status: 400 }
      );
    }

    // Password strength validation
    if (password.length < 6) {
      return NextResponse.json(
        { success: false, message: 'Password must be at least 6 characters' },
        { status: 400 }
      );
    }

    // Check if email already exists
    const existingUser = await db
      .select()
      .from(USERS)
      .where(eq(USERS.email, email))
      .limit(1);

    if (existingUser && existingUser.length > 0) {
      return NextResponse.json(
        { success: false, message: 'Email already registered' },
        { status: 409 }
      );
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 10);

    // Create user
    const newUser = await db
      .insert(USERS)
      .values({
        email,
        password_hash,
        status: 'active',
        timezone: 'UTC',
      });

    const userId = newUser[0].insertId;

    // Create user profile
    await db
      .insert(USER_PROFILES)
      .values({
        user_id: userId,
        full_name: full_name || null,
        phone: phone || null,
      });

    // Assign default 'user' role (role_id: 4)
    await db
      .insert(USER_ROLES)
      .values({
        user_id: userId,
        role_id: 4, // 'user' role
      });

    return NextResponse.json(
      {
        success: true,
        message: 'Registration successful',
        data: {
          user_id: userId,
          email,
          full_name,
        },
      },
      { status: 201 }
    );

  } catch (error) {
    console.error('Registration error:', error);
    return NextResponse.json(
      { success: false, message: 'Internal server error', error: error.message },
      { status: 500 }
    );
  }
}