export type PresetMode = 'persona' | 'object' | 'vibe';

export interface Preset {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  mode: PresetMode;
  icon_url: string | null;
  thumbnail_url: string | null;
  is_premium: boolean;
  parameters: Record<string, unknown>;
}

export interface PresetsResponse {
  data: Preset[];
  meta: {
    total: number;
    page: number;
    limit: number;
    has_more: boolean;
  };
}

export interface ApiError {
  code: string;
  message: string;
  details?: Array<{ field: string; message: string }>;
  request_id?: string;
}
