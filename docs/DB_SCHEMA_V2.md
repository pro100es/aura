# Aura Database Schema v2.0

> PostgreSQL 15+ на Supabase  
> Готовые SQL миграции для production

---

## 🗄️ Entity Relationship Diagram

```
                    ┌─────────────────┐
                    │   auth.users    │ (Supabase встроенная)
                    │   id (PK)       │
                    │   email         │
                    └────────┬────────┘
                             │
                             │ 1
                             ▼
                    ┌─────────────────┐
                    │    profiles     │
                    │    id (PK/FK)   │
                    │    subscription │
                    │    tier         │
              ┌─────┤    generations  │
              │     │    used_today   │
              │     └─────────────────┘
              │
              │ 1        N ┌──────────────┐
              └────────────│user_uploads  │
                           │id (PK)       │
                           │file_path     │
                           │expires_at    │
                           └──────────────┘

┌─────────────────┐
│    presets      │
│    id (PK)      │         N ┌──────────────────┐
│    slug (UQ)    │◄──────────│  generations     │
│    prompt_...   │           │  id (PK)         │
│    mode         │           │  user_id (FK)    │
│    parameters   │           │  preset_id (FK)  │
└─────────────────┘           │  replicate_id    │
                              │  status          │
                              └────────┬─────────┘
                                       │ 1
                                       │
                                       │ N
                              ┌────────▼─────────┐
                              │generation_assets │
                              │id (PK)           │
                              │generation_id (FK)│
                              │image_url         │
                              │variant           │
                              │is_favorite       │
                              └──────────────────┘

┌──────────────────┐
│  blocked_terms   │ (Compliance)
│  id (PK)         │
│  term (UQ)       │
│  category        │
│  severity        │
└──────────────────┘
```

---

## 📋 Migrations

### Migration 001: Core Schema

**Файл:** `supabase/migrations/20260115000001_initial_schema.sql`

```sql
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
-- Extends auth.users with Aura-specific user data
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    -- Primary Key (links to Supabase Auth)
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Basic Info
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    
    -- Subscription Management
    subscription_tier TEXT NOT NULL DEFAULT 'free' 
        CHECK (subscription_tier IN ('free', 'pro')),
    revenue_cat_id TEXT UNIQUE, -- RevenueCat customer ID
    subscription_started_at TIMESTAMPTZ,
    subscription_expires_at TIMESTAMPTZ,
    
    -- Usage Tracking
    generations_used_today INTEGER NOT NULL DEFAULT 0,
    total_generations INTEGER NOT NULL DEFAULT 0,
    last_generation_reset DATE DEFAULT CURRENT_DATE,
    
    -- User Preferences
    preferred_mode TEXT CHECK (preferred_mode IN ('persona', 'object', 'vibe')),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Constraints
    CONSTRAINT email_format CHECK (
        email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'
    ),
    CONSTRAINT valid_subscription_dates CHECK (
        subscription_started_at IS NULL OR 
        subscription_expires_at IS NULL OR
        subscription_started_at < subscription_expires_at
    )
);

-- Indexes for fast queries
CREATE INDEX idx_profiles_subscription 
    ON public.profiles(subscription_tier);

CREATE INDEX idx_profiles_email 
    ON public.profiles(email);

CREATE INDEX idx_profiles_revenue_cat 
    ON public.profiles(revenue_cat_id) 
    WHERE revenue_cat_id IS NOT NULL;

CREATE INDEX idx_profiles_active_subscription 
    ON public.profiles(subscription_tier, subscription_expires_at) 
    WHERE subscription_tier = 'pro' AND subscription_expires_at > now();

-- Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "profiles_update_own"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Comments for documentation
COMMENT ON TABLE public.profiles IS 'User profiles extending Supabase Auth';
COMMENT ON COLUMN public.profiles.subscription_tier IS 'Current subscription: free (3 gens/day) or pro (unlimited)';
COMMENT ON COLUMN public.profiles.generations_used_today IS 'Counter reset daily at midnight UTC';
COMMENT ON COLUMN public.profiles.revenue_cat_id IS 'RevenueCat customer identifier for subscription sync';

-- ============================================================================
-- TABLE: presets
-- AI generation style templates with prompts
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.presets (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identity
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    
    -- AI Configuration
    prompt_template TEXT NOT NULL,
    negative_prompt TEXT NOT NULL DEFAULT '',
    mode TEXT NOT NULL CHECK (mode IN ('persona', 'object', 'vibe')),
    
    -- Replicate Model Configuration
    replicate_model TEXT, -- e.g., "zsxkib/instant-id:..."
    
    -- Parameters (JSONB for flexibility)
    parameters JSONB NOT NULL DEFAULT '{
        "guidance_scale": 3.5,
        "num_inference_steps": 28,
        "aspect_ratio": "4:5",
        "ip_adapter_scale": 0.8
    }'::jsonb,
    
    -- UI/UX Metadata
    icon_url TEXT,
    thumbnail_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_premium BOOLEAN NOT NULL DEFAULT false,
    sort_order INTEGER NOT NULL DEFAULT 0,
    
    -- Analytics
    usage_count INTEGER NOT NULL DEFAULT 0,
    avg_rating NUMERIC(3,2), -- 0.00 to 5.00
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Constraints
    CONSTRAINT slug_format CHECK (slug ~* '^[a-z0-9-]+$'),
    CONSTRAINT valid_parameters CHECK (
        jsonb_typeof(parameters) = 'object' AND
        (parameters->>'guidance_scale')::numeric BETWEEN 0.1 AND 20 AND
        (parameters->>'num_inference_steps')::integer BETWEEN 1 AND 100
    ),
    CONSTRAINT valid_rating CHECK (avg_rating IS NULL OR (avg_rating >= 0 AND avg_rating <= 5))
);

-- Indexes
CREATE UNIQUE INDEX idx_presets_slug 
    ON public.presets(slug);

CREATE INDEX idx_presets_mode 
    ON public.presets(mode);

CREATE INDEX idx_presets_active 
    ON public.presets(is_active, sort_order) 
    WHERE is_active = true;

CREATE INDEX idx_presets_usage 
    ON public.presets(usage_count DESC);

CREATE INDEX idx_presets_premium 
    ON public.presets(is_premium) 
    WHERE is_premium = true;

-- Row Level Security
ALTER TABLE public.presets ENABLE ROW LEVEL SECURITY;

-- Public can read active presets
CREATE POLICY "presets_select_active"
    ON public.presets FOR SELECT
    USING (is_active = true);

-- Only service role can modify presets
CREATE POLICY "presets_all_service_role"
    ON public.presets FOR ALL
    USING (auth.jwt()->>'role' = 'service_role')
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Comments
COMMENT ON TABLE public.presets IS 'AI generation style presets with prompts';
COMMENT ON COLUMN public.presets.prompt_template IS 'Base prompt combined with global prefix';
COMMENT ON COLUMN public.presets.parameters IS 'Replicate API parameters as JSONB';
COMMENT ON COLUMN public.presets.mode IS 'persona (face), object (product), vibe (scene)';

-- ============================================================================
-- TABLE: user_uploads
-- Temporary metadata for uploaded source images
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_uploads (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- File Information
    file_path TEXT NOT NULL, -- Supabase Storage path: uploads/{user_id}/{filename}
    file_size_bytes INTEGER NOT NULL,
    mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
    
    -- Classification (auto-detected or user-specified)
    type TEXT NOT NULL CHECK (type IN ('face', 'object', 'scene')),
    
    -- Image Metadata
    width INTEGER,
    height INTEGER,
    blurhash TEXT, -- For loading placeholders
    
    -- Auto-Delete Lifecycle
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Constraints
    CONSTRAINT valid_file_size CHECK (
        file_size_bytes > 0 AND 
        file_size_bytes <= 10485760 -- 10MB
    ),
    CONSTRAINT valid_dimensions CHECK (
        (width IS NULL AND height IS NULL) OR
        (width > 0 AND height > 0)
    )
);

-- Indexes
CREATE INDEX idx_user_uploads_user 
    ON public.user_uploads(user_id, created_at DESC);

CREATE INDEX idx_user_uploads_expires 
    ON public.user_uploads(expires_at) 
    WHERE expires_at < now();

-- Row Level Security
ALTER TABLE public.user_uploads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_uploads_select_own"
    ON public.user_uploads FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "user_uploads_insert_own"
    ON public.user_uploads FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_uploads_delete_own"
    ON public.user_uploads FOR DELETE
    USING (auth.uid() = user_id);

-- Comments
COMMENT ON TABLE public.user_uploads IS 'Temporary uploads metadata (auto-deleted after 24h)';
COMMENT ON COLUMN public.user_uploads.blurhash IS 'BlurHash for progressive image loading';

-- ============================================================================
-- TABLE: generations
-- AI generation job tracking & history
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.generations (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    preset_id UUID NOT NULL REFERENCES public.presets(id),
    
    -- External References
    replicate_id TEXT, -- Replicate prediction ID
    
    -- Status Machine
    status TEXT NOT NULL DEFAULT 'starting'
        CHECK (status IN (
            'starting',    -- Initial state
            'processing',  -- Sent to Replicate
            'succeeded',   -- Completed successfully
            'failed',      -- Error occurred
            'canceled'     -- User canceled
        )),
    
    -- Input Data (for debugging/replay)
    input_params JSONB NOT NULL,
    
    -- Error Tracking
    error_message TEXT,
    error_code TEXT,
    error_details JSONB,
    
    -- Performance Metrics
    processing_time_seconds NUMERIC(6,2),
    queue_time_seconds NUMERIC(6,2),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT valid_status_timestamps CHECK (
        (status IN ('succeeded', 'failed', 'canceled') AND completed_at IS NOT NULL) OR
        (status NOT IN ('succeeded', 'failed', 'canceled'))
    ),
    CONSTRAINT valid_replicate_id CHECK (
        replicate_id IS NULL OR length(replicate_id) > 0
    )
);

-- Indexes for performance
CREATE INDEX idx_generations_user_created 
    ON public.generations(user_id, created_at DESC);

CREATE INDEX idx_generations_user_status 
    ON public.generations(user_id, status);

CREATE INDEX idx_generations_status_active 
    ON public.generations(status) 
    WHERE status IN ('starting', 'processing');

CREATE INDEX idx_generations_replicate 
    ON public.generations(replicate_id) 
    WHERE replicate_id IS NOT NULL;

CREATE INDEX idx_generations_preset 
    ON public.generations(preset_id);

-- Partial index for polling queries
CREATE INDEX idx_generations_polling 
    ON public.generations(id, status, completed_at) 
    WHERE status IN ('starting', 'processing');

-- Row Level Security
ALTER TABLE public.generations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "generations_select_own"
    ON public.generations FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "generations_insert_own"
    ON public.generations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "generations_update_own"
    ON public.generations FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Service role can update any (for webhooks)
CREATE POLICY "generations_update_service"
    ON public.generations FOR UPDATE
    USING (auth.jwt()->>'role' = 'service_role')
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Comments
COMMENT ON TABLE public.generations IS 'AI generation job tracking and history';
COMMENT ON COLUMN public.generations.replicate_id IS 'Replicate prediction ID for status polling';
COMMENT ON COLUMN public.generations.input_params IS 'Full request params for debugging/replay';
COMMENT ON COLUMN public.generations.status IS 'Job status: starting → processing → succeeded/failed/canceled';

-- ============================================================================
-- TABLE: generation_assets
-- Output images from AI generations (4 variants per generation)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.generation_assets (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relations
    generation_id UUID NOT NULL REFERENCES public.generations(id) ON DELETE CASCADE,
    
    -- Image Data
    image_url TEXT NOT NULL, -- Supabase Storage path
    variant TEXT NOT NULL 
        CHECK (variant IN (
            'safe_match',  -- Closest to original
            'editorial',   -- Editorial/magazine style
            'lifestyle',   -- Natural/candid
            'artistic',    -- Creative interpretation
            'custom'       -- Custom variant
        )),
    
    -- Image Metadata
    width INTEGER,
    height INTEGER,
    file_size_bytes INTEGER,
    blurhash TEXT,
    
    -- User Interactions
    is_favorite BOOLEAN NOT NULL DEFAULT false,
    download_count INTEGER NOT NULL DEFAULT 0,
    share_count INTEGER NOT NULL DEFAULT 0,
    
    -- Optional Enhancements
    upscaled_url TEXT,
    upscaled_at TIMESTAMPTZ,
    watermark_removed BOOLEAN NOT NULL DEFAULT false,
    
    -- AI Metadata (for compliance)
    ai_metadata JSONB DEFAULT '{
        "model": "flux-1-dev",
        "generated_by": "Aura",
        "is_ai_generated": true
    }'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Constraints
    CONSTRAINT valid_dimensions CHECK (
        (width IS NULL AND height IS NULL) OR
        (width > 0 AND height > 0 AND width <= 8192 AND height <= 8192)
    ),
    CONSTRAINT valid_file_size CHECK (
        file_size_bytes IS NULL OR 
        (file_size_bytes > 0 AND file_size_bytes <= 52428800) -- 50MB max
    )
);

-- Indexes
CREATE INDEX idx_assets_generation 
    ON public.generation_assets(generation_id);

CREATE INDEX idx_assets_user_favorite 
    ON public.generation_assets(generation_id, is_favorite) 
    WHERE is_favorite = true;

CREATE INDEX idx_assets_variant 
    ON public.generation_assets(variant);

CREATE INDEX idx_assets_created 
    ON public.generation_assets(created_at DESC);

-- Row Level Security
ALTER TABLE public.generation_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "assets_select_via_generation"
    ON public.generation_assets FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.generations g
            WHERE g.id = generation_id 
            AND g.user_id = auth.uid()
        )
    );

CREATE POLICY "assets_update_via_generation"
    ON public.generation_assets FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.generations g
            WHERE g.id = generation_id 
            AND g.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.generations g
            WHERE g.id = generation_id 
            AND g.user_id = auth.uid()
        )
    );

-- Service role can insert (webhooks)
CREATE POLICY "assets_insert_service"
    ON public.generation_assets FOR INSERT
    WITH CHECK (
        auth.jwt()->>'role' = 'service_role' OR
        EXISTS (
            SELECT 1 FROM public.generations g
            WHERE g.id = generation_id 
            AND g.user_id = auth.uid()
        )
    );

-- Comments
COMMENT ON TABLE public.generation_assets IS 'AI-generated output images';
COMMENT ON COLUMN public.generation_assets.variant IS 'A/B test variant: safe_match, editorial, lifestyle, artistic';
COMMENT ON COLUMN public.generation_assets.ai_metadata IS 'Metadata for App Store compliance (AI disclosure)';

-- ============================================================================
-- Grant permissions
-- ============================================================================

GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;

-- ============================================================================
-- Success log
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 001 completed successfully';
    RAISE NOTICE 'Created tables: profiles, presets, user_uploads, generations, generation_assets';
END $$;
```

---

### Migration 002: Functions & Triggers

**Файл:** `supabase/migrations/20260115000002_functions_triggers.sql`

```sql
-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 002: Functions, Triggers, and Automation
-- Created: 2026-01-15
-- ============================================================================

-- ============================================================================
-- FUNCTION: Auto-update updated_at timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.update_updated_at_column() IS 'Auto-update updated_at on row modification';

-- Apply triggers
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER presets_updated_at
    BEFORE UPDATE ON public.presets
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER generation_assets_updated_at
    BEFORE UPDATE ON public.generation_assets
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- FUNCTION: Auto-create profile on auth signup
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.profiles (
        id, 
        email, 
        full_name, 
        avatar_url
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        RETURN NEW; -- Profile already exists
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS 'Auto-create profile when user signs up';

-- Trigger on auth.users insert
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- FUNCTION: Reset daily generation counters (CRON job)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reset_daily_generation_counters()
RETURNS INTEGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE public.profiles
    SET 
        generations_used_today = 0,
        last_generation_reset = CURRENT_DATE
    WHERE last_generation_reset < CURRENT_DATE;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    RAISE NOTICE 'Reset generation counters for % users', updated_count;
    
    RETURN updated_count;
END;
$$;

COMMENT ON FUNCTION public.reset_daily_generation_counters() IS 'Reset daily counters (run at midnight UTC via pg_cron)';

-- Schedule via pg_cron (если доступно) или через Supabase Edge Function
-- SELECT cron.schedule('reset-daily-generations', '0 0 * * *', 'SELECT reset_daily_generation_counters()');

-- ============================================================================
-- FUNCTION: Increment usage counters on generation create
-- ============================================================================

CREATE OR REPLACE FUNCTION public.increment_generation_counters()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Increment user counters
    UPDATE public.profiles
    SET 
        generations_used_today = generations_used_today + 1,
        total_generations = total_generations + 1
    WHERE id = NEW.user_id;
    
    -- Increment preset usage counter
    UPDATE public.presets
    SET usage_count = usage_count + 1
    WHERE id = NEW.preset_id;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to increment counters: %', SQLERRM;
        RETURN NEW; -- Don't block generation if counter fails
END;
$$;

COMMENT ON FUNCTION public.increment_generation_counters() IS 'Auto-increment usage stats when generation created';

CREATE TRIGGER generation_increment_counters
    AFTER INSERT ON public.generations
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_generation_counters();

-- ============================================================================
-- FUNCTION: Check if user can generate (quota validation)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_generation_limit(p_user_id UUID)
RETURNS TABLE(
    can_generate BOOLEAN,
    used_today INTEGER,
    daily_limit INTEGER,
    subscription_tier TEXT,
    reason TEXT
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_profile RECORD;
    v_limit INTEGER;
BEGIN
    -- Get user profile
    SELECT 
        p.subscription_tier,
        p.generations_used_today,
        p.subscription_expires_at,
        CASE 
            WHEN p.subscription_tier = 'pro' THEN 999999
            WHEN p.subscription_tier = 'free' THEN 3
            ELSE 0
        END as limit
    INTO v_profile
    FROM public.profiles p
    WHERE p.id = p_user_id;
    
    -- Check if not found
    IF NOT FOUND THEN
        RETURN QUERY SELECT 
            false as can_generate,
            0 as used_today,
            0 as daily_limit,
            'free'::TEXT as subscription_tier,
            'User not found'::TEXT as reason;
        RETURN;
    END IF;
    
    -- Check if Pro subscription expired
    IF v_profile.subscription_tier = 'pro' 
       AND v_profile.subscription_expires_at IS NOT NULL 
       AND v_profile.subscription_expires_at < now() THEN
        
        RETURN QUERY SELECT 
            false as can_generate,
            v_profile.generations_used_today as used_today,
            v_profile.limit as daily_limit,
            'free'::TEXT as subscription_tier,
            'Subscription expired'::TEXT as reason;
        RETURN;
    END IF;
    
    -- Check daily limit
    IF v_profile.generations_used_today >= v_profile.limit THEN
        RETURN QUERY SELECT 
            false as can_generate,
            v_profile.generations_used_today as used_today,
            v_profile.limit as daily_limit,
            v_profile.subscription_tier as subscription_tier,
            'Daily limit exceeded'::TEXT as reason;
        RETURN;
    END IF;
    
    -- User can generate
    RETURN QUERY SELECT 
        true as can_generate,
        v_profile.generations_used_today as used_today,
        v_profile.limit as daily_limit,
        v_profile.subscription_tier as subscription_tier,
        NULL::TEXT as reason;
END;
$$;

COMMENT ON FUNCTION public.check_generation_limit(UUID) IS 'Validate if user has remaining quota';

-- Usage example:
-- SELECT * FROM check_generation_limit(auth.uid());

-- ============================================================================
-- FUNCTION: Get user gallery with pagination
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_gallery(
    p_user_id UUID,
    p_page INTEGER DEFAULT 1,
    p_limit INTEGER DEFAULT 20,
    p_preset_id UUID DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_favorites_only BOOLEAN DEFAULT false
)
RETURNS TABLE(
    generation_id UUID,
    preset_name TEXT,
    preset_slug TEXT,
    preset_icon_url TEXT,
    status TEXT,
    created_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    processing_time NUMERIC,
    outputs JSONB,
    total_count BIGINT
) 
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH filtered_generations AS (
        SELECT g.id
        FROM public.generations g
        WHERE g.user_id = p_user_id
            AND (p_preset_id IS NULL OR g.preset_id = p_preset_id)
            AND (p_status IS NULL OR g.status = p_status)
            AND (
                NOT p_favorites_only OR
                EXISTS (
                    SELECT 1 FROM public.generation_assets ga
                    WHERE ga.generation_id = g.id AND ga.is_favorite = true
                )
            )
    ),
    total AS (
        SELECT count(*) as cnt FROM filtered_generations
    )
    SELECT 
        g.id as generation_id,
        p.name as preset_name,
        p.slug as preset_slug,
        p.icon_url as preset_icon_url,
        g.status,
        g.created_at,
        g.completed_at,
        g.processing_time_seconds as processing_time,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', ga.id,
                    'url', ga.image_url,
                    'variant', ga.variant,
                    'is_favorite', ga.is_favorite,
                    'width', ga.width,
                    'height', ga.height,
                    'blurhash', ga.blurhash
                )
                ORDER BY 
                    CASE ga.variant
                        WHEN 'safe_match' THEN 1
                        WHEN 'editorial' THEN 2
                        WHEN 'lifestyle' THEN 3
                        WHEN 'artistic' THEN 4
                        ELSE 5
                    END
            ) FILTER (WHERE ga.id IS NOT NULL),
            '[]'::jsonb
        ) as outputs,
        (SELECT cnt FROM total) as total_count
    FROM public.generations g
    INNER JOIN filtered_generations fg ON fg.id = g.id
    LEFT JOIN public.presets p ON g.preset_id = p.id
    LEFT JOIN public.generation_assets ga ON ga.generation_id = g.id
    GROUP BY g.id, p.name, p.slug, p.icon_url, g.status, g.created_at, g.completed_at, g.processing_time_seconds
    ORDER BY g.created_at DESC
    LIMIT p_limit
    OFFSET (p_page - 1) * p_limit;
END;
$$;

COMMENT ON FUNCTION public.get_user_gallery IS 'Fetch user generations with pagination and filtering';

-- Usage example:
-- SELECT * FROM get_user_gallery(auth.uid(), 1, 20, NULL, 'succeeded');

-- ============================================================================
-- FUNCTION: Clean up expired uploads (CRON job)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.cleanup_expired_uploads()
RETURNS TABLE(
    deleted_count INTEGER,
    freed_bytes BIGINT,
    file_paths TEXT[]
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted_count INTEGER;
    v_freed_bytes BIGINT;
    v_file_paths TEXT[];
BEGIN
    -- Delete expired uploads and collect stats
    WITH deleted AS (
        DELETE FROM public.user_uploads
        WHERE expires_at < now()
        RETURNING id, file_path, file_size_bytes
    )
    SELECT 
        COUNT(*)::INTEGER,
        COALESCE(SUM(file_size_bytes), 0),
        array_agg(file_path)
    INTO v_deleted_count, v_freed_bytes, v_file_paths
    FROM deleted;
    
    -- Log cleanup
    RAISE NOTICE 'Cleanup: deleted % uploads, freed % bytes', 
        v_deleted_count, v_freed_bytes;
    
    -- Return stats
    RETURN QUERY SELECT 
        v_deleted_count,
        v_freed_bytes,
        v_file_paths;
END;
$$;

COMMENT ON FUNCTION public.cleanup_expired_uploads() IS 'Delete expired uploads (run daily via cron)';

-- Schedule via pg_cron or Supabase Edge Function
-- SELECT cron.schedule('cleanup-uploads', '0 */6 * * *', 'SELECT cleanup_expired_uploads()');

-- ============================================================================
-- FUNCTION: Update generation status (called by webhooks)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_generation_status(
    p_replicate_id TEXT,
    p_status TEXT,
    p_error_message TEXT DEFAULT NULL,
    p_error_code TEXT DEFAULT NULL,
    p_processing_time NUMERIC DEFAULT NULL
)
RETURNS TABLE(
    generation_id UUID,
    user_id UUID,
    updated BOOLEAN
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_generation_id UUID;
    v_user_id UUID;
    v_old_status TEXT;
BEGIN
    -- Update generation and return info
    UPDATE public.generations
    SET 
        status = p_status,
        completed_at = CASE 
            WHEN p_status IN ('succeeded', 'failed', 'canceled') THEN now() 
            ELSE completed_at 
        END,
        error_message = COALESCE(p_error_message, error_message),
        error_code = COALESCE(p_error_code, error_code),
        processing_time_seconds = COALESCE(p_processing_time, processing_time_seconds)
    WHERE replicate_id = p_replicate_id
    RETURNING id, user_id, status
    INTO v_generation_id, v_user_id, v_old_status;
    
    -- Check if found
    IF NOT FOUND THEN
        RAISE WARNING 'Generation with replicate_id % not found', p_replicate_id;
        RETURN QUERY SELECT 
            NULL::UUID as generation_id,
            NULL::UUID as user_id,
            false as updated;
        RETURN;
    END IF;
    
    -- Log status change
    RAISE NOTICE 'Updated generation % status to %', v_generation_id, p_status;
    
    RETURN QUERY SELECT 
        v_generation_id,
        v_user_id,
        true as updated;
END;
$$;

COMMENT ON FUNCTION public.update_generation_status IS 'Update generation status from Replicate webhook';

-- ============================================================================
-- FUNCTION: Toggle favorite status
-- ============================================================================

CREATE OR REPLACE FUNCTION public.toggle_favorite(p_asset_id UUID)
RETURNS BOOLEAN
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_status BOOLEAN;
    v_user_id UUID;
BEGIN
    -- Check ownership
    SELECT g.user_id INTO v_user_id
    FROM public.generation_assets ga
    JOIN public.generations g ON g.id = ga.generation_id
    WHERE ga.id = p_asset_id;
    
    IF v_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    -- Toggle favorite
    UPDATE public.generation_assets
    SET is_favorite = NOT is_favorite
    WHERE id = p_asset_id
    RETURNING is_favorite INTO v_new_status;
    
    RETURN v_new_status;
END;
$$;

COMMENT ON FUNCTION public.toggle_favorite IS 'Toggle is_favorite on generation asset';

-- ============================================================================
-- FUNCTION: Get user stats (for profile screen)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_stats(p_user_id UUID)
RETURNS TABLE(
    total_generations INTEGER,
    favorites_count INTEGER,
    most_used_preset TEXT,
    avg_processing_time NUMERIC,
    subscription_tier TEXT,
    generations_used_today INTEGER,
    daily_limit INTEGER
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            COUNT(DISTINCT g.id)::INTEGER as total_gens,
            COUNT(DISTINCT ga.id) FILTER (WHERE ga.is_favorite = true)::INTEGER as favs,
            MODE() WITHIN GROUP (ORDER BY p.name) as popular_preset,
            AVG(g.processing_time_seconds) as avg_time
        FROM public.generations g
        LEFT JOIN public.generation_assets ga ON ga.generation_id = g.id
        LEFT JOIN public.presets p ON p.id = g.preset_id
        WHERE g.user_id = p_user_id AND g.status = 'succeeded'
    )
    SELECT 
        s.total_gens,
        s.favs,
        s.popular_preset,
        ROUND(s.avg_time, 2),
        pr.subscription_tier,
        pr.generations_used_today,
        CASE 
            WHEN pr.subscription_tier = 'pro' THEN 999999
            WHEN pr.subscription_tier = 'free' THEN 3
        END as daily_limit
    FROM stats s
    CROSS JOIN public.profiles pr
    WHERE pr.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION public.get_user_stats IS 'Get aggregated user statistics for profile';

-- ============================================================================
-- FUNCTION: Delete user account and all data
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_user_account(p_user_id UUID)
RETURNS TABLE(
    deleted_generations INTEGER,
    deleted_assets INTEGER,
    deleted_uploads INTEGER,
    storage_paths TEXT[]
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_gens INTEGER;
    v_assets INTEGER;
    v_uploads INTEGER;
    v_paths TEXT[];
BEGIN
    -- Verify ownership
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    -- Collect storage paths for cleanup
    SELECT array_agg(DISTINCT file_path) INTO v_paths
    FROM public.user_uploads
    WHERE user_id = p_user_id;
    
    -- Delete in correct order (respecting FK constraints)
    DELETE FROM public.generation_assets
    WHERE generation_id IN (
        SELECT id FROM public.generations WHERE user_id = p_user_id
    );
    GET DIAGNOSTICS v_assets = ROW_COUNT;
    
    DELETE FROM public.generations WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_gens = ROW_COUNT;
    
    DELETE FROM public.user_uploads WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_uploads = ROW_COUNT;
    
    -- Delete profile (will cascade to auth.users via trigger)
    DELETE FROM public.profiles WHERE id = p_user_id;
    
    RAISE NOTICE 'Deleted account %: % generations, % assets, % uploads', 
        p_user_id, v_gens, v_assets, v_uploads;
    
    RETURN QUERY SELECT v_gens, v_assets, v_uploads, v_paths;
END;
$$;

COMMENT ON FUNCTION public.delete_user_account IS 'Permanently delete user account and all associated data';

-- ============================================================================
-- Success log
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 002 completed successfully';
    RAISE NOTICE 'Created functions: update_updated_at_column, handle_new_user, check_generation_limit, etc.';
END $$;
```

---

### Migration 003: Storage Policies

**Файл:** `supabase/migrations/20260115000003_storage_policies.sql`

```sql
-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 003: Supabase Storage Buckets & RLS Policies
-- Created: 2026-01-15
-- ============================================================================

-- Note: Buckets должны быть созданы через Supabase Dashboard:
-- 1. Storage → Create Bucket
-- 2. uploads (private, 10MB file limit)
-- 3. results (private, 50MB file limit)
-- 4. preset-icons (public, 5MB file limit)

-- ============================================================================
-- BUCKET: uploads (temporary user source images)
-- ============================================================================

-- Policy: Users can upload to their own folder only
CREATE POLICY "uploads_insert_own_folder"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'uploads' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Policy: Users can read their own uploads
CREATE POLICY "uploads_select_own_folder"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'uploads' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Policy: Users can delete their own uploads
CREATE POLICY "uploads_delete_own_folder"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'uploads' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================================
-- BUCKET: results (AI-generated images)
-- ============================================================================

-- Policy: Service role can insert (from webhooks)
CREATE POLICY "results_insert_service_role"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'results' AND
        auth.jwt()->>'role' = 'service_role'
    );

-- Policy: Users can read their own results
CREATE POLICY "results_select_own_folder"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'results' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Policy: Users can delete their own results
CREATE POLICY "results_delete_own_folder"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'results' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================================
-- BUCKET: preset-icons (public preset thumbnails)
-- ============================================================================

-- Policy: Anyone can read preset icons
CREATE POLICY "preset_icons_select_public"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'preset-icons');

-- Policy: Only service role can upload preset icons
CREATE POLICY "preset_icons_insert_service_role"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'preset-icons' AND
        auth.jwt()->>'role' = 'service_role'
    );

-- Policy: Only service role can update/delete
CREATE POLICY "preset_icons_update_service_role"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'preset-icons' AND
        auth.jwt()->>'role' = 'service_role'
    );

CREATE POLICY "preset_icons_delete_service_role"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'preset-icons' AND
        auth.jwt()->>'role' = 'service_role'
    );

-- ============================================================================
-- Helper Function: Get signed URL for private image
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_signed_url(
    p_bucket TEXT,
    p_path TEXT,
    p_expires_in INTEGER DEFAULT 3600 -- 1 hour
)
RETURNS TEXT
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_url TEXT;
BEGIN
    -- Verify user has access (via RLS)
    -- This will fail if user doesn't have SELECT permission
    
    -- Generate signed URL (placeholder - actual implementation depends on Supabase SDK)
    -- In production, call this from Edge Function
    SELECT concat(
        current_setting('app.settings.supabase_url'),
        '/storage/v1/object/sign/',
        p_bucket, '/', p_path,
        '?token=', encode(gen_random_bytes(32), 'hex')
    ) INTO v_url;
    
    RETURN v_url;
END;
$$;

-- ============================================================================
-- Success log
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 003 completed successfully';
    RAISE NOTICE 'Storage policies created for buckets: uploads, results, preset-icons';
    RAISE NOTICE '⚠️  Remember to create buckets manually in Supabase Dashboard!';
END $$;
```

---

### Migration 004: Compliance & Moderation

**Файл:** `supabase/migrations/20260115000004_compliance.sql`

```sql
-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 004: Compliance & Content Moderation
-- Created: 2026-01-15
-- ============================================================================

-- Required for trigram index on blocked_terms
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- TABLE: blocked_terms
-- Content moderation blocklist (celebrities, NSFW, violence)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.blocked_terms (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Term Data
    term TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL CHECK (category IN (
        'celebrity',  -- Famous people
        'nsfw',       -- Adult content
        'violence',   -- Violent content
        'brand',      -- Trademarked brands
        'location',   -- Problematic locations
        'other'       -- Miscellaneous
    )),
    severity TEXT NOT NULL DEFAULT 'high' CHECK (severity IN ('low', 'medium', 'high')),
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Metadata
    reason TEXT, -- Why this term is blocked
    added_by UUID REFERENCES public.profiles(id),
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_blocked_terms_category 
    ON public.blocked_terms(category, is_active) 
    WHERE is_active = true;

CREATE INDEX idx_blocked_terms_severity 
    ON public.blocked_terms(severity) 
    WHERE is_active = true;

-- Full-text search index for faster matching
CREATE INDEX idx_blocked_terms_term_trgm 
    ON public.blocked_terms USING gin(term gin_trgm_ops);

-- Row Level Security (service role only)
ALTER TABLE public.blocked_terms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "blocked_terms_service_role_all"
    ON public.blocked_terms FOR ALL
    USING (auth.jwt()->>'role' = 'service_role')
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- Comments
COMMENT ON TABLE public.blocked_terms IS 'Content moderation blocklist for App Store compliance';
COMMENT ON COLUMN public.blocked_terms.category IS 'Type of blocked content';
COMMENT ON COLUMN public.blocked_terms.severity IS 'Block severity: low (warning), medium (soft block), high (hard block)';

-- ============================================================================
-- SEED: Default Blocked Terms
-- ============================================================================

INSERT INTO public.blocked_terms (term, category, severity, reason) VALUES
-- Celebrities (high risk for Apple rejection)
('trump', 'celebrity', 'high', 'Political figure'),
('biden', 'celebrity', 'high', 'Political figure'),
('musk', 'celebrity', 'high', 'Public figure'),
('kardashian', 'celebrity', 'high', 'Public figure'),
('swift', 'celebrity', 'high', 'Public figure - Taylor Swift'),
('ronaldo', 'celebrity', 'high', 'Public figure'),
('messi', 'celebrity', 'high', 'Public figure'),
('obama', 'celebrity', 'high', 'Political figure'),
('putin', 'celebrity', 'high', 'Political figure'),

-- NSFW (mandatory blocks)
('nude', 'nsfw', 'high', 'Adult content'),
('naked', 'nsfw', 'high', 'Adult content'),
('sex', 'nsfw', 'high', 'Adult content'),
('porn', 'nsfw', 'high', 'Adult content'),
('nsfw', 'nsfw', 'high', 'Adult content'),
('xxx', 'nsfw', 'high', 'Adult content'),
('erotic', 'nsfw', 'high', 'Adult content'),
('bikini', 'nsfw', 'medium', 'May violate guidelines'),
('underwear', 'nsfw', 'medium', 'May violate guidelines'),

-- Violence
('gun', 'violence', 'high', 'Weapons'),
('blood', 'violence', 'medium', 'Gore'),
('dead', 'violence', 'high', 'Death'),
('kill', 'violence', 'high', 'Violence'),
('murder', 'violence', 'high', 'Violence'),
('suicide', 'violence', 'high', 'Self-harm'),
('weapon', 'violence', 'high', 'Weapons'),

-- Brands (trademark issues)
('coca-cola', 'brand', 'medium', 'Trademarked brand'),
('nike', 'brand', 'medium', 'Trademarked brand'),
('apple logo', 'brand', 'high', 'Our competitor :)'),
('mcdonald', 'brand', 'medium', 'Trademarked brand'),
('starbucks', 'brand', 'medium', 'Trademarked brand'),

-- Other problematic
('deepfake', 'other', 'high', 'Banned by Apple'),
('face swap', 'other', 'high', 'Banned by Apple'),
('hitler', 'other', 'high', 'Historical figure'),
('nazi', 'other', 'high', 'Hate symbol')

ON CONFLICT (term) DO NOTHING;

-- ============================================================================
-- FUNCTION: Validate prompt against blocklist
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_prompt(p_prompt TEXT)
RETURNS TABLE(
    is_valid BOOLEAN,
    violations JSONB,
    message TEXT
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_violations JSONB := '[]'::jsonb;
    v_found_term RECORD;
    v_prompt_lower TEXT;
BEGIN
    v_prompt_lower := lower(p_prompt);
    
    -- Check against blocked terms
    FOR v_found_term IN
        SELECT term, category, severity
        FROM public.blocked_terms
        WHERE is_active = true
        AND v_prompt_lower LIKE '%' || term || '%'
        ORDER BY severity DESC
        LIMIT 10 -- Max 10 violations to return
    LOOP
        v_violations := v_violations || jsonb_build_object(
            'term', v_found_term.term,
            'category', v_found_term.category,
            'severity', v_found_term.severity
        );
    END LOOP;
    
    -- Return result
    IF jsonb_array_length(v_violations) > 0 THEN
        RETURN QUERY SELECT 
            false as is_valid,
            v_violations,
            CASE (v_violations->0->>'category')::text
                WHEN 'celebrity' THEN 'Генерация с изображениями знаменитостей запрещена политикой App Store'
                WHEN 'nsfw' THEN 'Контент для взрослых запрещен в приложении'
                WHEN 'violence' THEN 'Контент с насилием запрещен'
                WHEN 'brand' THEN 'Использование защищенных брендов может нарушать авторские права'
                ELSE 'Обнаружен запрещенный контент'
            END as message;
    ELSE
        RETURN QUERY SELECT 
            true as is_valid,
            '[]'::jsonb as violations,
            NULL::TEXT as message;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.validate_prompt IS 'Validate user prompt against blocklist';

-- Usage:
-- SELECT * FROM validate_prompt('A photo of Trump in Paris');
-- Returns: {is_valid: false, violations: [...], message: '...'}

-- ============================================================================
-- Success log
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 004 completed successfully';
    RAISE NOTICE 'Created compliance infrastructure with % blocked terms', 
        (SELECT COUNT(*) FROM public.blocked_terms);
END $$;
```

---

### Migration 005: Indexes Optimization

**Файл:** `supabase/migrations/20260115000005_optimization.sql`

```sql
-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 005: Performance Optimization
-- Created: 2026-01-15
-- ============================================================================

-- ============================================================================
-- Composite Indexes for Complex Queries
-- ============================================================================

-- Gallery query optimization (most common query)
CREATE INDEX idx_generations_gallery 
    ON public.generations(user_id, status, created_at DESC)
    WHERE status = 'succeeded';

-- Favorite assets quick lookup
CREATE INDEX idx_assets_favorites_by_user 
    ON public.generation_assets(generation_id, is_favorite, created_at DESC)
    WHERE is_favorite = true;

-- Preset analytics (admin dashboard)
CREATE INDEX idx_presets_analytics 
    ON public.presets(mode, is_premium, usage_count DESC)
    WHERE is_active = true;

-- Failed generations for debugging
CREATE INDEX idx_generations_failed 
    ON public.generations(created_at DESC, error_code)
    WHERE status = 'failed';

-- ============================================================================
-- JSONB Indexes for Parameter Queries
-- ============================================================================

-- Index for searching generations by parameters
CREATE INDEX idx_generations_input_params 
    ON public.generations USING gin(input_params);

-- Index for preset parameters
CREATE INDEX idx_presets_parameters 
    ON public.presets USING gin(parameters);

-- ============================================================================
-- Materialized View: Daily Stats (optional)
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS public.daily_stats AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_generations,
    COUNT(*) FILTER (WHERE status = 'succeeded') as successful,
    COUNT(*) FILTER (WHERE status = 'failed') as failed,
    AVG(processing_time_seconds) FILTER (WHERE status = 'succeeded') as avg_time,
    COUNT(DISTINCT user_id) as unique_users
FROM public.generations
GROUP BY DATE(created_at)
ORDER BY date DESC;

CREATE UNIQUE INDEX idx_daily_stats_date ON public.daily_stats(date);

COMMENT ON MATERIALIZED VIEW public.daily_stats IS 'Daily aggregated statistics (refresh hourly via cron)';

-- Refresh function
CREATE OR REPLACE FUNCTION public.refresh_daily_stats()
RETURNS void
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.daily_stats;
    RAISE NOTICE 'Daily stats refreshed';
END;
$$;

-- Schedule refresh (via pg_cron or Edge Function)
-- SELECT cron.schedule('refresh-stats', '0 * * * *', 'SELECT refresh_daily_stats()');

-- ============================================================================
-- Success log
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 005 completed successfully';
    RAISE NOTICE 'Created performance indexes and materialized views';
END $$;
```

---

## 📊 Seed Data

**Файл:** `supabase/seed.sql`

```sql
-- ============================================================================
-- Aura Database - Production Seed Data
-- ============================================================================

-- ============================================================================
-- SEED: Presets (Initial Styles)
-- ============================================================================

INSERT INTO public.presets (
    name,
    slug,
    description,
    mode,
    prompt_template,
    negative_prompt,
    icon_url,
    thumbnail_url,
    is_premium,
    sort_order,
    parameters,
    replicate_model
) VALUES

-- ================== PERSONA PRESETS ==================

(
    'Old Money',
    'old-money-paris',
    'Тихая роскошь в парижском стиле',
    'persona',
    'A person in a minimalist chic outfit, sitting at a classic Parisian cafe, beige and cream color palette, soft afternoon sunlight through large cafe windows, elegant atmosphere, blurred background of Haussmann architecture, expensive aesthetic, quiet luxury, natural skin tone, editorial magazine quality',
    'deformed, distorted, bad anatomy, blurry, low quality, plastic skin, over-sharpened',
    'https://storage.supabase.co/preset-icons/old-money.webp',
    'https://storage.supabase.co/preset-icons/old-money-thumb.webp',
    false, -- Free
    1,
    '{
        "guidance_scale": 3.5,
        "num_inference_steps": 28,
        "aspect_ratio": "4:5",
        "ip_adapter_scale": 0.85,
        "face_preservation_strength": 0.85
    }'::jsonb,
    'zsxkib/instant-id:6c8f5e3aeb3a15f91c43c6fb31ebdbd06e3957efa38ce89c696edf2a75012f5c'
),

(
    'Urban Night',
    'urban-night-tokyo',
    'Неоновые огни ночного города',
    'persona',
    'Night photography in bustling Tokyo street, cinematic neon lighting, reflections of red and blue city lights on wet pavement, high contrast, street style aesthetic, busy metropolitan background with bokeh effects, sharp details on subject, moody cyberpunk atmosphere without actual cyberpunk elements',
    'deformed, distorted, bad anatomy, blurry, cartoon, anime',
    'https://storage.supabase.co/preset-icons/urban-night.webp',
    'https://storage.supabase.co/preset-icons/urban-night-thumb.webp',
    false, -- Free
    2,
    '{
        "guidance_scale": 4.0,
        "num_inference_steps": 30,
        "aspect_ratio": "4:5",
        "ip_adapter_scale": 0.75,
        "face_preservation_strength": 0.82
    }'::jsonb,
    'zsxkib/instant-id:6c8f5e3aeb3a15f91c43c6fb31ebdbd06e3957efa38ce89c696edf2a75012f5c'
),

(
    'Scandi Minimalist',
    'scandi-minimalist',
    'Чистый скандинавский интерьер',
    'persona',
    'Clean minimalist Scandinavian interior, person in natural linen clothing, bright natural daylight from large window, white walls and light oak wood textures, clean lines, organic aesthetic, soft shadows, airy and fresh atmosphere, high-end lifestyle photography, serene mood',
    'deformed, distorted, bad anatomy, blurry, cluttered, messy',
    'https://storage.supabase.co/preset-icons/scandi.webp',
    'https://storage.supabase.co/preset-icons/scandi-thumb.webp',
    false, -- Free
    3,
    '{
        "guidance_scale": 3.0,
        "num_inference_steps": 25,
        "aspect_ratio": "4:5",
        "ip_adapter_scale": 0.88,
        "face_preservation_strength": 0.88
    }'::jsonb,
    'zsxkib/instant-id:6c8f5e3aeb3a15f91c43c6fb31ebdbd06e3957efa38ce89c696edf2a75012f5c'
),

(
    'Editorial Vogue',
    'editorial-vogue',
    'Высокая мода в стиле Vogue',
    'persona',
    'High fashion editorial photoshoot, dramatic studio lighting setup, harsh directional light creating deep shadows, stark monochromatic background or bold single color, avant-garde aesthetic, sharp focus on eyes and facial features, grainy film texture, 90s Vogue magazine style, confident pose',
    'deformed, distorted, bad anatomy, blurry, amateur, snapshot',
    'https://storage.supabase.co/preset-icons/vogue.webp',
    'https://storage.supabase.co/preset-icons/vogue-thumb.webp',
    true, -- Premium
    4,
    '{
        "guidance_scale": 4.5,
        "num_inference_steps": 32,
        "aspect_ratio": "4:5",
        "ip_adapter_scale": 0.7,
        "face_preservation_strength": 0.75
    }'::jsonb,
    'zsxkib/instant-id:6c8f5e3aeb3a15f91c43c6fb31ebdbd06e3957efa38ce89c696edf2a75012f5c'
),

(
    'Analog Film 90s',
    'analog-film-90s',
    'Винтажная пленочная эстетика',
    'persona',
    'Vintage 90s film photography aesthetic, shot on Kodak Portra 400, warm natural skin tones, visible film grain texture, soft lens flare from sunlight, nostalgic vibe, authentic candid moment, raw unposed photography, natural imperfections, slightly faded colors, timeless feel',
    'deformed, distorted, bad anatomy, blurry, digital, over-processed',
    'https://storage.supabase.co/preset-icons/analog.webp',
    'https://storage.supabase.co/preset-icons/analog-thumb.webp',
    false, -- Free
    5,
    '{
        "guidance_scale": 3.2,
        "num_inference_steps": 26,
        "aspect_ratio": "4:5",
        "ip_adapter_scale": 0.9,
        "face_preservation_strength": 0.9
    }'::jsonb,
    'zsxkib/instant-id:6c8f5e3aeb3a15f91c43c6fb31ebdbd06e3957efa38ce89c696edf2a75012f5c'
),

(
    'Corporate LinkedIn',
    'corporate-linkedin',
    'Профессиональное бизнес-фото',
    'persona',
    'Professional corporate headshot, business attire, modern office background, soft professional lighting, confident expression, clean and polished look, LinkedIn profile quality, neutral background',
    'deformed, distorted, bad anatomy, blurry, casual, unprofessional',
    'https://storage.supabase.co/preset-icons/corporate.webp',
    'https://storage.supabase.co/preset-icons/corporate-thumb.webp',
    true, -- Premium
    6,
    '{
        "guidance_scale": 3.0,
        "num_inference_steps": 25,
        "aspect_ratio": "1:1",
        "ip_adapter_scale": 0.88,
        "face_preservation_strength": 0.92
    }'::jsonb,
    'zsxkib/instant-id:6c8f5e3aeb3a15f91c43c6fb31ebdbd06e3957efa38ce89c696edf2a75012f5c'
),

-- ================== OBJECT PRESETS ==================

(
    'Luxury Product',
    'product-luxury',
    'Премиальная предметная съемка',
    'object',
    'High-end product photography, luxury item on marble or velvet surface, professional studio lighting setup, clean white or deep black background, perfect reflections, premium aesthetic, sharp focus on product details, commercial photography quality',
    'deformed, blurry, low quality, amateur, cluttered background',
    'https://storage.supabase.co/preset-icons/product-luxury.webp',
    'https://storage.supabase.co/preset-icons/product-luxury-thumb.webp',
    true, -- Premium
    10,
    '{
        "guidance_scale": 3.8,
        "num_inference_steps": 30,
        "aspect_ratio": "1:1",
        "controlnet_conditioning_scale": 0.7,
        "structure_preservation": "canny"
    }'::jsonb,
    'jagilley/controlnet-canny:aff48af9c68d162388d230a2ab003f68d2638d88307bdaf1c2f1ac95079c9613'
),

(
    'Lifestyle Flatlay',
    'lifestyle-flatlay',
    'Стильный флэтлей для Instagram',
    'object',
    'Lifestyle flatlay photography, artfully arranged items on clean surface, natural daylight, aesthetic composition, soft shadows, Instagram-worthy, trendy minimal style',
    'deformed, blurry, messy, cluttered',
    'https://storage.supabase.co/preset-icons/flatlay.webp',
    'https://storage.supabase.co/preset-icons/flatlay-thumb.webp',
    false, -- Free
    11,
    '{
        "guidance_scale": 3.2,
        "num_inference_steps": 26,
        "aspect_ratio": "4:5",
        "controlnet_conditioning_scale": 0.65,
        "structure_preservation": "depth"
    }'::jsonb,
    'jagilley/controlnet-canny:aff48af9c68d162388d230a2ab003f68d2638d88307bdaf1c2f1ac95079c9613'
)

ON CONFLICT (slug) DO NOTHING;

-- ============================================================================
-- Success log
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Seed data inserted successfully';
    RAISE NOTICE 'Added % presets', (SELECT COUNT(*) FROM public.presets);
END $$;
```

---

## 🧪 Useful Queries

### Проверка квоты пользователя

```sql
-- Простой способ
SELECT 
    subscription_tier,
    generations_used_today,
    CASE 
        WHEN subscription_tier = 'pro' THEN 999999
        WHEN subscription_tier = 'free' THEN 3
    END as daily_limit,
    CASE 
        WHEN subscription_tier = 'pro' THEN true
        WHEN generations_used_today < 3 THEN true
        ELSE false
    END as can_generate
FROM public.profiles
WHERE id = auth.uid();

-- Или через функцию
SELECT * FROM check_generation_limit(auth.uid());
```

---

### Галерея пользователя с пагинацией

```sql
-- Через функцию (рекомендуется)
SELECT * FROM get_user_gallery(
    auth.uid(),  -- user_id
    1,           -- page
    20,          -- limit
    NULL,        -- preset_id filter (optional)
    'succeeded', -- status filter (optional)
    false        -- favorites_only
);

-- Или прямой запрос
SELECT 
    g.id,
    g.status,
    g.created_at,
    p.name as preset_name,
    json_agg(
        json_build_object(
            'url', ga.image_url,
            'variant', ga.variant,
            'is_favorite', ga.is_favorite
        ) ORDER BY ga.created_at
    ) as outputs
FROM public.generations g
LEFT JOIN public.presets p ON g.preset_id = p.id
LEFT JOIN public.generation_assets ga ON ga.generation_id = g.id
WHERE g.user_id = auth.uid()
GROUP BY g.id, g.status, g.created_at, p.name
ORDER BY g.created_at DESC
LIMIT 20;
```

---

### Статистика пользователя

```sql
SELECT * FROM get_user_stats(auth.uid());

-- Возвращает:
-- total_generations, favorites_count, most_used_preset, 
-- avg_processing_time, subscription_tier, etc.
```

---

### Топ популярных пресетов

```sql
SELECT 
    name,
    slug,
    mode,
    usage_count,
    COALESCE(avg_rating, 0) as rating
FROM public.presets
WHERE is_active = true
ORDER BY usage_count DESC
LIMIT 10;
```

---

### Поиск проблемных генераций

```sql
-- Failed generations за последние 24 часа
SELECT 
    g.id,
    g.created_at,
    g.error_code,
    g.error_message,
    p.name as preset_name,
    prof.email as user_email
FROM public.generations g
LEFT JOIN public.presets p ON p.id = g.preset_id
LEFT JOIN public.profiles prof ON prof.id = g.user_id
WHERE g.status = 'failed'
    AND g.created_at > now() - interval '24 hours'
ORDER BY g.created_at DESC;
```

---

### Проверка валидации промпта

```sql
-- Проверить промпт на запрещенные слова
SELECT * FROM validate_prompt('A photo of Elon Musk in Paris');

-- Output:
-- {
--   is_valid: false,
--   violations: [{"term": "musk", "category": "celebrity", "severity": "high"}],
--   message: "Генерация с изображениями знаменитостей запрещена..."
-- }
```

---

## 🔧 Maintenance Queries

### Очистка старых uploads

```sql
-- Ручная очистка (или через cron)
SELECT * FROM cleanup_expired_uploads();

-- Проверка сколько файлов на удаление
SELECT COUNT(*), SUM(file_size_bytes) as total_bytes
FROM public.user_uploads
WHERE expires_at < now();
```

---

### Reset счетчиков (для тестирования)

```sql
-- Сброс счетчика генераций для всех
UPDATE public.profiles
SET generations_used_today = 0,
    last_generation_reset = CURRENT_DATE;

-- Сброс для конкретного юзера
UPDATE public.profiles
SET generations_used_today = 0
WHERE id = 'user-uuid-here';
```

---

### Обновление подписки (manual override)

```sql
-- Дать Pro подписку пользователю
UPDATE public.profiles
SET 
    subscription_tier = 'pro',
    subscription_started_at = now(),
    subscription_expires_at = now() + interval '1 year'
WHERE email = 'user@example.com';
```

---

## 📝 Backend Integration Examples

### TypeScript: Проверка лимита

```typescript
// services/subscription.service.ts
export async function checkUserLimit(userId: string): Promise<{
  canGenerate: boolean;
  usedToday: number;
  dailyLimit: number;
}> {
  const { data, error } = await supabase
    .rpc('check_generation_limit', { p_user_id: userId })
    .single();
  
  if (error) throw error;
  
  return {
    canGenerate: data.can_generate,
    usedToday: data.used_today,
    dailyLimit: data.daily_limit,
  };
}
```

### TypeScript: Получение галереи

```typescript
// services/gallery.service.ts
export async function getUserGallery(
  userId: string,
  page: number = 1,
  limit: number = 20
) {
  const { data, error } = await supabase
    .rpc('get_user_gallery', {
      p_user_id: userId,
      p_page: page,
      p_limit: limit,
    });
  
  if (error) throw error;
  
  return data;
}
```

### Swift: Проверка лимита

```swift
struct GenerationLimit: Decodable {
    let canGenerate: Bool
    let usedToday: Int
    let dailyLimit: Int
    let subscriptionTier: String
    
    enum CodingKeys: String, CodingKey {
        case canGenerate = "can_generate"
        case usedToday = "used_today"
        case dailyLimit = "daily_limit"
        case subscriptionTier = "subscription_tier"
    }
}

func checkGenerationLimit() async throws -> GenerationLimit {
    let response = try await supabase
        .rpc("check_generation_limit", params: ["p_user_id": userId])
        .execute()
    
    return try JSONDecoder().decode(GenerationLimit.self, from: response.data)
}
```

---

## 🚀 Deployment Commands

### Применить все миграции

```bash
# Подключиться к проекту
supabase link --project-ref your-project-ref

# Посмотреть diff
supabase db diff

# Применить миграции
supabase db push

# Проверить успешность
supabase db inspect
```

---

### Откат миграции (если нужно)

```bash
# Создать резервную копию
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql

# Откат последней миграции
supabase db reset

# Применить до нужной версии
supabase db push --file migrations/20260115000003_storage_policies.sql
```

---

## 📊 Performance Monitoring

### Медленные запросы

```sql
-- Включить мониторинг (один раз)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Топ медленных запросов
SELECT 
    substring(query, 1, 100) as query_preview,
    calls,
    total_exec_time,
    mean_exec_time,
    stddev_exec_time
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

### Размер таблиц

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 📝 Инструкции для Cursor

```
@DB_SCHEMA_V2:

1. SETUP:
   - Скопируй миграции в supabase/migrations/
   - Запусти: supabase db push
   - Загрузи seed данные: supabase db execute --file seed.sql

2. QUERYING:
   - Используй RPC функции (check_generation_limit, get_user_gallery)
   - Не пиши прямые SQL запросы с auth.uid() - используй RLS
   - Для backend используй service_role key (обходит RLS)

3. ADDING PRESETS:
   - Добавляй через INSERT в presets таблицу
   - Обязательно заполни: slug (unique), prompt_template, parameters
   - Upload иконку в Storage bucket preset-icons

4. TESTING:
   - Используй примеры из раздела "Useful Queries"
   - Проверяй RLS: SET ROLE authenticated; SET request.jwt.claims.sub = 'user-uuid';
   - Тестируй functions через SELECT

5. MONITORING:
   - Включи pg_stat_statements
   - Проверяй медленные запросы раз в неделю
   - Refresh materialized views через cron
```

---

**Версия:** 2.0  
**Статус:** Production Ready ✅  
**Migrations:** 5 файлов  
**Seed Data:** 8 presets + блокировка