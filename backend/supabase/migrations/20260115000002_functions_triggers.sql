-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 002: Functions, Triggers, and Automation
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER presets_updated_at BEFORE UPDATE ON public.presets
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER generation_assets_updated_at BEFORE UPDATE ON public.generation_assets
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Auto-create profile on auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(trim(NEW.email), ''), NEW.id::text || '@users.aura.local'),
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN RETURN NEW;
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Reset daily counters
CREATE OR REPLACE FUNCTION public.reset_daily_generation_counters()
RETURNS INTEGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE updated_count INTEGER;
BEGIN
    UPDATE public.profiles SET generations_used_today = 0, last_generation_reset = CURRENT_DATE
    WHERE last_generation_reset < CURRENT_DATE;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;

-- Increment usage counters
CREATE OR REPLACE FUNCTION public.increment_generation_counters()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.profiles SET generations_used_today = generations_used_today + 1, total_generations = total_generations + 1
    WHERE id = NEW.user_id;
    UPDATE public.presets SET usage_count = usage_count + 1 WHERE id = NEW.preset_id;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to increment counters: %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER generation_increment_counters AFTER INSERT ON public.generations
    FOR EACH ROW EXECUTE FUNCTION public.increment_generation_counters();

-- Check generation limit
CREATE OR REPLACE FUNCTION public.check_generation_limit(p_user_id UUID)
RETURNS TABLE(can_generate BOOLEAN, used_today INTEGER, daily_limit INTEGER, subscription_tier TEXT, reason TEXT)
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE v_profile RECORD;
BEGIN
    SELECT p.subscription_tier, p.generations_used_today, p.subscription_expires_at,
        CASE WHEN p.subscription_tier = 'pro' THEN 999999 WHEN p.subscription_tier = 'free' THEN 3 ELSE 0 END as limit
    INTO v_profile FROM public.profiles p WHERE p.id = p_user_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 0, 0, 'free'::TEXT, 'User not found'::TEXT;
        RETURN;
    END IF;
    IF v_profile.subscription_tier = 'pro' AND v_profile.subscription_expires_at IS NOT NULL AND v_profile.subscription_expires_at < now() THEN
        RETURN QUERY SELECT false, v_profile.generations_used_today, v_profile.limit, 'free'::TEXT, 'Subscription expired'::TEXT;
        RETURN;
    END IF;
    IF v_profile.generations_used_today >= v_profile.limit THEN
        RETURN QUERY SELECT false, v_profile.generations_used_today, v_profile.limit, v_profile.subscription_tier, 'Daily limit exceeded'::TEXT;
        RETURN;
    END IF;
    RETURN QUERY SELECT true, v_profile.generations_used_today, v_profile.limit, v_profile.subscription_tier, NULL::TEXT;
END;
$$;

-- Get user gallery
CREATE OR REPLACE FUNCTION public.get_user_gallery(
    p_user_id UUID, p_page INTEGER DEFAULT 1, p_limit INTEGER DEFAULT 20,
    p_preset_id UUID DEFAULT NULL, p_status TEXT DEFAULT NULL, p_favorites_only BOOLEAN DEFAULT false
)
RETURNS TABLE(generation_id UUID, preset_name TEXT, preset_slug TEXT, preset_icon_url TEXT, status TEXT,
    created_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, processing_time NUMERIC, outputs JSONB, total_count BIGINT)
SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH filtered_generations AS (
        SELECT g.id FROM public.generations g
        WHERE g.user_id = p_user_id
            AND (p_preset_id IS NULL OR g.preset_id = p_preset_id)
            AND (p_status IS NULL OR g.status = p_status)
            AND (NOT p_favorites_only OR EXISTS (
                SELECT 1 FROM public.generation_assets ga WHERE ga.generation_id = g.id AND ga.is_favorite = true
            ))
    ),
    total AS (SELECT count(*) as cnt FROM filtered_generations)
    SELECT g.id, p.name, p.slug, p.icon_url, g.status, g.created_at, g.completed_at, g.processing_time_seconds,
        COALESCE(jsonb_agg(jsonb_build_object('id', ga.id, 'url', ga.image_url, 'variant', ga.variant, 'is_favorite', ga.is_favorite, 'width', ga.width, 'height', ga.height, 'blurhash', ga.blurhash)
            ORDER BY CASE ga.variant WHEN 'safe_match' THEN 1 WHEN 'editorial' THEN 2 WHEN 'lifestyle' THEN 3 WHEN 'artistic' THEN 4 ELSE 5 END)
            FILTER (WHERE ga.id IS NOT NULL), '[]'::jsonb),
        (SELECT cnt FROM total)
    FROM public.generations g
    INNER JOIN filtered_generations fg ON fg.id = g.id
    LEFT JOIN public.presets p ON g.preset_id = p.id
    LEFT JOIN public.generation_assets ga ON ga.generation_id = g.id
    GROUP BY g.id, p.name, p.slug, p.icon_url, g.status, g.created_at, g.completed_at, g.processing_time_seconds
    ORDER BY g.created_at DESC LIMIT p_limit OFFSET (p_page - 1) * p_limit;
END;
$$;

-- Cleanup expired uploads
CREATE OR REPLACE FUNCTION public.cleanup_expired_uploads()
RETURNS TABLE(deleted_count INTEGER, freed_bytes BIGINT, file_paths TEXT[])
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE v_deleted_count INTEGER; v_freed_bytes BIGINT; v_file_paths TEXT[];
BEGIN
    WITH deleted AS (DELETE FROM public.user_uploads WHERE expires_at < now() RETURNING id, file_path, file_size_bytes)
    SELECT COUNT(*)::INTEGER, COALESCE(SUM(file_size_bytes), 0), array_agg(file_path)
    INTO v_deleted_count, v_freed_bytes, v_file_paths FROM deleted;
    RETURN QUERY SELECT v_deleted_count, v_freed_bytes, v_file_paths;
END;
$$;

-- Update generation status (webhooks)
CREATE OR REPLACE FUNCTION public.update_generation_status(
    p_replicate_id TEXT, p_status TEXT, p_error_message TEXT DEFAULT NULL,
    p_error_code TEXT DEFAULT NULL, p_processing_time NUMERIC DEFAULT NULL
)
RETURNS TABLE(generation_id UUID, user_id UUID, updated BOOLEAN)
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE v_generation_id UUID; v_user_id UUID;
BEGIN
    UPDATE public.generations
    SET status = p_status,
        completed_at = CASE WHEN p_status IN ('succeeded', 'failed', 'canceled') THEN now() ELSE completed_at END,
        error_message = COALESCE(p_error_message, error_message),
        error_code = COALESCE(p_error_code, error_code),
        processing_time_seconds = COALESCE(p_processing_time, processing_time_seconds)
    WHERE replicate_id = p_replicate_id
    RETURNING id, user_id INTO v_generation_id, v_user_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::UUID, NULL::UUID, false;
        RETURN;
    END IF;
    RETURN QUERY SELECT v_generation_id, v_user_id, true;
END;
$$;

-- Toggle favorite
CREATE OR REPLACE FUNCTION public.toggle_favorite(p_asset_id UUID)
RETURNS BOOLEAN SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE v_new_status BOOLEAN; v_user_id UUID;
BEGIN
    SELECT g.user_id INTO v_user_id FROM public.generation_assets ga
    JOIN public.generations g ON g.id = ga.generation_id WHERE ga.id = p_asset_id;
    IF v_user_id != auth.uid() THEN RAISE EXCEPTION 'Access denied'; END IF;
    UPDATE public.generation_assets SET is_favorite = NOT is_favorite WHERE id = p_asset_id
    RETURNING is_favorite INTO v_new_status;
    RETURN v_new_status;
END;
$$;

-- Get user stats
CREATE OR REPLACE FUNCTION public.get_user_stats(p_user_id UUID)
RETURNS TABLE(total_generations INTEGER, favorites_count INTEGER, most_used_preset TEXT, avg_processing_time NUMERIC,
    subscription_tier TEXT, generations_used_today INTEGER, daily_limit INTEGER)
SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT COUNT(DISTINCT g.id)::INTEGER as total_gens,
            COUNT(DISTINCT ga.id) FILTER (WHERE ga.is_favorite = true)::INTEGER as favs,
            MODE() WITHIN GROUP (ORDER BY p.name) as popular_preset,
            AVG(g.processing_time_seconds) as avg_time
        FROM public.generations g
        LEFT JOIN public.generation_assets ga ON ga.generation_id = g.id
        LEFT JOIN public.presets p ON p.id = g.preset_id
        WHERE g.user_id = p_user_id AND g.status = 'succeeded'
    )
    SELECT s.total_gens, s.favs, s.popular_preset, ROUND(s.avg_time, 2),
        pr.subscription_tier, pr.generations_used_today,
        CASE WHEN pr.subscription_tier = 'pro' THEN 999999 WHEN pr.subscription_tier = 'free' THEN 3 END
    FROM stats s CROSS JOIN public.profiles pr WHERE pr.id = p_user_id;
END;
$$;

-- Delete user account
CREATE OR REPLACE FUNCTION public.delete_user_account(p_user_id UUID)
RETURNS TABLE(deleted_generations INTEGER, deleted_assets INTEGER, deleted_uploads INTEGER, storage_paths TEXT[])
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE v_gens INTEGER; v_assets INTEGER; v_uploads INTEGER; v_paths TEXT[];
BEGIN
    IF p_user_id != auth.uid() THEN RAISE EXCEPTION 'Access denied'; END IF;
    SELECT array_agg(DISTINCT file_path) INTO v_paths FROM public.user_uploads WHERE user_id = p_user_id;
    DELETE FROM public.generation_assets WHERE generation_id IN (SELECT id FROM public.generations WHERE user_id = p_user_id);
    GET DIAGNOSTICS v_assets = ROW_COUNT;
    DELETE FROM public.generations WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_gens = ROW_COUNT;
    DELETE FROM public.user_uploads WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_uploads = ROW_COUNT;
    DELETE FROM public.profiles WHERE id = p_user_id;
    RETURN QUERY SELECT v_gens, v_assets, v_uploads, v_paths;
END;
$$;

DO $$ BEGIN RAISE NOTICE 'Migration 002 completed successfully'; END $$;
