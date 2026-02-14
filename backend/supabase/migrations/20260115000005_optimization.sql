-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 005: Performance Optimization
-- ============================================================================

CREATE INDEX idx_generations_gallery ON public.generations(user_id, status, created_at DESC)
    WHERE status = 'succeeded';

CREATE INDEX idx_assets_favorites_by_user ON public.generation_assets(generation_id, is_favorite, created_at DESC)
    WHERE is_favorite = true;

CREATE INDEX idx_presets_analytics ON public.presets(mode, is_premium, usage_count DESC)
    WHERE is_active = true;

CREATE INDEX idx_generations_failed ON public.generations(created_at DESC, error_code)
    WHERE status = 'failed';

CREATE INDEX idx_generations_input_params ON public.generations USING gin(input_params);
CREATE INDEX idx_presets_parameters ON public.presets USING gin(parameters);

CREATE MATERIALIZED VIEW IF NOT EXISTS public.daily_stats AS
SELECT DATE(created_at) as date,
    COUNT(*) as total_generations,
    COUNT(*) FILTER (WHERE status = 'succeeded') as successful,
    COUNT(*) FILTER (WHERE status = 'failed') as failed,
    AVG(processing_time_seconds) FILTER (WHERE status = 'succeeded') as avg_time,
    COUNT(DISTINCT user_id) as unique_users
FROM public.generations
GROUP BY DATE(created_at)
ORDER BY date DESC;

CREATE UNIQUE INDEX idx_daily_stats_date ON public.daily_stats(date);

CREATE OR REPLACE FUNCTION public.refresh_daily_stats()
RETURNS void SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.daily_stats;
END;
$$;

DO $$ BEGIN RAISE NOTICE 'Migration 005 completed successfully'; END $$;
