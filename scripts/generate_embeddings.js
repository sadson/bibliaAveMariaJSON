/**
 * Generates int8-quantized sentence embeddings for all Bible verses
 * using all-MiniLM-L6-v2 (via @xenova/transformers, runs fully offline via ONNX).
 *
 * Outputs:
 *   ../bible_app/assets/embeddings/verses_embeddings.bin  — int8 embeddings [N * 384]
 *   ../bible_app/assets/embeddings/verse_ids.bin          — int32 verse IDs  [N]
 *   ../bible_app/assets/models/tokenizer_vocab.txt        — BERT vocabulary
 *   ../bible_app/assets/models/all_minilm_l6_v2.onnx      — ONNX model for runtime
 */

import { pipeline, env } from '@xenova/transformers';
import Database from 'better-sqlite3';
import { writeFileSync, mkdirSync, copyFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DB_PATH = resolve(__dirname, '../bible_app/assets/data/bible.db');
const EMB_DIR = resolve(__dirname, '../bible_app/assets/embeddings');
const MODEL_DIR = resolve(__dirname, '../bible_app/assets/models');

mkdirSync(EMB_DIR, { recursive: true });
mkdirSync(MODEL_DIR, { recursive: true });

// Use cached models from ~/.cache/huggingface
env.allowLocalModels = false;
env.useBrowserCache = false;

const MODEL_ID = 'Xenova/all-MiniLM-L6-v2';
const BATCH_SIZE = 64;
const DIMS = 384;

console.log('⏳ Carregando modelo ONNX (será baixado na primeira vez ~22MB)...');
const extractor = await pipeline('feature-extraction', MODEL_ID, {
  quantized: true,
});
console.log('✅ Modelo carregado!\n');

// ── Load verses from SQLite ────────────────────────────────────────────────────

const db = new Database(DB_PATH, { readonly: true });
const rows = db.prepare('SELECT id, text FROM verses ORDER BY id').all();
db.close();
console.log(`📖 ${rows.length} versículos encontrados\n`);

// ── Generate embeddings in batches ─────────────────────────────────────────────

const allIds = new Int32Array(rows.length);
const allEmbeddings = new Int8Array(rows.length * DIMS);

const startTime = Date.now();
let processed = 0;

for (let i = 0; i < rows.length; i += BATCH_SIZE) {
  const batch = rows.slice(i, i + BATCH_SIZE);
  const texts = batch.map((r) => r.text);

  const output = await extractor(texts, { pooling: 'mean', normalize: true });
  const data = output.data; // Float32Array [batchSize * DIMS]

  for (let j = 0; j < batch.length; j++) {
    allIds[i + j] = batch[j].id;

    const baseOut = j * DIMS;
    const baseDst = (i + j) * DIMS;
    for (let d = 0; d < DIMS; d++) {
      // Quantize float32 [-1, 1] → int8 [-127, 127]
      const val = data[baseOut + d];
      allEmbeddings[baseDst + d] = Math.max(
        -127,
        Math.min(127, Math.round(val * 127))
      );
    }
  }

  processed += batch.length;
  const elapsed = (Date.now() - startTime) / 1000;
  const rate = processed / elapsed;
  const remaining = (rows.length - processed) / rate;
  process.stdout.write(
    `\r  ${processed}/${rows.length} versículos | ${rate.toFixed(0)} v/s | ~${remaining.toFixed(0)}s restantes  `
  );
}

console.log('\n');

// ── Save binary files ─────────────────────────────────────────────────────────

const embPath = resolve(EMB_DIR, 'verses_embeddings.bin');
const idsPath = resolve(EMB_DIR, 'verse_ids.bin');
writeFileSync(embPath, Buffer.from(allEmbeddings.buffer));
writeFileSync(idsPath, Buffer.from(allIds.buffer));

console.log(`✅ Embeddings salvas: ${embPath}`);
console.log(`   Tamanho: ${(allEmbeddings.byteLength / 1024 / 1024).toFixed(1)} MB (int8 quantizado)`);
console.log(`✅ IDs salvos: ${idsPath}`);

// ── Copy ONNX model and vocab to Flutter assets ───────────────────────────────

// The model is cached by @xenova/transformers — check local node_modules cache first,
// then fall back to ~/.cache/huggingface/hub
const { readdirSync, readFileSync } = await import('fs');

const localCache = resolve(__dirname, 'node_modules/@xenova/transformers/.cache/Xenova/all-MiniLM-L6-v2');
const hfCacheBase = resolve(process.env.HOME || '.', '.cache/huggingface/hub/models--Xenova--all-MiniLM-L6-v2/snapshots');

let snapshotDir = null;
if (existsSync(localCache)) {
  snapshotDir = localCache;
} else if (existsSync(hfCacheBase)) {
  const snapshots = readdirSync(hfCacheBase);
  if (snapshots.length > 0) snapshotDir = resolve(hfCacheBase, snapshots[0]);
}

if (snapshotDir) {
  // Copy quantized ONNX model
  const onnxSrc = resolve(snapshotDir, 'onnx/model_quantized.onnx');
  const onnxDst = resolve(MODEL_DIR, 'all_minilm_l6_v2.onnx');
  if (existsSync(onnxSrc)) {
    copyFileSync(onnxSrc, onnxDst);
    console.log(`✅ Modelo ONNX copiado: ${onnxDst}`);
  }

  // Copy vocabulary
  const vocabTxtSrc = resolve(snapshotDir, 'vocab.txt');
  const tokenizerSrc = resolve(snapshotDir, 'tokenizer.json');
  const vocabDst = resolve(MODEL_DIR, 'tokenizer_vocab.txt');
  if (existsSync(vocabTxtSrc)) {
    copyFileSync(vocabTxtSrc, vocabDst);
    console.log(`✅ Vocabulário copiado: ${vocabDst}`);
  } else if (existsSync(tokenizerSrc)) {
    const tokenizerData = JSON.parse(readFileSync(tokenizerSrc, 'utf-8'));
    const vocab = tokenizerData.model?.vocab || {};
    const sorted = Object.entries(vocab)
      .sort((a, b) => a[1] - b[1])
      .map(([token]) => token);
    writeFileSync(vocabDst, sorted.join('\n'));
    console.log(`✅ Vocabulário extraído: ${vocabDst}`);
  }
} else {
  console.log('⚠️  Cache do modelo não encontrado. Copie manualmente:');
  console.log(`   model_quantized.onnx → ${MODEL_DIR}/all_minilm_l6_v2.onnx`);
  console.log(`   vocab.txt            → ${MODEL_DIR}/tokenizer_vocab.txt`);
}

const totalTime = ((Date.now() - startTime) / 1000).toFixed(1);
console.log(`\n⏱️  Tempo total: ${totalTime}s`);
console.log('\n🎉 Assets gerados! Execute "flutter pub get" no diretório bible_app.');
