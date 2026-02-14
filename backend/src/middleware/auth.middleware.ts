import type { Context, Next } from 'hono';
import { createClient } from '@supabase/supabase-js';
import type { Env } from '../config/env';

export function authMiddleware(c: Context<{ Bindings: Env; Variables: { userId: string } }>, next: Next) {
  const authHeader = c.req.header('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');

  if (!token) {
    return c.json(
      {
        error: {
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        },
      },
      401
    );
  }

  const supabaseUrl = c.env?.SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseKey = c.env?.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return c.json(
      {
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Server configuration error',
        },
      },
      500
    );
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  return (async () => {
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser(token);

    if (error || !user) {
      return c.json(
        {
          error: {
            code: 'UNAUTHORIZED',
            message: error?.message ?? 'Invalid or expired token',
          },
        },
        401
      );
    }

    c.set('userId', user.id);
    await next();
  })();
}
