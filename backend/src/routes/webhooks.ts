import { Hono } from 'hono';

type WebhooksContext = {
  Bindings: Record<string, string>;
};

const webhooks = new Hono<WebhooksContext>();

webhooks.post('/replicate', async (c) => {
  const secret = c.req.header('X-Webhook-Secret');
  const webhookSecret = c.env?.WEBHOOK_SECRET ?? process.env.WEBHOOK_SECRET;

  if (webhookSecret && secret !== webhookSecret) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  let body: {
    id?: string;
    status?: string;
    output?: string[];
    metrics?: { predict_time?: number };
    error?: string;
  };

  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: 'Invalid JSON' }, 400);
  }

  const replicateId = body.id;
  const status = body.status;
  const predictTime = body.metrics?.predict_time;
  const errorMsg = body.error;

  if (!replicateId || !status) {
    return c.json({ error: 'Missing id or status' }, 400);
  }

  const supabaseUrl = c.env?.SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseKey = c.env?.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    return c.json({ error: 'Configuration error' }, 500);
  }

  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(supabaseUrl, supabaseKey);

  const mapStatus = (s: string) => {
    if (['succeeded', 'failed', 'canceled'].includes(s)) return s;
    return s === 'succeeded' ? 'succeeded' : 'processing';
  };

  const { data, error } = await supabase.rpc('update_generation_status', {
    p_replicate_id: replicateId,
    p_status: mapStatus(status),
    p_error_message: errorMsg ?? null,
    p_processing_time: predictTime ?? null,
  });

  if (error) {
    return c.json({ error: error.message }, 500);
  }

  const result = Array.isArray(data) ? data[0] : data;
  if (result?.updated && status === 'succeeded' && body.output?.length && result.generation_id && result.user_id) {
    const variants = ['safe_match', 'editorial', 'lifestyle', 'artistic'] as const;
    for (let i = 0; i < body.output!.length; i++) {
      const outputUrl = body.output![i];
      const variant = variants[i] ?? 'custom';
      try {
        const res = await fetch(outputUrl);
        if (!res.ok) continue;
        const blob = await res.arrayBuffer();
        const path = `${result.user_id}/${result.generation_id}_${i + 1}.jpg`;
        const { error: uploadError } = await supabase.storage
          .from('results')
          .upload(path, blob, { contentType: 'image/jpeg', upsert: true });
        if (uploadError) continue;
        await supabase.from('generation_assets').insert({
          generation_id: result.generation_id,
          image_url: path,
          variant,
        });
      } catch {
        // Skip failed asset
      }
    }
  }

  return c.json({ received: true });
});

export default webhooks;
