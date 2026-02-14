import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';

type GenerationsContext = {
  Bindings: Record<string, string>;
  Variables: { userId: string };
};

const CreateGenerationSchema = z.object({
  preset_id: z.string().uuid(),
  image_url: z.string().url(),
  aspect_ratio: z.enum(['1:1', '4:5', '16:9']).optional(),
  batch_size: z.number().int().min(1).max(4).optional().default(4),
  custom_prompt: z.string().max(500).optional(),
});

const generations = new Hono<GenerationsContext>();

generations.get('/', async (c) => {
  const userId = c.get('userId');
  const page = Math.max(1, parseInt(c.req.query('page') ?? '1', 10));
  const limit = Math.min(50, Math.max(1, parseInt(c.req.query('limit') ?? '20', 10)));
  const presetId = c.req.query('preset_id') ?? undefined;
  const status = c.req.query('status') ?? undefined;

  const supabaseUrl = c.env?.SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseKey = c.env?.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return c.json({ error: { code: 'INTERNAL_ERROR', message: 'Configuration error' } }, 500);
  }

  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data, error } = await supabase.rpc('get_user_gallery', {
    p_user_id: userId,
    p_page: page,
    p_limit: limit,
    p_preset_id: presetId || null,
    p_status: status || null,
    p_favorites_only: false,
  });

  if (error) {
    return c.json({ error: { code: 'INTERNAL_ERROR', message: error.message } }, 500);
  }

  const rows = (data ?? []) as Array<{
    generation_id: string;
    preset_name: string;
    preset_slug: string;
    preset_icon_url: string;
    status: string;
    created_at: string;
    completed_at: string;
    processing_time: number;
    outputs: unknown[];
    total_count: number;
  }>;

  const mapped = rows.map((r) => ({
    id: r.generation_id,
    preset: { name: r.preset_name, slug: r.preset_slug, icon_url: r.preset_icon_url },
    status: r.status,
    outputs: r.outputs ?? [],
    created_at: r.created_at,
    completed_at: r.completed_at,
  }));

  const total = rows[0]?.total_count ?? 0;

  return c.json({
    data: mapped,
    meta: {
      total,
      page,
      limit,
      has_more: total > page * limit,
    },
  });
});

generations.post('/', zValidator('json', CreateGenerationSchema), async (c) => {
  const userId = c.get('userId');
  const body = c.req.valid('json');

  const supabaseUrl = c.env?.SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseKey = c.env?.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return c.json({ error: { code: 'INTERNAL_ERROR', message: 'Configuration error' } }, 500);
  }

  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data: limitData, error: limitError } = await supabase.rpc('check_generation_limit', {
    p_user_id: userId,
  });

  if (limitError) {
    return c.json({ error: { code: 'INTERNAL_ERROR', message: limitError.message } }, 500);
  }

  const limitResult = Array.isArray(limitData) ? limitData[0] : limitData;
  if (!limitResult?.can_generate) {
    return c.json(
      {
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message: limitResult?.reason ?? 'Daily limit exceeded',
          upgrade_url: 'aura://paywall',
        },
      },
      429
    );
  }

  const { data: preset, error: presetError } = await supabase
    .from('presets')
    .select('id, is_premium, replicate_model, prompt_template, negative_prompt, parameters, mode')
    .eq('id', body.preset_id)
    .single();

  if (presetError || !preset) {
    return c.json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid preset_id' } }, 400);
  }

  if (preset.is_premium && limitResult?.subscription_tier === 'free') {
    return c.json(
      {
        error: {
          code: 'SUBSCRIPTION_REQUIRED',
          message: 'Active Pro subscription needed for this preset',
          upgrade_url: 'aura://paywall',
        },
      },
      402
    );
  }

  if (body.custom_prompt) {
    const { data: validation } = await supabase.rpc('validate_prompt', {
      p_prompt: body.custom_prompt,
    });
    const result = Array.isArray(validation) ? validation[0] : validation;
    if (result && !result.is_valid) {
      return c.json(
        {
          error: {
            code: 'CONTENT_MODERATION',
            message: result.message ?? 'Prompt contains blocked content',
          },
        },
        400
      );
    }
  }

  const inputParams = {
    preset_id: body.preset_id,
    image_url: body.image_url,
    aspect_ratio: body.aspect_ratio ?? '4:5',
    batch_size: body.batch_size ?? 4,
    custom_prompt: body.custom_prompt,
  };

  const { data: gen, error: insertError } = await supabase
    .from('generations')
    .insert({
      user_id: userId,
      preset_id: body.preset_id,
      status: 'starting',
      input_params: inputParams,
    })
    .select('id')
    .single();

  if (insertError) {
    return c.json({ error: { code: 'INTERNAL_ERROR', message: insertError.message } }, 500);
  }

  let replicateId: string | null = null;
  let webhookRegistered = false;
  const apiUrl = c.env?.API_URL ?? process.env.API_URL;

  try {
    const { createPrediction } = await import('../services/replicate.service');
    const prediction = await createPrediction(
      {
        preset: {
          replicate_model: preset.replicate_model,
          prompt_template: preset.prompt_template,
          negative_prompt: preset.negative_prompt,
          parameters: (preset.parameters as Record<string, unknown>) ?? {},
          mode: preset.mode,
        },
        imageUrl: body.image_url,
        aspectRatio: body.aspect_ratio ?? '4:5',
        customPrompt: body.custom_prompt,
      },
      apiUrl
        ? {
            webhookUrl: `${apiUrl.replace(/\/$/, '')}/webhooks/replicate`,
            webhookEvents: ['completed'],
          }
        : undefined
    );

    replicateId = prediction.id;
    webhookRegistered = !!apiUrl;

    await supabase
      .from('generations')
      .update({
        replicate_id: replicateId,
        status: 'processing',
        started_at: new Date().toISOString(),
      })
      .eq('id', gen.id);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Replicate API error';
    await supabase
      .from('generations')
      .update({
        status: 'failed',
        error_message: message,
        error_code: 'REPLICATE_ERROR',
        completed_at: new Date().toISOString(),
      })
      .eq('id', gen.id);

    return c.json(
      {
        error: {
          code: 'GENERATION_FAILED',
          message: 'Failed to start image generation',
          details: message,
        },
      },
      503
    );
  }

  return c.json(
    {
      data: {
        generation_id: gen.id,
        status: 'processing',
        replicate_ids: replicateId ? [replicateId] : [],
        estimated_time_seconds: 25,
        webhook_registered: webhookRegistered,
        poll_url: `/generations/${gen.id}`,
      },
    },
    201
  );
});

generations.get('/:id', async (c) => {
  const userId = c.get('userId');
  const id = c.req.param('id');

  const supabaseUrl = c.env?.SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseKey = c.env?.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return c.json({ error: { code: 'INTERNAL_ERROR', message: 'Configuration error' } }, 500);
  }

  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data: gen, error } = await supabase
    .from('generations')
    .select('id, user_id, status, created_at, completed_at, processing_time_seconds, error_message, error_code')
    .eq('id', id)
    .single();

  if (error || !gen) {
    return c.json(
      { error: { code: 'GENERATION_NOT_FOUND', message: 'Generation not found' } },
      404
    );
  }

  if (gen.user_id !== userId) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Access denied' } }, 403);
  }

  let outputs: unknown[] = [];
  if (gen.status === 'succeeded') {
    const { data: assets } = await supabase
      .from('generation_assets')
      .select('id, image_url, variant, width, height, is_favorite')
      .eq('generation_id', id);
    if (assets?.length) {
      for (const a of assets) {
        const url = a.image_url.startsWith('http')
          ? a.image_url
          : (await supabase.storage.from('results').createSignedUrl(a.image_url, 3600)).data?.signedUrl ?? a.image_url;
        outputs.push({
          id: a.id,
          url,
          variant: a.variant,
          width: a.width,
          height: a.height,
          is_favorite: a.is_favorite,
        });
      }
    }
  }

  return c.json({
    data: {
      id: gen.id,
      status: gen.status,
      outputs,
      error: gen.status === 'failed' ? { code: gen.error_code, message: gen.error_message } : undefined,
      created_at: gen.created_at,
      completed_at: gen.completed_at,
      metadata: gen.processing_time_seconds
        ? { actual_time_seconds: gen.processing_time_seconds }
        : undefined,
    },
  });
});

generations.delete('/:id', async (c) => {
  const userId = c.get('userId');
  const id = c.req.param('id');

  const supabaseUrl = c.env?.SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseKey = c.env?.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return c.json({ error: { code: 'INTERNAL_ERROR', message: 'Configuration error' } }, 500);
  }

  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data: gen, error: fetchError } = await supabase
    .from('generations')
    .select('id, replicate_id, status')
    .eq('id', id)
    .eq('user_id', userId)
    .single();

  if (fetchError || !gen) {
    return c.json(
      { error: { code: 'GENERATION_NOT_FOUND', message: 'Generation not found' } },
      404
    );
  }

  if (gen.replicate_id && ['starting', 'processing'].includes(gen.status)) {
    try {
      const { cancelPrediction } = await import('../services/replicate.service');
      await cancelPrediction(gen.replicate_id);
    } catch {
      // Ignore cancel errors
    }
  }

  await supabase
    .from('generations')
    .update({ status: 'canceled', completed_at: new Date().toISOString() })
    .eq('id', id)
    .eq('user_id', userId);

  return c.json({ data: { id: gen.id, status: 'canceled', canceled_at: new Date().toISOString() } });
});

export default generations;
