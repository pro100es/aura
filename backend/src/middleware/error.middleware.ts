import type { Context } from 'hono';
import { HTTPException } from 'hono/http-exception';

export function errorMiddleware(err: Error, c: Context): Response {
  if (err instanceof HTTPException) {
    return c.json(
      {
        error: {
          code: err.message,
          message: err.message,
        },
      },
      err.status as 400 | 401 | 402 | 403 | 404 | 429 | 500
    );
  }

  console.error('[API Error]', err);

  return c.json(
    {
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred',
        request_id: crypto.randomUUID(),
      },
    },
    500
  );
}
