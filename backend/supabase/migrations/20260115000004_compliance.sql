-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 004: Compliance & Content Moderation
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.blocked_terms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    term TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL CHECK (category IN ('celebrity', 'nsfw', 'violence', 'brand', 'location', 'other')),
    severity TEXT NOT NULL DEFAULT 'high' CHECK (severity IN ('low', 'medium', 'high')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    reason TEXT,
    added_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_blocked_terms_category ON public.blocked_terms(category, is_active) WHERE is_active = true;
CREATE INDEX idx_blocked_terms_severity ON public.blocked_terms(severity) WHERE is_active = true;
CREATE INDEX idx_blocked_terms_term_trgm ON public.blocked_terms USING gin(term gin_trgm_ops);

ALTER TABLE public.blocked_terms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "blocked_terms_service_role_all" ON public.blocked_terms FOR ALL
    USING (auth.jwt()->>'role' = 'service_role')
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

INSERT INTO public.blocked_terms (term, category, severity, reason) VALUES
('trump', 'celebrity', 'high', 'Political figure'),
('biden', 'celebrity', 'high', 'Political figure'),
('musk', 'celebrity', 'high', 'Public figure'),
('kardashian', 'celebrity', 'high', 'Public figure'),
('swift', 'celebrity', 'high', 'Public figure - Taylor Swift'),
('ronaldo', 'celebrity', 'high', 'Public figure'),
('messi', 'celebrity', 'high', 'Public figure'),
('obama', 'celebrity', 'high', 'Political figure'),
('putin', 'celebrity', 'high', 'Political figure'),
('nude', 'nsfw', 'high', 'Adult content'),
('naked', 'nsfw', 'high', 'Adult content'),
('sex', 'nsfw', 'high', 'Adult content'),
('porn', 'nsfw', 'high', 'Adult content'),
('nsfw', 'nsfw', 'high', 'Adult content'),
('xxx', 'nsfw', 'high', 'Adult content'),
('erotic', 'nsfw', 'high', 'Adult content'),
('bikini', 'nsfw', 'medium', 'May violate guidelines'),
('underwear', 'nsfw', 'medium', 'May violate guidelines'),
('gun', 'violence', 'high', 'Weapons'),
('blood', 'violence', 'medium', 'Gore'),
('dead', 'violence', 'high', 'Death'),
('kill', 'violence', 'high', 'Violence'),
('murder', 'violence', 'high', 'Violence'),
('suicide', 'violence', 'high', 'Self-harm'),
('weapon', 'violence', 'high', 'Weapons'),
('coca-cola', 'brand', 'medium', 'Trademarked brand'),
('nike', 'brand', 'medium', 'Trademarked brand'),
('apple logo', 'brand', 'high', 'Our competitor :)'),
('mcdonald', 'brand', 'medium', 'Trademarked brand'),
('starbucks', 'brand', 'medium', 'Trademarked brand'),
('deepfake', 'other', 'high', 'Banned by Apple'),
('face swap', 'other', 'high', 'Banned by Apple'),
('hitler', 'other', 'high', 'Historical figure'),
('nazi', 'other', 'high', 'Hate symbol')
ON CONFLICT (term) DO NOTHING;

CREATE OR REPLACE FUNCTION public.validate_prompt(p_prompt TEXT)
RETURNS TABLE(is_valid BOOLEAN, violations JSONB, message TEXT)
SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE v_violations JSONB := '[]'::jsonb; v_found_term RECORD; v_prompt_lower TEXT;
BEGIN
    v_prompt_lower := lower(p_prompt);
    FOR v_found_term IN
        SELECT term, category, severity FROM public.blocked_terms
        WHERE is_active = true AND v_prompt_lower LIKE '%' || term || '%'
        ORDER BY severity DESC LIMIT 10
    LOOP
        v_violations := v_violations || jsonb_build_object('term', v_found_term.term, 'category', v_found_term.category, 'severity', v_found_term.severity);
    END LOOP;
    IF jsonb_array_length(v_violations) > 0 THEN
        RETURN QUERY SELECT false, v_violations,
            CASE (v_violations->0->>'category')::text
                WHEN 'celebrity' THEN 'Generation with celebrity images prohibited'
                WHEN 'nsfw' THEN 'Adult content prohibited'
                WHEN 'violence' THEN 'Violent content prohibited'
                WHEN 'brand' THEN 'Protected brand usage may violate copyright'
                ELSE 'Blocked content detected'
            END;
    ELSE
        RETURN QUERY SELECT true, '[]'::jsonb, NULL::TEXT;
    END IF;
END;
$$;

DO $$ BEGIN RAISE NOTICE 'Migration 004 completed successfully'; END $$;
