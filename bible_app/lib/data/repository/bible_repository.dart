import '../db/database.dart';

class BibleRepository {
  BibleRepository(this._db);

  final AppDatabase _db;

  BibleDao get _bible => _db.bibleDao;
  BookmarksDao get _bookmarks => _db.bookmarksDao;

  Future<List<Book>> getBooks() => _bible.getBooks();
  Stream<List<Book>> watchBooks() => _bible.watchBooks();

  Future<List<Chapter>> getChapters(int bookId) => _bible.getChapters(bookId);
  Future<List<Verse>> getVerses(int chapterId) => _bible.getVerses(chapterId);
  Future<List<Verse>> getVersesByIds(List<int> ids) => _bible.getVersesByIds(ids);

  Future<Verse?> getVerse(int id) => _bible.getVerse(id);
  Future<Chapter?> getChapter(int id) => _bible.getChapter(id);
  Future<Book?> getBook(int id) => _bible.getBook(id);

  Future<Chapter?> findChapter(int bookId, int number) =>
      _bible.findChapter(bookId, number);

  Future<Verse?> findVerse(int chapterId, int number) =>
      _bible.findVerse(chapterId, number);

  Future<List<Verse>> searchText(String query) => _bible.searchText(query);

  Stream<List<BookmarkWithVerse>> watchBookmarks() =>
      _bookmarks.watchBookmarks();

  Future<void> addBookmark(int verseId, {String? note}) =>
      _bookmarks.addBookmark(verseId, note: note);

  Future<void> removeBookmark(int bookmarkId) =>
      _bookmarks.removeBookmark(bookmarkId);

  Future<bool> isBookmarked(int verseId) => _bookmarks.isBookmarked(verseId);
}
