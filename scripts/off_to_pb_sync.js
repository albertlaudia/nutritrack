#!/usr/bin/env node
/**
 * Open Food Facts → PocketBase sync job.
 *
 * Reads recently-fetched OFF products (tracked in a small JSONL log the
 * device can append to, or via PB's own query for high-traffic products)
 * and upserts them into the nt_barcode_cache collection. After this runs,
 * every device lookup hits the cache first, skipping the OFF network call.
 *
 * Run as a cron. Suggested cadence: every 6 hours. Cheap (PocketBase is
 * co-located on Dokploy), and OFF's data improves over time so the cache
 * benefits from periodic refresh.
 *
 * Usage:
 *   PB_URL=https://pocketbase.scaleupcrm.com \
 *   PB_ADMIN_EMAIL=... PB_ADMIN_PASSWORD=... \
 *   node scripts/off_to_pb_sync.js
 *
 *   # Dry run (no writes):
 *   PB_DRY_RUN=1 node scripts/off_to_pb_sync.js
 *
 *   # Process a specific list of barcodes (one per line via stdin or file):
 *   node scripts/off_to_pb_sync.js --barcodes=data/barcodes-to-seed.txt
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');

const PB_URL = process.env.PB_URL || 'https://pocketbase.scaleupcrm.com';
const PB_ADMIN_EMAIL = process.env.PB_ADMIN_EMAIL;
const PB_ADMIN_PASSWORD = process.env.PB_ADMIN_PASSWORD;
const DRY_RUN = process.env.PB_DRY_RUN === '1';
const OFF_BASE = process.env.OFF_BASE || 'https://world.openfoodfacts.org';

if (!DRY_RUN && (!PB_ADMIN_EMAIL || !PB_ADMIN_PASSWORD)) {
  console.error('Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD (or PB_DRY_RUN=1)');
  process.exit(1);
}

function request(method, baseUrl, path, opts = {}) {
  const { body, token } = opts;
  return new Promise((resolve, reject) => {
    const url = new URL(baseUrl + path);
    const data = body ? JSON.stringify(body) : null;
    const lib = url.protocol === 'https:' ? https : http;
    const req = lib.request({
      method,
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'NutriTrackSync/1.0 (https://nutritrack.app)',
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

async function fetchOff(barcode) {
  const url = `${OFF_BASE}/api/v2/product/${barcode}.json`;
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'NutriTrackSync/1.0' } }, (res) => {
      let buf = '';
      res.on('data', (c) => (buf += c));
      res.on('end', () => {
        try {
          const data = JSON.parse(buf);
          if (data.status !== 1 || !data.product) {
            resolve(null);
            return;
          }
          const p = data.product;
          const n = p.nutriments || {};
          resolve({
            barcode,
            name: p.product_name || p.product_name_en || p.generic_name || 'Unknown',
            brand: p.brands || null,
            image_url: p.image_front_url || p.image_url || null,
            serving_grams: parseServing(p.serving_size),
            protein_100g: num(n.proteins_100g ?? n.proteins),
            carbs_100g: num(n.carbohydrates_100g ?? n.carbohydrates),
            fat_100g: num(n.fat_100g ?? n.fat),
            fiber_100g: num(n.fiber_100g ?? n.fiber),
            sugar_100g: num(n.sugars_100g ?? n.sugars),
            sodium_100g: num(n.sodium_100g ?? n.sodium) || (num(n.salt_100g ?? n.salt) * 0.4),
            energy_kcal_100g: num(n['energy-kcal_100g'] ?? n['energy-kcal']),
            categories: parseList(p.categories),
            allergens: parseList(p.allergens),
            nutriscore: p.nutriscore_grade || null,
          });
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

function num(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') {
    const x = parseFloat(v.replace(',', '.'));
    return isNaN(x) ? 0 : x;
  }
  return 0;
}

function parseServing(s) {
  if (!s) return null;
  const m = String(s).match(/(\d+(?:[.,]\d+)?)/);
  if (!m) return null;
  const n = parseFloat(m[1].replace(',', '.'));
  return isNaN(n) || n <= 0 ? null : n;
}

function parseList(s) {
  if (!s) return [];
  return String(s).split(',').map((x) => x.trim()).filter(Boolean).slice(0, 20);
}

async function main() {
  // Parse CLI args
  const args = process.argv.slice(2);
  const barcodeFile = args.find((a) => a.startsWith('--barcodes='))?.split('=')[1];

  let barcodes = [];
  if (barcodeFile) {
    barcodes = fs.readFileSync(barcodeFile, 'utf8')
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean);
    console.log(`Loaded ${barcodes.length} barcodes from ${barcodeFile}`);
  } else if (!DRY_RUN) {
    console.error('No --barcodes=path/to/file.txt given and PB_DRY_RUN not set.');
    console.error('Usage: node scripts/off_to_pb_sync.js --barcodes=path/to/file.txt');
    process.exit(1);
  }

  // Auth to PB
  let token = null;
  if (!DRY_RUN) {
    console.log(`Authenticating to ${PB_URL}...`);
    const authResult = await request('POST', PB_URL, '/api/collections/_superusers/auth-with-password', {
      body: { identity: PB_ADMIN_EMAIL, password: PB_ADMIN_PASSWORD },
    });
    token = authResult.token;
    if (!token) throw new Error('No token from auth');
    console.log('  ✓ Auth OK\n');
  } else {
    console.log('  DRY RUN — no writes will be made.\n');
  }

  let synced = 0, skipped = 0, failed = 0;
  for (let i = 0; i < barcodes.length; i++) {
    const barcode = barcodes[i];
    process.stdout.write(`  [${i + 1}/${barcodes.length}] ${barcode} ... `);
    try {
      const product = await fetchOff(barcode);
      if (!product) {
        console.log('not in OFF');
        skipped++;
        continue;
      }
      if (DRY_RUN) {
        console.log(`would sync "${product.name}" (${product.brand ?? 'no brand'})`);
        synced++;
        continue;
      }
      // Upsert into nt_barcode_cache.
      const existing = await request(
        'GET', PB_URL,
        `/api/collections/nt_barcode_cache/records?filter=barcode="${barcode}"&perPage=1`,
        { token },
      );
      const body = { ...product, source: 'openfoodfacts', fetched_at: new Date().toISOString() };
      if (existing.items && existing.items.length > 0) {
        const id = existing.items[0].id;
        await request('PATCH', PB_URL, `/api/collections/nt_barcode_cache/records/${id}`, { body, token });
        console.log(`updated "${product.name}"`);
      } else {
        await request('POST', PB_URL, '/api/collections/nt_barcode_cache/records', { body, token });
        console.log(`inserted "${product.name}"`);
      }
      synced++;
      // OFF's published rate limit guideline: 1 req/s for product queries.
      // Be polite.
      await new Promise((r) => setTimeout(r, 1100));
    } catch (e) {
      console.log(`FAIL: ${e.message.split('\n')[0]}`);
      failed++;
    }
  }

  console.log(`\n${DRY_RUN ? '[dry run] ' : ''}Synced: ${synced}, Skipped: ${skipped}, Failed: ${failed}`);
}

main().catch((e) => {
  console.error('FATAL:', e.message);
  process.exit(1);
});