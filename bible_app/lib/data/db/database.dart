import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

part 'database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get testament => text()(); // 'AT' | 'NT'
  IntColumn get order => integer()();
}

class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id)();
  IntColumn get number => integer()();
}

class Verses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chapterId => integer().references(Chapters, #id)();
  IntColumn get bookId => integer().references(Books, #id)();
  IntColumn get number => integer()();
  // Named 'text' in SQL but accessed as 'verseText' in Dart to avoid
  // conflicting with the Table.text() column builder method.
  TextColumn get verseText => text().named('text')();
}

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get verseId => integer().references(Verses, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
}

// ─── DAOs ─────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [Books, Chapters, Verses])
class BibleDao extends DatabaseAccessor<AppDatabase> with _$BibleDaoMixin {
  BibleDao(super.db);

  Stream<List<Book>> watchBooks() => select(books).watch();

  Future<List<Book>> getBooks() => select(books).get();

  Future<List<Chapter>> getChapters(int bookId) =>
      (select(chapters)..where((c) => c.bookId.equals(bookId))).get();

  Future<List<Verse>> getVerses(int chapterId) =>
      (select(verses)..where((v) => v.chapterId.equals(chapterId))).get();

  Future<List<Verse>> getVersesByIds(List<int> ids) =>
      (select(verses)..where((v) => v.id.isIn(ids))).get();

  Future<Verse?> getVerse(int verseId) =>
      (select(verses)..where((v) => v.id.equals(verseId))).getSingleOrNull();

  Future<Chapter?> getChapter(int chapterId) =>
      (select(chapters)..where((c) => c.id.equals(chapterId))).getSingleOrNull();

  Future<Book?> getBook(int bookId) =>
      (select(books)..where((b) => b.id.equals(bookId))).getSingleOrNull();

  // FTS5 full-text search using raw SQL
  Future<List<Verse>> searchText(String query) async {
    final rows = await customSelect(
      '''
      SELECT v.id, v.chapter_id, v.book_id, v.number, v.text
      FROM verses v
      JOIN verses_fts ON verses_fts.rowid = v.id
      WHERE verses_fts MATCH ?
      ORDER BY rank
      LIMIT 50
      ''',
      variables: [Variable.withString('"$query"')],
      readsFrom: {verses},
    ).get();
    return rows
        .map((r) => Verse(
              id: r.read<int>('id'),
              chapterId: r.read<int>('chapter_id'),
              bookId: r.read<int>('book_id'),
              number: r.read<int>('number'),
              verseText: r.read<String>('text'),
            ))
        .toList();
  }
}

@DriftAccessor(tables: [Bookmarks, Verses, Books, Chapters])
class BookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarksDaoMixin {
  BookmarksDao(super.db);

  Stream<List<BookmarkWithVerse>> watchBookmarks() {
    final query = select(bookmarks).join([
      innerJoin(verses, verses.id.equalsExp(bookmarks.verseId)),
      innerJoin(books, books.id.equalsExp(verses.bookId)),
      innerJoin(chapters, chapters.id.equalsExp(verses.chapterId)),
    ])
      ..orderBy([OrderingTerm.desc(bookmarks.createdAt)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => BookmarkWithVerse(
                  bookmark: r.readTable(bookmarks),
                  verse: r.readTable(verses),
                  book: r.readTable(books),
                  chapter: r.readTable(chapters),
                ),
              )
              .toList(),
        );
  }

  Future<void> addBookmark(int verseId, {String? note}) =>
      into(bookmarks).insert(BookmarksCompanion.insert(
        verseId: verseId,
        note: Value(note),
      ));

  Future<void> removeBookmark(int bookmarkId) =>
      (delete(bookmarks)..where((b) => b.id.equals(bookmarkId))).go();

  Future<bool> isBookmarked(int verseId) async {
    final result = await (select(bookmarks)
          ..where((b) => b.verseId.equals(verseId)))
        .getSingleOrNull();
    return result != null;
  }
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [Books, Chapters, Verses, Bookmarks],
  daos: [BibleDao, BookmarksDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  static Future<AppDatabase> create() async {
    final dbFile = await _copyDbAsset();
    return AppDatabase(driftDatabase(name: 'bible', native: DriftNativeOptions(databasePath: () async => dbFile.path)));
  }

  static Future<File> _copyDbAsset() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/bible.db';
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      final bytes = await rootBundle.load(AppConstants.dbAssetPath);
      await dbFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    return dbFile;
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class BookmarkWithVerse {
  final Bookmark bookmark;
  final Verse verse;
  final Book book;
  final Chapter chapter;

  const BookmarkWithVerse({
    required this.bookmark,
    required this.verse,
    required this.book,
    required this.chapter,
  });
}
