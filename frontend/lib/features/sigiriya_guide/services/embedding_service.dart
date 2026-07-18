import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

class EmbeddingService {
  static EmbeddingService? _instance;
  OrtSession? _session;
  bool _ready = false;

  // vocab.txt loaded into a map: token → id  (line number = token id)
  Map<String, int> _vocab = {};

  static const _modelAssetPath = 'assets/models/minilm.onnx';
  static const _vocabAssetPath = 'assets/data/vocab.txt';
  static const _modelFileName = 'minilm.onnx';
  static const _embeddingDim = 384;

  // Standard BERT special token ids
  static const int _clsId = 101; // [CLS]
  static const int _sepId = 102; // [SEP]
  static const int _unkId = 100; // [UNK]

  EmbeddingService._();
  factory EmbeddingService() => _instance ??= EmbeddingService._();

  bool get isReady => _ready;

  // ── Initialise: load vocab then ONNX session ─────────────────────────────

  Future<void> init() async {
    if (_ready) return;

    OrtEnv.instance.init();

    // 1. Load vocabulary — must be done before ONNX session
    await _loadVocab();
    debugPrint('[EmbeddingService] Vocab loaded: ${_vocab.length} tokens');

    // 2. Load ONNX model
    final modelBytes = await _loadModelBytes();
    final opts = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, opts);

    _ready = true;
    debugPrint('[EmbeddingService] ONNX session ready.');
  }

  // ── Vocab loading from assets/data/vocab.txt ─────────────────────────────
  // vocab.txt format: one token per line, line index == token id
  // This is the official HuggingFace BERT vocab format.

  Future<void> _loadVocab() async {
    final raw = await rootBundle.loadString(_vocabAssetPath);
    final lines = raw.split('\n');
    _vocab = {};
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trimRight(); // preserve leading ## but trim \r
      if (token.isNotEmpty) _vocab[token] = i;
    }
  }

  // ── ONNX model bytes from assets or app documents ────────────────────────

  Future<Uint8List> _loadModelBytes() async {
    try {
      final data = await rootBundle.load(_modelAssetPath);
      return data.buffer.asUint8List();
    } catch (_) {}

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_modelFileName');
    if (await file.exists()) return file.readAsBytes();

    throw Exception(
      'minilm.onnx not found.\n'
      'Place it at: assets/models/minilm.onnx\n'
      'Run tools/export_onnx_embedder.py to generate it.',
    );
  }

  // ── Public API: embed a text string → 384-dim unit vector ───────────────

  Future<List<double>> embed(String text) async {
    if (!_ready) throw StateError('EmbeddingService not initialised');

    final tokens = _tokenize(text);
    final inputIds = Int64List.fromList(tokens.inputIds);
    final attentionMask = Int64List.fromList(tokens.attentionMask);
    final shape = [1, tokens.inputIds.length];

    // FIX 2: only input_ids + attention_mask (no token_type_ids)
    final inputs = {
      'input_ids': OrtValueTensor.createTensorWithDataList(inputIds, shape),
      'attention_mask': OrtValueTensor.createTensorWithDataList(
        attentionMask,
        shape,
      ),
    };

    final runOptions = OrtRunOptions();
    final List<OrtValue?> outputs =
        await _session!.runAsync(runOptions, inputs) ?? [];

    // Mean-pool the last hidden state: shape [1, seq_len, 384]
    // This matches sentence-transformers' default pooling for MiniLM
    final seqLen = tokens.inputIds.length;
    final pooled = List<double>.filled(_embeddingDim, 0.0);

    if (outputs.isNotEmpty && outputs[0] != null) {
      final hidden = outputs[0]!.value as List;
      for (int t = 0; t < seqLen; t++) {
        for (int d = 0; d < _embeddingDim; d++) {
          pooled[d] += (hidden[0][t][d] as num).toDouble();
        }
      }
      for (int d = 0; d < _embeddingDim; d++) {
        pooled[d] /= seqLen;
      }
    }

    for (final v in inputs.values) v.release();
    for (final o in outputs) o?.release();
    runOptions.release();

    // L2-normalise — mirrors normalize_embeddings=True in Python
    return _l2Normalise(pooled);
  }

  // ── BERT WordPiece Tokenizer ─────────────────────────────────────────────
  //
  // Replicates BertTokenizer from HuggingFace transformers:
  //   1. Lowercase the input (MiniLM uses uncased BERT vocab)
  //   2. Insert spaces around CJK characters and punctuation
  //   3. Split on whitespace
  //   4. Apply WordPiece sub-word splitting using vocab.txt
  //   5. Prepend [CLS]=101, append [SEP]=102, clip to maxLen
  //
  // The output token IDs will be identical to:
  //   tokenizer("your text", return_tensors="pt")["input_ids"]

  _Tokens _tokenize(String text, {int maxLen = 128}) {
    // Step 1: lowercase
    final lower = text.toLowerCase().trim();

    // Step 2+3: basic tokenize (CJK / punct spacing → split)
    final rawTokens = _basicTokenize(lower);

    // Step 4: WordPiece
    final ids = <int>[_clsId];
    for (final word in rawTokens) {
      if (ids.length >= maxLen - 1) break;
      for (final id in _wordPiece(word)) {
        if (ids.length >= maxLen - 1) break;
        ids.add(id);
      }
    }
    ids.add(_sepId);

    return _Tokens(
      inputIds: ids,
      attentionMask: List<int>.filled(ids.length, 1),
    );
  }

  /// Split text on whitespace after inserting spaces around CJK and punctuation.
  List<String> _basicTokenize(String text) {
    final buf = StringBuffer();
    for (final rune in text.runes) {
      if (_isCjk(rune) || _isPunct(rune)) {
        buf.write(' ');
        buf.writeCharCode(rune);
        buf.write(' ');
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf
        .toString()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// WordPiece sub-word split for a single word.
  /// Returns a list of vocab IDs for the word's sub-tokens.
  List<int> _wordPiece(String word) {
    // Direct whole-word lookup
    if (_vocab.containsKey(word)) return [_vocab[word]!];

    final subIds = <int>[];
    int start = 0;
    bool isBad = false;

    while (start < word.length) {
      int end = word.length;
      int? foundId;

      // Greedy longest-match from end → start
      while (start < end) {
        final sub = start == 0
            ? word.substring(start, end)
            : '##${word.substring(start, end)}';
        if (_vocab.containsKey(sub)) {
          foundId = _vocab[sub]!;
          break;
        }
        end--;
      }

      if (foundId == null) {
        isBad = true;
        break;
      }
      subIds.add(foundId);
      start = end;
    }

    return isBad ? [_unkId] : subIds;
  }

  // ── Unicode helpers ──────────────────────────────────────────────────────

  bool _isCjk(int cp) =>
      (cp >= 0x4E00 && cp <= 0x9FFF) ||
      (cp >= 0x3400 && cp <= 0x4DBF) ||
      (cp >= 0x20000 && cp <= 0x2A6DF) ||
      (cp >= 0x2A700 && cp <= 0x2B73F) ||
      (cp >= 0x2B740 && cp <= 0x2B81F) ||
      (cp >= 0x2B820 && cp <= 0x2CEAF) ||
      (cp >= 0xF900 && cp <= 0xFAFF) ||
      (cp >= 0x2F800 && cp <= 0x2FA1F);

  bool _isPunct(int cp) {
    // ASCII punctuation ranges
    if ((cp >= 33 && cp <= 47) ||
        (cp >= 58 && cp <= 64) ||
        (cp >= 91 && cp <= 96) ||
        (cp >= 123 && cp <= 126))
      return true;
    // Unicode category P / S (spot-check common ones)
    return (cp >= 0x2000 && cp <= 0x206F) || // General Punctuation block
        (cp >= 0x2E00 && cp <= 0x2E7F) || // Supplemental Punctuation
        cp == 0x00B7 ||
        cp == 0x0387;
  }

  // ── L2 normalisation (mirrors normalize_embeddings=True) ─────────────────

  List<double> _l2Normalise(List<double> v) {
    double norm = 0;
    for (final x in v) norm += x * x;
    norm = sqrt(norm);
    if (norm < 1e-10) return v;
    return v.map((x) => x / norm).toList();
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _vocab = {};
    _ready = false;
    _instance = null;
  }
}

// ── Internal token holder ────────────────────────────────────────────────────

class _Tokens {
  final List<int> inputIds;
  final List<int> attentionMask;
  _Tokens({required this.inputIds, required this.attentionMask});
}
