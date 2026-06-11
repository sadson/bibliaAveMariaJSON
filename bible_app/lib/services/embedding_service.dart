import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../core/constants.dart';
import 'tokenizer.dart';

/// Result of a semantic search — verse DB id + cosine similarity score.
class SemanticResult {
  const SemanticResult({required this.verseId, required this.score});
  final int verseId;
  final double score;
}

/// Loads pre-computed int8 verse embeddings and runs cosine-similarity search.
/// Query embeddings are generated on-device via ONNX (all-MiniLM-L6-v2).
class EmbeddingService {
  EmbeddingService._({
    required Float32List embeddings,
    required Int32List verseIds,
    required OrtSession session,
    required BertTokenizer tokenizer,
  })  : _embeddings = embeddings,
        _verseIds = verseIds,
        _session = session,
        _tokenizer = tokenizer;

  final Float32List _embeddings; // [N * D] row-major, normalised float32
  final Int32List _verseIds;    // [N] verse DB ids
  final OrtSession _session;
  final BertTokenizer _tokenizer;

  static EmbeddingService? _instance;

  static Future<EmbeddingService> load() async {
    if (_instance != null) return _instance!;

    final results = await Future.wait([
      rootBundle.load(AppConstants.embeddingsAssetPath),
      rootBundle.load(AppConstants.verseIdsAssetPath),
      rootBundle.load(AppConstants.onnxModelAssetPath),
      BertTokenizer.load(),
    ]);

    final embeddingBytes = (results[0] as ByteData).buffer.asUint8List();
    final verseIdBytes = (results[1] as ByteData).buffer.asUint8List();
    final modelBytes = (results[2] as ByteData).buffer.asUint8List();
    final tokenizer = results[3] as BertTokenizer;

    // Embeddings are stored as int8, dequantize to float32
    final int8View = Int8List.view(
      embeddingBytes.buffer,
      embeddingBytes.offsetInBytes,
      embeddingBytes.lengthInBytes,
    );
    final float32Embeddings =
        Float32List.fromList(int8View.map((v) => v / 127.0).toList());

    final verseIds = Int32List.view(
      verseIdBytes.buffer,
      verseIdBytes.offsetInBytes,
      verseIdBytes.lengthInBytes ~/ 4,
    );

    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    final session =
        OrtSession.fromBuffer(modelBytes, sessionOptions);

    _instance = EmbeddingService._(
      embeddings: float32Embeddings,
      verseIds: verseIds,
      session: session,
      tokenizer: tokenizer,
    );
    return _instance!;
  }

  /// Embed the query on-device using ONNX, then search the verse corpus.
  Future<List<SemanticResult>> search(String query,
      {int topK = AppConstants.topKResults}) async {
    final queryEmbedding = await _embedQuery(query);
    return _cosineSimilaritySearch(
      queryEmbedding,
      _embeddings,
      _verseIds,
      topK,
      AppConstants.embeddingDims,
    );
  }

  Future<Float32List> _embedQuery(String text) async {
    final encoded = _tokenizer.encode(text);
    final seqLen = AppConstants.maxSeqLength;

    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(encoded.inputIds.map((e) => e.toInt()).toList()),
      [1, seqLen],
    );
    final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(
          encoded.attentionMask.map((e) => e.toInt()).toList()),
      [1, seqLen],
    );
    final tokenTypeIdsTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(
          encoded.tokenTypeIds.map((e) => e.toInt()).toList()),
      [1, seqLen],
    );

    final inputs = {
      'input_ids': inputIdsTensor,
      'attention_mask': attentionMaskTensor,
      'token_type_ids': tokenTypeIdsTensor,
    };

    final runOptions = OrtRunOptions();
    final outputs = await _session.runAsync(runOptions, inputs);

    // outputs[0] = last_hidden_state [1, seqLen, 384]
    final hiddenState =
        (outputs![0]?.value as List)[0] as List; // [seqLen, 384]

    // Mean pooling over non-padding tokens
    final attMask = encoded.attentionMask;
    final dims = AppConstants.embeddingDims;
    final pooled = Float32List(dims);
    int count = 0;
    for (int i = 0; i < seqLen; i++) {
      if (attMask[i] == 0) break;
      count++;
      final row = hiddenState[i] as List;
      for (int d = 0; d < dims; d++) {
        pooled[d] += (row[d] as num).toDouble();
      }
    }
    for (int d = 0; d < dims; d++) {
      pooled[d] /= count;
    }

    // L2 normalise
    return _l2Normalize(pooled);
  }

  static Float32List _l2Normalize(Float32List v) {
    double norm = 0;
    for (final x in v) { norm += x * x; }
    norm = math.sqrt(norm);
    if (norm == 0) return v;
    return Float32List.fromList(v.map((x) => x / norm).toList());
  }

  static List<SemanticResult> _cosineSimilaritySearch(
    Float32List query,
    Float32List corpus,
    Int32List ids,
    int topK,
    int dims,
  ) {
    final n = ids.length;
    // Min-heap of size topK: (score, index)
    final heap = <(double, int)>[];

    for (int i = 0; i < n; i++) {
      double dot = 0;
      final base = i * dims;
      for (int d = 0; d < dims; d++) {
        dot += query[d] * corpus[base + d];
      }
      if (heap.length < topK) {
        heap.add((dot, i));
        heap.sort((a, b) => a.$1.compareTo(b.$1));
      } else if (dot > heap.first.$1) {
        heap[0] = (dot, i);
        heap.sort((a, b) => a.$1.compareTo(b.$1));
      }
    }

    return heap.reversed
        .map((e) => SemanticResult(verseId: ids[e.$2], score: e.$1))
        .toList();
  }
}
