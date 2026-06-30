import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:dio/io.dart';
import 'package:rxdart/rxdart.dart';

import '../../features/dashboard/domain/food_log_entry.dart';
import '../../features/dashboard/domain/macro_nutrients.dart';

/// Abstract AI gateway — pluggable providers (OpenRouter, direct OpenAI, …).
///
/// Returns typed `FoodLogEntry` list — never raw strings into the UI.
abstract class AIGateway {
  Future<List<FoodLogEntry>> recognizeFromImage({
    required File image,
    String? hint,
  });

  /// Streaming voice → food items. Yields partial transcripts as user speaks,
  /// then final structured result when [audioStream] closes.
  Stream<VoiceLogProgress> parseFromVoice({
    required Stream<Uint8List> audioStream,
    MealSlot? forcedSlot,
  });

  Future<List<FoodLogEntry>> parseTextLog(String transcript);
}

class VoiceLogProgress {
  const VoiceLogProgress({
    this.transcript,
    this.items,
    this.isFinal = false,
    this.error,
  });

  final String? transcript;
  final List<FoodLogEntry>? items;
  final bool isFinal;
  final Object? error;
}

/// OpenRouter-based AI gateway. Multi-modal:
///   • Image → MiniMax M3 (primary) → Gemini Flash / GPT-4o-mini fallback
///   • Voice → Whisper transcription → M3 text parsing
class OpenRouterAIGateway implements AIGateway {
  OpenRouterAIGateway({
    required this.apiKey,
    required this.primaryModel,
    required this.fallbackModels,
    Dio? dio,
  }) : _dio = dio ?? _buildDio(apiKey);

  final String apiKey;
  final String primaryModel;
  final List<String> fallbackModels;
  final Dio _dio;

  static Dio _buildDio(String apiKey) {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://openrouter.ai/api/v1',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://nutritrack.app',
        'X-Title': 'NutriTrack',
      },
    ));
    // Compression: enable gzip/brotli on requests too
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.autoUncompress = true;
      return client;
    };
    return dio;
  }

  // ── Vision ────────────────────────────────────────────────────
  @override
  Future<List<FoodLogEntry>> recognizeFromImage({
    required File image,
    String? hint,
  }) async {
    // Resize + compress aggressively — target ~600KB JPEG.
    final compressed = await _compressImage(image);
    final base64 = base64Encode(compressed);
    final prompt = hint != null ? '${_visionPrompt}\n\nExtra hint: $hint' : _visionPrompt;

    final models = [primaryModel, ...fallbackModels];
    Object? lastErr;
    for (final model in models) {
      try {
        final res = await _dio.post('/chat/completions', data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': _visionSystemPrompt},
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64'},
                },
                {'type': 'text', 'text': prompt},
              ],
            },
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.1,
          'max_tokens': 1500,
        });

        final content = res.data['choices']?[0]?['message']?['content'];
        if (content is String) {
          final entries = _parseVisionResponse(content);
          if (entries.isNotEmpty) return entries;
        }
      } catch (e) {
        lastErr = e;
        // Try next model.
      }
    }
    throw AIException(_friendlyError(lastErr ?? 'Unknown error'));
  }

  /// Map technical exceptions to messages a non-technical user can act on.
  static String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Connection')) {
      return 'No internet connection — your entries are saved and will sync later.';
    }
    if (s.contains('TimeoutException') || s.contains('Timeout')) {
      return 'Network is slow — try again or use Snap or Search instead.';
    }
    if (s.contains('401') || s.contains('403')) {
      return 'AI service temporarily unavailable. Try again in a moment.';
    }
    if (s.contains('429')) {
      return 'Too many requests — wait a few seconds and try again.';
    }
    return 'Something went wrong. Your entry is still saved locally.';
  }

  // ── Voice (Whisper streaming) ─────────────────────────────────
  @override
  Stream<VoiceLogProgress> parseFromVoice({
    required Stream<Uint8List> audioStream,
    MealSlot? forcedSlot,
  }) {
    // Buffer the stream into one complete file, then submit to Whisper,
    // then parse the transcript through the same JSON pipeline.
    return Stream.fromFuture(
      audioStream
          .scan<Uint8List>(
            (acc, chunk, _) => acc..addAll(chunk),
            Uint8List(0),
          )
          .last,
    ).asyncExpand((bytes) async* {
      if (bytes.isEmpty) {
        yield const VoiceLogProgress(isFinal: true);
        return;
      }
      yield const VoiceLogProgress(transcript: 'Transcribing…');
      try {
        final transcript = await _transcribe(bytes);
        if (transcript.isEmpty) {
          yield const VoiceLogProgress(
            isFinal: true,
            error: 'No speech detected — try again in a quieter spot.',
          );
          return;
        }
        yield VoiceLogProgress(transcript: transcript);
        final entries = await parseTextLog(transcript, forcedSlot: forcedSlot);
        yield VoiceLogProgress(
          transcript: transcript,
          items: entries,
          isFinal: entries.isNotEmpty,
          error: entries.isEmpty
              ? 'Could not parse any food items from that.'
              : null,
        );
      } catch (e) {
        yield VoiceLogProgress(
          isFinal: true,
          error: 'Voice recognition failed: ${_friendlyError(e)}',
        );
      }
    }).asBroadcastStream();
  }

  @override
  Future<List<FoodLogEntry>> parseTextLog(
    String transcript, {
    MealSlot? forcedSlot,
  }) async {
    if (transcript.trim().isEmpty) return [];
    final models = [primaryModel, ...fallbackModels];
    Object? lastErr;
    for (final model in models) {
      try {
        final res = await _dio.post('/chat/completions', data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': _parseTextSystemPrompt},
            {'role': 'user', 'content': transcript},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.2,
          'max_tokens': 1500,
        });
        final content = res.data['choices']?[0]?['message']?['content'];
        if (content is String) {
          final entries = _parseVisionResponse(content); // same JSON shape
          if (entries.isNotEmpty) {
            return forcedSlot == null
                ? entries
                : entries.map((e) => e.copyWith(slot: forcedSlot)).toList();
          }
        }
      } catch (e) {
        lastErr = e;
      }
    }
    throw AIException(_friendlyError(lastErr ?? 'Unknown error'));
  }

  // ── Whisper transcription ─────────────────────────────────────
  Future<String> _transcribe(Uint8List wavBytes) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          wavBytes,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
        ),
        'model': 'openai/whisper-large-v3',
        'language': 'en',
      });
      final res = await _dio.post(
        '/audio/transcriptions',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return (res.data['text'] as String?)?.trim() ?? '';
    } catch (e) {
      return '';
    }
  }

  // ── Parsing helpers ───────────────────────────────────────────
  List<FoodLogEntry> _parseVisionResponse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final items = (json['items'] as List? ?? []).cast<Map<String, dynamic>>();
      final now = DateTime.now();
      return items.map((j) {
        final grams = (j['portion_grams'] as num?)?.toDouble() ?? 100;
        final conf = (j['confidence'] as num?)?.toDouble() ?? 0.5;
        final name = (j['name'] as String? ?? 'Unknown').toLowerCase();
        final nut = LocalNutritionDB.lookup(name);
        final ratio = grams / 100;
        return FoodLogEntry(
          id: '${now.microsecondsSinceEpoch}_${name.hashCode}',
          name: name,
          grams: grams,
          macros: MacroNutrients(
            protein: nut.protein * ratio,
            carbs: nut.carbs * ratio,
            fat: nut.fat * ratio,
            fiber: nut.fiber * ratio,
            sugar: nut.sugar * ratio,
            sodium: nut.sodium * ratio,
          ),
          loggedAt: now,
          slot: _inferSlot(now),
          source: LogSource.cameraAI,
          confidence: conf,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  MealSlot _inferSlot(DateTime t) {
    final h = t.hour;
    if (h < 11) return MealSlot.breakfast;
    if (h < 15) return MealSlot.lunch;
    if (h < 21) return MealSlot.dinner;
    return MealSlot.snack;
  }

  Future<Uint8List> _compressImage(File input) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    // Downscale longest side to 1024px.
    final resized = decoded.width > decoded.height
        ? img.copyResize(decoded, width: 1024)
        : img.copyResize(decoded, height: 1024);

    return Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  }

  // ── Prompts ───────────────────────────────────────────────────
  static const _visionSystemPrompt = '''
You are a precision nutrition recognition AI. Analyze meal photos and return structured JSON.
''';

  static const _visionPrompt = '''
Identify every distinct food item in this image. Return this exact JSON shape:

{
  "items": [
    {
      "name": "generic food name in English (lowercase)",
      "portion_grams": number,
      "confidence": 0.0-1.0,
      "category": "protein|carb|vegetable|fruit|fat|dairy|beverage|other",
      "visual_cues": "brief description"
    }
  ],
  "scene": "home|restaurant|packaged|unclear",
  "notes": "uncertainty or assumptions"
}

Rules:
- Identify EACH distinct item separately
- Estimate portions conservatively (slight under-call better than over)
- confidence reflects identification AND portion certainty
- If image is unclear or not food: items: []
''';

  static const _parseTextSystemPrompt = '''
Extract every food item the user mentions. Convert quantities to grams.

Examples:
- "two scrambled eggs" → eggs, 100g
- "a bowl of rice" → rice, 150g
- "half an avocado" → avocado, 70g
- "a glass of milk" → milk, 240g
- "a chicken breast" → chicken breast, 150g

Return JSON in the same shape as vision mode. If meal slot is mentioned, include it; else "auto".
''';
}

class AIException implements Exception {
  AIException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Local nutrition lookup — same shape as OpenRouter service's USDA DB.
/// Kept minimal here; full DB lives in [LocalNutritionDB] in core.
class LocalNutritionDB {
  LocalNutritionDB._();

  static _N lookup(String name) {
    final key = name.toLowerCase().trim();
    final hit = _data[key];
    if (hit != null) return hit;
    for (final e in _data.entries) {
      if (key.contains(e.key)) return e.value;
    }
    return _N(0, 0, 0);
  }

  static const _data = <String, _N>{
    'rice': _N(2.7, 28, 0.3),
    'white rice': _N(2.7, 28, 0.3),
    'chicken breast': _N(31, 0, 3.6),
    'chicken': _N(25, 0, 8),
    'egg': _N(13, 1.1, 11),
    'eggs': _N(13, 1.1, 11),
    'salmon': _N(20, 0, 13),
    'broccoli': _N(2.8, 7, 0.4),
    'avocado': _N(2, 9, 15),
    'bread': _N(9, 49, 3.2),
    'toast': _N(9, 55, 6),
    'milk': _N(3.4, 5, 1),
    'banana': _N(1.1, 23, 0.3),
    'apple': _N(0.3, 14, 0.2),
    'oatmeal': _N(2.4, 12, 1.4),
    'yogurt': _N(10, 3.6, 0.4),
    'cheese': _N(25, 1.3, 33),
    'noodles': _N(4.5, 25, 2.1),
    'pasta': _N(5, 25, 1.1),
    'salad': _N(3, 8, 2),
    'potato': _N(2, 17, 0.1),
    'sweet potato': _N(1.6, 20, 0.1),
    'beef': _N(26, 0, 18),
    'pork': _N(27, 0, 14),
    'tofu': _N(8, 1.9, 4.8),
    'coffee': _N(0.3, 0, 0),
    'orange juice': _N(0.7, 10, 0.2),
    'tea': _N(0, 0.3, 0),
  };
}

class _N {
  const _N(this.protein, this.carbs, this.fat);
  final double protein;
  final double carbs;
  final double fat;
  final double fiber = 0;
  final double sugar = 0;
  final double sodium = 0;
}