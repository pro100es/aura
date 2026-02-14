-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 001: Core Tables & Indexes
-- Created: 2026-01-15
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TABLE: profiles
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    subscription_tier TEXT NOT NULL DEFAULT 'free' 
        CHECK (subscription_tier IN ('free', 'pro')),
    revenue_cat_id TEXT UNIQUE,
    subscription_started_at TIMESTAMPTZ,
    subscription_expires_at TIMESTAMPTZ,
    generations_used_today INTEGER NOT NULL DEFAULT 0,
    total_generations INTEGER NOT NULL DEFAULT 0,
    last_generation_reset DATE DEFAULT CURRENT_DATE,
    preferred_mode TEXT CHECK (preferred_mode IN ('persona', 'object', 'vibe')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT email_format CHECK (
        email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'
    ),
    CONSTRAINT valid_subscription_dates CHECK (
        subscription_started_at IS NULL OR 
        subscription_expires_at IS NULL OR
        subscription_started_at < subscription_expires_at
    )
);

CREATE INDEX idx_profiles_subscription ON public.profiles(subscription_tier);
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_revenue_cat ON public.profiles(revenue_cat_id) WHERE revenue_cat_id IS NOT NULL;
CREATE INDEX idx_profiles_active_subscription ON public.profiles(subscription_tier, subscription_expires_at);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE 
    USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ============================================================================
-- TABLE: presets
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.presets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    prompt_template TEXT NOT NULL,
    negative_prompt TEXT NOT NULL DEFAULT '',
    mode TEXT NOT NULL CHECK (mode IN ('persona', 'object', 'vibe')),
    replicate_model TEXT,
    parameters JSONB NOT NULL DEFAULT '{"guidance_scale": 3.5, "num_inference_steps": 28, "aspect_ratio": "4:5", "ip_adapter_scale": 0.8}'::jsonb,
    icon_url TEXT,
    thumbnail_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_premium BOOLEAN NOT NULL DEFAULT false,
    sort_order INTEGER NOT NULL DEFAULT 0,
    usage_count INTEGER NOT NULL DEFAULT 0,
    avg_rating NUMERIC(3,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT slug_format CHECK (slug ~* '^[a-z0-9-]+$'),
    CONSTRAINT valid_parameters CHECK (
        jsonb_typeof(parameters) = 'object' AND
        (
            (parameters->>'guidance_scale') IS NULL OR
            ((parameters->>'guidance_scale')::numeric BETWEEN 0.1 AND 20)
        ) AND
        (
            (parameters->>'num_inference_steps') IS NULL OR
            ((parameters->>'num_inference_steps')::integer BETWEEN 1 AND 100)
        )
    ),
    CONSTRAINT valid_rating CHECK (avg_rating IS NULL OR (avg_rating >= 0 AND avg_rating <= 5))
);

CREATE UNIQUE INDEX idx_presets_slug ON public.presets(slug);
CREATE INDEX idx_presets_mode ON public.presets(mode);
CREATE INDEX idx_presets_active ON public.presets(is_active, sort_order) WHERE is_active = true;
CREATE INDEX idx_presets_usage ON public.presets(usage_count DESC);
CREATE INDEX idx_presets_premium ON public.presets(is_premium) WHERE is_premium = true;

ALTER TABLE public.presets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "presets_select_active" ON public.presets FOR SELECT USING (is_active = true);
CREATE POLICY "presets_all_service_role" ON public.presets FOR ALL
    USING (auth.jwt()->>'role' = 'service_role')
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- TABLE: user_uploads
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    file_size_bytes INTEGER NOT NULL,
    mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
    type TEXT NOT NULL CHECK (type IN ('face', 'object', 'scene')),
    width INTEGER,
    height INTEGER,
    blurhash TEXT,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT valid_file_size CHECK (file_size_bytes > 0 AND file_size_bytes <= 10485760),
    CONSTRAINT valid_dimensions CHECK (
        (width IS NULL AND height IS NULL) OR
        (width > 0 AND height > 0)
    )
);

CREATE INDEX idx_user_uploads_user ON public.user_uploads(user_id, created_at DESC);
CREATE INDEX idx_user_uploads_expires ON public.user_uploads(expires_at);

ALTER TABLE public.user_uploads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_uploads_select_own" ON public.user_uploads FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_uploads_insert_own" ON public.user_uploads FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_uploads_delete_own" ON public.user_uploads FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- TABLE: generations
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    preset_id UUID NOT NULL REFERENCES public.presets(id),
    replicate_id TEXT,
    status TEXT NOT NULL DEFAULT 'starting'
        CHECK (status IN ('starting', 'processing', 'succeeded', 'failed', 'canceled')),
    input_params JSONB NOT NULL,
    error_message TEXT,
    error_code TEXT,
    error_details JSONB,
    processing_time_seconds NUMERIC(6,2),
    queue_time_seconds NUMERIC(6,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    CONSTRAINT valid_status_timestamps CHECK (
        (status IN ('succeeded', 'failed', 'canceled') AND completed_at IS NOT NULL) OR
        (status NOT IN ('succeeded', 'failed', 'canceled'))
    ),
    CONSTRAINT valid_replicate_id CHECK (replicate_id IS NULL OR length(replicate_id) > 0)
);

CREATE INDEX idx_generations_user_created ON public.generations(user_id, created_at DESC);
CREATE INDEX idx_generations_user_status ON public.generations(user_id, status);
CREATE INDEX idx_generations_status_active ON public.generations(status) WHERE status IN ('starting', 'processing');
CREATE INDEX idx_generations_replicate ON public.generations(replicate_id) WHERE replicate_id IS NOT NULL;
CREATE INDEX idx_generations_preset ON public.generations(preset_id);
CREATE INDEX idx_generations_polling ON public.generations(id, status, completed_at) WHERE status IN ('starting', 'processing');

ALTER TABLE public.generations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "generations_select_own" ON public.generations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "generations_insert_own" ON public.generations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "generations_update_own" ON public.generations FOR UPDATE 
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "generations_update_service" ON public.generations FOR UPDATE
    USING (auth.jwt()->>'role' = 'service_role')
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- TABLE: generation_assets
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.generation_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    generation_id UUID NOT NULL REFERENCES public.generations(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    variant TEXT NOT NULL CHECK (variant IN ('safe_match', 'editorial', 'lifestyle', 'artistic', 'custom')),
    width INTEGER,
    height INTEGER,
    file_size_bytes INTEGER,
    blurhash TEXT,
    is_favorite BOOLEAN NOT NULL DEFAULT false,
    download_count INTEGER NOT NULL DEFAULT 0,
    share_count INTEGER NOT NULL DEFAULT 0,
    upscaled_url TEXT,
    upscaled_at TIMESTAMPTZ,
    watermark_removed BOOLEAN NOT NULL DEFAULT false,
    ai_metadata JSONB DEFAULT '{"model": "flux-1-dev", "generated_by": "Aura", "is_ai_generated": true}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT valid_dimensions CHECK (
        (width IS NULL AND height IS NULL) OR
        (width > 0 AND height > 0 AND width <= 8192 AND height <= 8192)
    ),
    CONSTRAINT valid_file_size CHECK (
        file_size_bytes IS NULL OR 
        (file_size_bytes > 0 AND file_size_bytes <= 52428800)
    )
);

CREATE INDEX idx_assets_generation ON public.generation_assets(generation_id);
CREATE INDEX idx_assets_user_favorite ON public.generation_assets(generation_id, is_favorite) WHERE is_favorite = true;
CREATE INDEX idx_assets_variant ON public.generation_assets(variant);
CREATE INDEX idx_assets_created ON public.generation_assets(created_at DESC);

ALTER TABLE public.generation_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "assets_select_via_generation" ON public.generation_assets FOR SELECT
    USING (EXISTS (SELECT 1 FROM public.generations g WHERE g.id = generation_id AND g.user_id = auth.uid()));

CREATE POLICY "assets_update_via_generation" ON public.generation_assets FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.generations g WHERE g.id = generation_id AND g.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.generations g WHERE g.id = generation_id AND g.user_id = auth.uid()));

CREATE POLICY "assets_insert_service" ON public.generation_assets FOR INSERT
    WITH CHECK (
        auth.jwt()->>'role' = 'service_role' OR
        EXISTS (SELECT 1 FROM public.generations g WHERE g.id = generation_id AND g.user_id = auth.uid())
    );

-- ============================================================================
-- Grant permissions
-- ============================================================================

GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;

DO $$
BEGIN
    RAISE NOTICE 'Migration 001 completed successfully';
END $$;
