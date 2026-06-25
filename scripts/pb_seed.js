#!/usr/bin/env node
/**
 * PocketBase seed script for NutriTrack
 *
 * Creates the `nt_*` collections (differentiated from existing 1perc_*, rup_*,
 * lta_* schemas) and seeds the exercise database.
 *
 * Usage:
 *   PB_URL=https://pocketbase.scaleupcrm.com \
 *   PB_ADMIN_EMAIL=greatoneplatform@gmail.com \
 *   PB_ADMIN_PASSWORD=0ahltd0jxjexu9a7qw9hxxijfezdv050 \
 *   node scripts/pb_seed.js
 *
 * Idempotent: re-running is safe.
 *
 * PB v0.39 quirks accounted for:
 *   - Use `fields:` (not `schema:`) in POST body
 *   - Relation fields use `collectionId` at top level, NOT inside `options:`
 *   - Select fields use `values:` at top level, NOT inside `options:`
 *   - maxSelect for select must be ≤ number of values defined
 *   - Custom table-level `indexes` with column refs can fail — use field-level `index: true` in field options
 *   - Rules referencing cross-collection fields are validated at create time,
 *     so create with empty rules, then PATCH to set real rules
 */

const https = require('https');
const http = require('http');
const { URL } = require('url');

const PB_URL = process.env.PB_URL || 'https://pocketbase.scaleupcrm.com';
const PB_ADMIN_EMAIL = process.env.PB_ADMIN_EMAIL;
const PB_ADMIN_PASSWORD = process.env.PB_ADMIN_PASSWORD;

if (!PB_ADMIN_EMAIL || !PB_ADMIN_PASSWORD) {
  console.error('Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD env vars');
  process.exit(1);
}

const MUSCLE_VALUES = ['chest', 'back', 'shoulders', 'arms', 'legs', 'glutes', 'core', 'fullBody', 'cardio'];

function request(method, path, opts = {}) {
  const { body, token } = opts;
  return new Promise((resolve, reject) => {
    const url = new URL(PB_URL + path);
    const data = body ? JSON.stringify(body) : null;
    const lib = url.protocol === 'https:' ? https : http;
    const req = lib.request({
      method,
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: token } : {}),
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      },
    }, (res) => {
      let buf = '';
      res.on('data', (c) => (buf += c));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try { resolve(buf ? JSON.parse(buf) : {}); } catch { resolve({}); }
        } else {
          reject(new Error(`${res.statusCode} ${method} ${path}: ${buf}`));
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

// ── Collection definitions ─────────────────────────────────────
//
// Select fields use `values` at top level (not in options).
// maxSelect ≤ number of values.

const NT_USERS_ID_PLACEHOLDER = '__NT_USERS_ID__';

const COLLECTIONS = [
  {
    name: 'nt_users',
    type: 'base',
    fields: [
      { name: 'auth_user_id', type: 'text', required: false, options: { max: 100 } },
      { name: 'name', type: 'text', required: false, options: { max: 255 } },
      { name: 'avatar', type: 'file', required: false, options: {
          maxSelect: 1, maxSize: 5242880,
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        }
      },
      { name: 'sex', type: 'select', required: false, maxSelect: 1,
        values: ['male', 'female', 'other'] },
      { name: 'birth_date', type: 'date', required: false, options: {} },
      { name: 'height_cm', type: 'number', required: false, options: {} },
      { name: 'weight_kg', type: 'number', required: false, options: {} },
      { name: 'activity', type: 'select', required: false, maxSelect: 1,
        values: ['sedentary', 'light', 'moderate', 'active', 'athletic'] },
      { name: 'goal', type: 'select', required: false, maxSelect: 1,
        values: ['aggressiveCut', 'moderateCut', 'recomposition', 'leanBulk', 'aggressiveBulk', 'maintenance'] },
      { name: 'use_metric', type: 'bool', required: false, options: {} },
    ],
    rules: {
      listRule: 'auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      viewRule: 'auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      createRule: '',
      updateRule: 'auth_user_id = @request.auth.id',
      deleteRule: '@request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_food_logs',
    type: 'base',
    fields: [
      { name: 'nt_user', type: 'relation', required: true, collectionId: NT_USERS_ID_PLACEHOLDER, cascadeDelete: true, maxSelect: 1, minSelect: 1 },
      { name: 'name', type: 'text', required: true, options: { max: 500 } },
      { name: 'brand', type: 'text', required: false, options: { max: 200 } },
      { name: 'grams', type: 'number', required: true, options: { min: 0 } },
      { name: 'protein', type: 'number', required: true, options: { min: 0 } },
      { name: 'carbs', type: 'number', required: true, options: { min: 0 } },
      { name: 'fat', type: 'number', required: true, options: { min: 0 } },
      { name: 'fiber', type: 'number', required: false, options: { min: 0 } },
      { name: 'sugar', type: 'number', required: false, options: { min: 0 } },
      { name: 'sodium', type: 'number', required: false, options: { min: 0 } },
      { name: 'slot', type: 'select', required: true, maxSelect: 1,
        values: ['breakfast', 'lunch', 'dinner', 'snack'] },
      { name: 'source', type: 'select', required: true, maxSelect: 1,
        values: ['cameraAI', 'voiceAI', 'barcode', 'search', 'recipe', 'custom'] },
      { name: 'confidence', type: 'number', required: false, options: { min: 0, max: 1 } },
      { name: 'image', type: 'file', required: false, options: {
          maxSelect: 1, maxSize: 5242880, mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        }
      },
      { name: 'notes', type: 'text', required: false, options: { max: 1000 } },
      { name: 'external_id', type: 'text', required: false, options: { max: 200 } },
      { name: 'is_favorite', type: 'bool', required: false, options: {} },
      { name: 'logged_at', type: 'date', required: true, options: {} },
    ],
    rules: {
      listRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      viewRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      createRule: 'nt_user.auth_user_id = @request.auth.id',
      updateRule: 'nt_user.auth_user_id = @request.auth.id',
      deleteRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_exercises',
    type: 'base',
    fields: [
      { name: 'name', type: 'text', required: true, options: { max: 200 } },
      { name: 'primary_muscle', type: 'select', required: true, maxSelect: 1,
        values: MUSCLE_VALUES },
      { name: 'secondary_muscles', type: 'select', required: false, maxSelect: MUSCLE_VALUES.length,
        values: MUSCLE_VALUES },
      { name: 'equipment', type: 'select', required: true, maxSelect: 1,
        values: ['bodyweight', 'dumbbell', 'barbell', 'kettlebell', 'machine', 'cable', 'band', 'other'] },
      { name: 'difficulty', type: 'select', required: true, maxSelect: 1,
        values: ['beginner', 'intermediate', 'advanced'] },
      { name: 'category', type: 'select', required: true, maxSelect: 1,
        values: ['strength', 'cardio', 'flexibility', 'plyometric', 'olympic', 'powerlifting'] },
      { name: 'force', type: 'select', required: false, maxSelect: 1,
        values: ['push', 'pull', 'static'] },
      { name: 'mechanic', type: 'select', required: false, maxSelect: 1,
        values: ['compound', 'isolation'] },
      { name: 'instructions', type: 'text', required: false, options: { max: 2000 } },
      { name: 'tips', type: 'text', required: false, options: { max: 1000 } },
      { name: 'video_url', type: 'url', required: false, options: {} },
      { name: 'image_url', type: 'url', required: false, options: {} },
      { name: 'tags', type: 'json', required: false, options: { maxSize: 2000 } },
      { name: 'calories_per_hour', type: 'number', required: false, options: { min: 0 } },
      { name: 'popularity', type: 'number', required: false, options: { min: 0 } },
    ],
    rules: {
      listRule: '',
      viewRule: '',
      createRule: '@request.auth.collectionId = "_superusers"',
      updateRule: '@request.auth.collectionId = "_superusers"',
      deleteRule: '@request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_workout_sessions',
    type: 'base',
    fields: [
      { name: 'nt_user', type: 'relation', required: true, collectionId: NT_USERS_ID_PLACEHOLDER, cascadeDelete: true, maxSelect: 1, minSelect: 1 },
      { name: 'name', type: 'text', required: true, options: { max: 200 } },
      { name: 'started_at', type: 'date', required: true, options: {} },
      { name: 'ended_at', type: 'date', required: false, options: {} },
      { name: 'exercises', type: 'json', required: false, options: { maxSize: 65535 } },
      { name: 'perceived_exertion', type: 'number', required: false, options: { min: 0, max: 10 } },
      { name: 'calories_burned', type: 'number', required: false, options: { min: 0 } },
      { name: 'notes', type: 'text', required: false, options: { max: 2000 } },
    ],
    rules: {
      listRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      viewRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      createRule: 'nt_user.auth_user_id = @request.auth.id',
      updateRule: 'nt_user.auth_user_id = @request.auth.id',
      deleteRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_weight_entries',
    type: 'base',
    fields: [
      { name: 'nt_user', type: 'relation', required: true, collectionId: NT_USERS_ID_PLACEHOLDER, cascadeDelete: true, maxSelect: 1, minSelect: 1 },
      { name: 'recorded_at', type: 'date', required: true, options: {} },
      { name: 'weight_kg', type: 'number', required: true, options: { min: 0 } },
      { name: 'body_fat_pct', type: 'number', required: false, options: { min: 0, max: 100 } },
      { name: 'muscle_kg', type: 'number', required: false, options: { min: 0 } },
      { name: 'notes', type: 'text', required: false, options: { max: 500 } },
    ],
    rules: {
      listRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      viewRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      createRule: 'nt_user.auth_user_id = @request.auth.id',
      updateRule: 'nt_user.auth_user_id = @request.auth.id',
      deleteRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_favorites',
    type: 'base',
    fields: [
      { name: 'nt_user', type: 'relation', required: true, collectionId: NT_USERS_ID_PLACEHOLDER, cascadeDelete: true, maxSelect: 1, minSelect: 1 },
      { name: 'food_name', type: 'text', required: true, options: { max: 500 } },
      { name: 'brand', type: 'text', required: false, options: { max: 200 } },
      { name: 'grams', type: 'number', required: true, options: { min: 0 } },
      { name: 'protein', type: 'number', required: false, options: { min: 0 } },
      { name: 'carbs', type: 'number', required: false, options: { min: 0 } },
      { name: 'fat', type: 'number', required: false, options: { min: 0 } },
      { name: 'times_logged', type: 'number', required: false, options: { min: 0 } },
      { name: 'last_logged_at', type: 'date', required: false, options: {} },
    ],
    rules: {
      listRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      viewRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      createRule: 'nt_user.auth_user_id = @request.auth.id',
      updateRule: 'nt_user.auth_user_id = @request.auth.id',
      deleteRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_meal_templates',
    type: 'base',
    fields: [
      { name: 'nt_user', type: 'relation', required: true, collectionId: NT_USERS_ID_PLACEHOLDER, cascadeDelete: true, maxSelect: 1, minSelect: 1 },
      { name: 'name', type: 'text', required: true, options: { max: 200 } },
      { name: 'slot', type: 'select', required: true, maxSelect: 1,
        values: ['breakfast', 'lunch', 'dinner', 'snack'] },
      { name: 'items', type: 'json', required: false, options: { maxSize: 65535 } },
      { name: 'total_calories', type: 'number', required: false, options: { min: 0 } },
      { name: 'times_used', type: 'number', required: false, options: { min: 0 } },
    ],
    rules: {
      listRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      viewRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
      createRule: 'nt_user.auth_user_id = @request.auth.id',
      updateRule: 'nt_user.auth_user_id = @request.auth.id',
      deleteRule: 'nt_user.auth_user_id = @request.auth.id || @request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_sync_queue',
    type: 'base',
    fields: [
      { name: 'nt_user', type: 'relation', required: false, collectionId: NT_USERS_ID_PLACEHOLDER, cascadeDelete: false, maxSelect: 1, minSelect: 0 },
      { name: 'entity_type', type: 'select', required: true, maxSelect: 1,
        values: ['food_log', 'workout', 'weight', 'favorite', 'meal_template'] },
      { name: 'entity_id', type: 'text', required: true, options: { max: 100 } },
      { name: 'operation', type: 'select', required: true, maxSelect: 1,
        values: ['create', 'update', 'delete'] },
      { name: 'payload', type: 'json', required: false, options: { maxSize: 65535 } },
      { name: 'queued_at', type: 'date', required: true, options: {} },
      { name: 'retries', type: 'number', required: false, options: { min: 0 } },
      { name: 'last_error', type: 'text', required: false, options: { max: 2000 } },
    ],
    rules: {
      listRule: '@request.auth.collectionId = "_superusers"',
      viewRule: '@request.auth.collectionId = "_superusers"',
      createRule: '',
      updateRule: '@request.auth.collectionId = "_superusers"',
      deleteRule: '@request.auth.collectionId = "_superusers"',
    },
  },
  {
    name: 'nt_barcode_cache',
    type: 'base',
    fields: [
      // The actual barcode (EAN-13, UPC-A, etc). Indexed unique so lookups
      // are O(1) and we never duplicate cache entries across users.
      { name: 'barcode', type: 'text', required: true, options: { max: 32 } },
      // Cached Open Food Facts response, normalized.
      { name: 'name', type: 'text', required: true, options: { max: 500 } },
      { name: 'brand', type: 'text', required: false, options: { max: 200 } },
      { name: 'image_url', type: 'url', required: false, options: {} },
      { name: 'serving_grams', type: 'number', required: false, options: { min: 0 } },
      // Per-100g macros stored as denormalized columns so we don't need to
      // parse JSON on every read. Doubles as the lookup payload for offline.
      { name: 'protein_100g', type: 'number', required: false, options: { min: 0 } },
      { name: 'carbs_100g', type: 'number', required: false, options: { min: 0 } },
      { name: 'fat_100g', type: 'number', required: false, options: { min: 0 } },
      { name: 'fiber_100g', type: 'number', required: false, options: { min: 0 } },
      { name: 'sugar_100g', type: 'number', required: false, options: { min: 0 } },
      { name: 'sodium_100g', type: 'number', required: false, options: { min: 0 } },
      { name: 'energy_kcal_100g', type: 'number', required: false, options: { min: 0 } },
      // Metadata
      { name: 'categories', type: 'json', required: false, options: { maxSize: 2000 } },
      { name: 'allergens', type: 'json', required: false, options: { maxSize: 2000 } },
      { name: 'nutriscore', type: 'text', required: false, options: { max: 4 } },
      // Source + freshness
      { name: 'source', type: 'text', required: false, options: { max: 50 } },
      { name: 'fetched_at', type: 'date', required: true, options: {} },
      { name: 'hit_count', type: 'number', required: false, options: { min: 0 } },
    ],
    rules: {
      // Public read: any logged-in user can read cached barcodes.
      // We gate listRule on auth so unauthenticated probes can't dump the
      // whole table; reads by id are allowed for any signed-in user.
      listRule: '@request.auth.id != ""',
      viewRule: '@request.auth.id != ""',
      // Only superuser writes — caches are populated by the OFF sync job,
      // not by individual users.
      createRule: '@request.auth.collectionId = "_superusers"',
      updateRule: '@request.auth.collectionId = "_superusers"',
      deleteRule: '@request.auth.collectionId = "_superusers"',
    },
  },
];

// ── Exercise data ──────────────────────────────────────────────
const EXERCISES = require('./exercises_chest.js');

async function main() {
  console.log(`Authenticating to ${PB_URL} as ${PB_ADMIN_EMAIL}...`);
  const authResult = await request('POST', '/api/collections/_superusers/auth-with-password', {
    body: { identity: PB_ADMIN_EMAIL, password: PB_ADMIN_PASSWORD },
  });
  const token = authResult.token;
  if (!token) throw new Error('No token from auth');
  console.log('  ✓ Auth OK\n');

  const existing = await request('GET', '/api/collections?perPage=500', { token });
  const existingByName = new Map(existing.items.map((c) => [c.name, c]));
  console.log(`Found ${existing.items.length} existing collections\n`);

  // Pass 1: nt_users (no relations to it)
  const ntUsers = existingByName.get('nt_users');
  let ntUsersId;
  if (ntUsers) {
    ntUsersId = ntUsers.id;
    console.log(`  ⏭  nt_users exists (${ntUsersId})`);
  } else {
    process.stdout.write('  + nt_users ... ');
    const def = COLLECTIONS[0];
    try {
      const result = await request('POST', '/api/collections', {
        body: {
          name: def.name, type: def.type, fields: def.fields,
          listRule: '', viewRule: '', createRule: '', updateRule: '', deleteRule: '',
          options: {},
        },
        token,
      });
      ntUsersId = result.id;
      await request('PATCH', `/api/collections/${ntUsersId}`, { body: def.rules, token });
      console.log(`OK (${ntUsersId})`);
    } catch (e) {
      console.log('FAIL\n' + e.message);
      throw e;
    }
  }

  // Pass 2: remaining collections
  console.log('\nCreating other collections:');
  for (const def of COLLECTIONS.slice(1)) {
    if (existingByName.has(def.name)) {
      console.log(`  ⏭  ${def.name} (exists)`);
      continue;
    }
    process.stdout.write(`  + ${def.name} ... `);
    try {
      const fields = JSON.parse(JSON.stringify(def.fields));
      for (const f of fields) {
        if (f.collectionId === NT_USERS_ID_PLACEHOLDER) f.collectionId = ntUsersId;
      }
      const result = await request('POST', '/api/collections', {
        body: {
          name: def.name, type: def.type, fields,
          listRule: '', viewRule: '', createRule: '', updateRule: '', deleteRule: '',
          options: {},
        },
        token,
      });
      await request('PATCH', `/api/collections/${result.id}`, { body: def.rules, token });
      console.log(`OK (${result.id})`);
    } catch (e) {
      console.log('FAIL\n' + e.message.split('\n')[0]);
      throw e;
    }
  }

  // Pass 3: seed exercises
  console.log(`\nSeeding ${EXERCISES.length} exercises...`);
  const existingRecords = await request('GET', `/api/collections/nt_exercises/records?perPage=200&fields=name`, { token });
  const existingNames = new Set(existingRecords.items.map((r) => r.name));
  const toInsert = EXERCISES.filter((e) => !existingNames.has(e.name));
  console.log(`  ${existingNames.size} already present, ${toInsert.length} new\n`);

  const BATCH = 50;
  let inserted = 0;
  for (let i = 0; i < toInsert.length; i += BATCH) {
    const batch = toInsert.slice(i, i + BATCH);
    process.stdout.write(`  batch ${Math.floor(i / BATCH) + 1}/${Math.ceil(toInsert.length / BATCH)} ... `);
    try {
      await request('POST', '/api/batch', {
        body: { requests: batch.map((item) => ({
          method: 'POST',
          url: '/api/collections/nt_exercises/records',
          body: item,
        })) },
        token,
      });
      inserted += batch.length;
      console.log(`OK (${inserted}/${toInsert.length})`);
    } catch (e) {
      console.log('FAIL — falling back to individual inserts');
      for (const item of batch) {
        try {
          await request('POST', '/api/collections/nt_exercises/records', { body: item, token });
          inserted++;
        } catch (e2) {
          console.error(`     ✗ ${item.name}: ${e2.message.split('\n')[0]}`);
        }
      }
    }
  }
  console.log(`\n  ✓ ${inserted} exercises inserted\n`);

  // Final summary
  const summary = await request('GET', `/api/collections/nt_exercises/records?perPage=1`, { token });
  console.log('Final state:');
  console.log(`  nt_exercises: ${summary.totalItems} records`);

  const allNt = await request('GET', `/api/collections?perPage=200&filter=name~'nt_'`, { token });
  console.log(`  nt_* collections: ${allNt.items.length}`);
  for (const c of allNt.items) {
    console.log(`    - ${c.name} (${c.type}, ${c.fields?.length ?? 0} fields)`);
  }
  console.log('\n✅ Done.');
}

main().catch((e) => {
  console.error('\n❌ FAILED:', e.message);
  process.exit(1);
});
