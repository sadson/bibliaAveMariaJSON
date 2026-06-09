final class AppConstants {
  AppConstants._();

  static const dbAssetPath = 'assets/data/bible.db';
  static const embeddingsAssetPath = 'assets/embeddings/verses_embeddings.bin';
  static const verseIdsAssetPath = 'assets/embeddings/verse_ids.bin';
  static const vocabAssetPath = 'assets/models/tokenizer_vocab.txt';
  static const onnxModelAssetPath = 'assets/models/all_minilm_l6_v2.onnx';

  static const embeddingDims = 384;
  static const maxSeqLength = 128;
  static const topKResults = 20;
}
