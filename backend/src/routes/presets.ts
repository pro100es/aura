import { Hono } from 'hono';
import { createClient } from '@supabase/supabase-js';
import type { PresetsResponse } from '../types/api.types';

type PresetsContext = {
  Bindings: Record<string, string>;
  Variables: { userId: string };
};

const presets = new Hono<PresetsContext>();

presets.get('/', async (c) => {
  const mode = c.req.query('mode') as 'persona' | 'object' | 'vibe' | undefined;
  const page = Math.max(1, parseInt(c.req.query('page') ?? '1', 10));
  const limit = Math.min(50, Math.max(1, parseInt(c.req.query('limit') ?? '20', 10)));

  const supabaseUrl = c.env?.SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseKey = c.env?.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return c.json(
      { error: { code: 'INTERNAL_ERROR', message: 'Failed to fetch presets' } },
      500
    );
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  let query = supabase
    .from('presets')
    .select('id, name, slug, description, mode, icon_url, thumbnail_url, is_premium, parameters', { count: 'exact' })
    .eq('is_active', true)
    .order('sort_order', { ascending: true });

  if (mode && ['persona', 'object', 'vibe'].includes(mode)) {
    query = query.eq('mode', mode);
  }

  const from = (page - 1) * limit;
  const { data, error, count } = await query.range(from, from + limit - 1);

  if (error) {
    return c.json(
      { error: { code: 'INTERNAL_ERROR', message: 'Failed to fetch presets' } },
      500
    );
  }

  const response: PresetsResponse = {
    data: (data ?? []).map((p) => ({
      id: p.id,
      name: p.name,
      slug: p.slug,
      description: p.description ?? null,
      mode: p.mode,
      icon_url: p.icon_url ?? null,
      thumbnail_url: p.thumbnail_url ?? null,
      is_premium: p.is_premium ?? false,
      parameters: (p.parameters as Record<string, unknown>) ?? {},
    })),
    meta: {
      total: count ?? 0,
      page,
      limit,
      has_more: (count ?? 0) > from + (data?.length ?? 0),
    },
  };

  return c.json(response);
});

export default presets;
