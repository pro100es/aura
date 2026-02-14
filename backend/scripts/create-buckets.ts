/**
 * Create Supabase Storage buckets for Aura
 * Run: bun run scripts/create-buckets.ts
 */
import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(url, key, {
  auth: { persistSession: false },
});

async function createBucket(
  name: string,
  options: { public?: boolean; fileSizeLimit?: string; allowedMimeTypes?: string[] }
) {
  const { data, error } = await supabase.storage.createBucket(name, options);
  if (error) {
    if (error.message?.includes('already exists')) {
      console.log(`✅ Bucket "${name}" already exists`);
      return;
    }
    console.error(`❌ ${name}:`, error.message);
    return;
  }
  console.log(`✅ Bucket "${name}" created`);
  return data;
}

async function main() {
  console.log('Creating storage buckets...\n');

  await createBucket('uploads', {
    public: false,
    fileSizeLimit: '10MB',
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  });

  await createBucket('results', {
    public: false,
    fileSizeLimit: '50MB',
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  });

  await createBucket('preset-icons', {
    public: true,
    fileSizeLimit: '5MB',
    allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  });

  console.log('\nDone.');
}

main().catch(console.error);
