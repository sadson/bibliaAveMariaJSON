/**
 * Generates bible.db (SQLite) from bibliaAveMaria.json.
 * Includes FTS5 virtual table for full-text search.
 *
 * Output: ../bible_app/assets/data/bible.db
 */

import Database from 'better-sqlite3';
import { readFileSync, mkdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const JSON_PATH = resolve(__dirname, '../bibliaAveMaria.json');
const DB_PATH = resolve(__dirname, '../bible_app/assets/data/bible.db');

mkdirSync(resolve(__dirname, '../bible_app/assets/data'), { recursive: true });

console.log('📖 Lendo JSON da Bíblia...');
const bible = JSON.parse(readFileSync(JSON_PATH, 'utf-8'));

const db = new Database(DB_PATH);

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// ── Schema ──────────────────────────────────────────────────────────────────

db.exec(`
  CREATE TABLE IF NOT EXISTS books (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    name     TEXT    NOT NULL,
    testament TEXT   NOT NULL CHECK(testament IN ('AT','NT')),
    "order"  INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS chapters (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id INTEGER NOT NULL REFERENCES books(id),
    number  INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS verses (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    chapter_id INTEGER NOT NULL REFERENCES chapters(id),
    book_id    INTEGER NOT NULL REFERENCES books(id),
    number     INTEGER NOT NULL,
    text       TEXT    NOT NULL
  );

  CREATE TABLE IF NOT EXISTS bookmarks (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    verse_id   INTEGER NOT NULL REFERENCES verses(id),
    created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    note       TEXT
  );

  CREATE INDEX IF NOT EXISTS idx_chapters_book   ON chapters(book_id);
  CREATE INDEX IF NOT EXISTS idx_verses_chapter  ON verses(chapter_id);
  CREATE INDEX IF NOT EXISTS idx_verses_book     ON verses(book_id);

  -- FTS5 for full-text search
  CREATE VIRTUAL TABLE IF NOT EXISTS verses_fts
    USING fts5(text, content=verses, content_rowid=id, tokenize='unicode61');
`);

// ── Insert ───────────────────────────────────────────────────────────────────

const insertBook = db.prepare(
  'INSERT INTO books (name, testament, "order") VALUES (?, ?, ?)'
);
const insertChapter = db.prepare(
  'INSERT INTO chapters (book_id, number) VALUES (?, ?)'
);
const insertVerse = db.prepare(
  'INSERT INTO verses (chapter_id, book_id, number, text) VALUES (?, ?, ?, ?)'
);

let bookOrder = 0;
let totalVerses = 0;

const insertAll = db.transaction((testament, books) => {
  for (const book of books) {
    bookOrder++;
    const { lastInsertRowid: bookId } = insertBook.run(
      book.nome,
      testament,
      bookOrder
    );

    for (const cap of book.capitulos) {
      const { lastInsertRowid: chapterId } = insertChapter.run(
        bookId,
        cap.capitulo
      );
      for (const v of cap.versiculos) {
        insertVerse.run(chapterId, bookId, v.versiculo, v.texto);
        totalVerses++;
      }
    }
  }
});

console.log('📚 Inserindo Antigo Testamento...');
insertAll('AT', bible.antigoTestamento);
console.log('✝️  Inserindo Novo Testamento...');
insertAll('NT', bible.novoTestamento);

// ── FTS5 populate ────────────────────────────────────────────────────────────

console.log('🔍 Indexando FTS5...');
db.exec(`INSERT INTO verses_fts(rowid, text) SELECT id, text FROM verses;`);

// ── Stats ────────────────────────────────────────────────────────────────────

const stats = db
  .prepare(
    `SELECT
      (SELECT COUNT(*) FROM books) AS books,
      (SELECT COUNT(*) FROM chapters) AS chapters,
      (SELECT COUNT(*) FROM verses) AS verses`
  )
  .get();

console.log(`\n✅ Banco gerado: ${DB_PATH}`);
console.log(
  `   ${stats.books} livros | ${stats.chapters} capítulos | ${stats.verses} versículos`
);

db.close();
