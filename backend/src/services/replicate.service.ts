/**
 * Replicate AI service for image generation
 * Supports InstantID (persona) and ControlNet (object) models
 */
import Replicate from 'replicate';

export interface PresetForGeneration {
  replicate_model: string | null;
  prompt_template: string;
  negative_prompt: string;
  parameters: Record<string, unknown>;
  mode: string;
}

export interface CreatePredictionInput {
  preset: PresetForGeneration;
  imageUrl: string;
  aspectRatio?: string;
  customPrompt?: string;
}

export interface PredictionResult {
  id: string;
  status: string;
  urls?: { get: string; cancel: string };
}

const GLOBAL_PREFIX =
  'professional commercial photography, high-end editorial, shot on 35mm lens, f/1.8, incredibly detailed, realistic skin textures, natural lighting, sharp focus, 8k resolution, cinematic composition';

function buildPrompt(preset: PresetForGeneration, customPrompt?: string): string {
  const parts = [GLOBAL_PREFIX, preset.prompt_template];
  if (customPrompt?.trim()) {
    parts.push(customPrompt.trim());
  }
  return parts.join(', ');
}

function buildInput(params: CreatePredictionInput): Record<string, unknown> {
  const { preset, imageUrl, aspectRatio = '4:5', customPrompt } = params;
  const prompt = buildPrompt(preset, customPrompt);
  const baseParams = (preset.parameters || {}) as Record<string, unknown>;

  const input: Record<string, unknown> = {
    image: imageUrl,
    prompt,
    negative_prompt: preset.negative_prompt || 'deformed, blurry, low quality',
    ...baseParams,
  };

  if (aspectRatio) {
    input.aspect_ratio = aspectRatio;
  }

  return input;
}

export async function createPrediction(
  params: CreatePredictionInput,
  options?: {
    webhookUrl?: string;
    webhookEvents?: string[];
  }
): Promise<PredictionResult> {
  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) {
    throw new Error('REPLICATE_API_TOKEN is not set');
  }

  const model = params.preset.replicate_model;
  if (!model) {
    throw new Error('Preset has no replicate_model configured');
  }

  const replicate = new Replicate({ auth: token });
  const input = buildInput(params);

  const predictionOptions: Parameters<typeof replicate.predictions.create>[0] = {
    model,
    input: input as Record<string, string>,
  };

  if (options?.webhookUrl) {
    predictionOptions.webhook = options.webhookUrl;
    predictionOptions.webhook_events_filter = options.webhookEvents ?? ['completed'];
  }

  const prediction = await replicate.predictions.create(predictionOptions);

  return {
    id: prediction.id!,
    status: prediction.status ?? 'starting',
    urls: prediction.urls as { get: string; cancel: string } | undefined,
  };
}

export async function cancelPrediction(replicateId: string): Promise<void> {
  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) throw new Error('REPLICATE_API_TOKEN is not set');

  const replicate = new Replicate({ auth: token });
  await replicate.predictions.cancel(replicateId);
}
