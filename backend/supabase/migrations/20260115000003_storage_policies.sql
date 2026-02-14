-- ============================================================================
-- Aura Database Schema v2.0
-- Migration 003: Supabase Storage Buckets & RLS Policies
-- Note: Create buckets manually in Supabase Dashboard: uploads, results, preset-icons
-- ============================================================================

-- Bucket: uploads
CREATE POLICY "uploads_insert_own_folder" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'uploads' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "uploads_select_own_folder" ON storage.objects FOR SELECT
    USING (bucket_id = 'uploads' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "uploads_delete_own_folder" ON storage.objects FOR DELETE
    USING (bucket_id = 'uploads' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Bucket: results
CREATE POLICY "results_insert_service_role" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'results' AND auth.jwt()->>'role' = 'service_role');

CREATE POLICY "results_select_own_folder" ON storage.objects FOR SELECT
    USING (bucket_id = 'results' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "results_delete_own_folder" ON storage.objects FOR DELETE
    USING (bucket_id = 'results' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Bucket: preset-icons
CREATE POLICY "preset_icons_select_public" ON storage.objects FOR SELECT
    USING (bucket_id = 'preset-icons');

CREATE POLICY "preset_icons_insert_service_role" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'preset-icons' AND auth.jwt()->>'role' = 'service_role');

CREATE POLICY "preset_icons_update_service_role" ON storage.objects FOR UPDATE
    USING (bucket_id = 'preset-icons' AND auth.jwt()->>'role' = 'service_role');

CREATE POLICY "preset_icons_delete_service_role" ON storage.objects FOR DELETE
    USING (bucket_id = 'preset-icons' AND auth.jwt()->>'role' = 'service_role');

DO $$ BEGIN RAISE NOTICE 'Migration 003 completed successfully'; END $$;
