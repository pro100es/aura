import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { prettyJSON } from 'hono/pretty-json';

import { authMiddleware } from './middleware/auth.middleware';
import { errorMiddleware } from './middleware/error.middleware';

import presetsRoutes from './routes/presets';
import generationsRoutes from './routes/generations';
import webhooksRoutes from './routes/webhooks';

type Env = Record<string, string>;
type Variables = { userId: string };

const app = new Hono<{ Bindings: Env; Variables: Variables }>();

app.use('*', logger());
app.use('*', prettyJSON());
app.use(
  '*',
  cors({
    origin: ['aura://app', 'capacitor://localhost', 'http://localhost:3000', 'http://localhost:5173'],
    credentials: true,
  })
);

app.get('/health', (c) => {
  return c.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '2.0.0',
  });
});

app.use('/presets/*', authMiddleware as () => Promise<void>);
app.use('/generations/*', authMiddleware as () => Promise<void>);

app.route('/presets', presetsRoutes);
app.route('/generations', generationsRoutes);
app.route('/webhooks', webhooksRoutes);

app.onError(errorMiddleware);

export default app;

if (import.meta.main) {
  const port = parseInt(process.env.PORT ?? '3000', 10);
  console.log(`Aura API running on http://localhost:${port}`);
  Bun.serve({
    fetch: app.fetch,
    port,
  });
}
