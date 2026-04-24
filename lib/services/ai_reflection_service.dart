import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../data/models/value_model.dart';
import '../providers/settings_provider.dart';
import '../shared/utils/currency.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

sealed class AiReflectionResult {
  const AiReflectionResult();
}

class AiReflectionSuccess extends AiReflectionResult {
  const AiReflectionSuccess(this.text);
  final String text;
}

class AiReflectionError extends AiReflectionResult {
  const AiReflectionError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class AiReflectionService {
  AiReflectionService(String apiKey)
    : _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
      );

  final GenerativeModel _model;

  static const _systemPrompt = '''
You are Debbie, a warm and mindful money companion. You help people connect their spending to their personal values. You never use the words "budget", "restrict", "limit", "overspend", "warning", or "alert". Instead you speak of values plans, energy, alignment, intention, and purpose.

Your tone is encouraging, gentle, and reflective — like a thoughtful friend having tea. Keep responses concise (2-4 sentences). End with a reflective question or gentle encouragement. Use Indonesian Rupiah (Rp) when mentioning amounts.
''';

  Future<AiReflectionResult> generateWeeklyReflection({
    required Map<String, int> spendingByValue,
    required List<ValueModel> values,
    required String topValueName,
    required int topValueAmount,
  }) async {
    try {
      final valueMap = {for (final v in values) v.id: v};
      final spendingLines = spendingByValue.entries
          .map((e) {
            final name = valueMap[e.key]?.name ?? 'Unknown';
            return '- $name: ${CurrencyUtils.format(e.value)}';
          })
          .join('\n');

      final prompt =
          '''
This week's spending aligned to values:
$spendingLines

The top value was "$topValueName" with ${CurrencyUtils.format(topValueAmount)}.

Reflect on this person's week — what does this spending pattern say about where their energy is flowing? Offer a warm, personalized reflection.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        return const AiReflectionError(
          'Could not generate a reflection right now. Please try again later.',
        );
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError(
        'Could not connect to the AI service. Please check your internet connection and try again.',
      );
    }
  }

  Future<AiReflectionResult> generateJournalInsight({
    required String journalContent,
    required String? mood,
    required Map<String, int> spendingByValue,
    required List<ValueModel> values,
  }) async {
    try {
      final valueMap = {for (final v in values) v.id: v};
      final spendingLines = spendingByValue.entries
          .map((e) {
            final name = valueMap[e.key]?.name ?? 'Unknown';
            return '- $name: ${CurrencyUtils.format(e.value)}';
          })
          .join('\n');

      final moodLine = mood != null ? 'Their current mood: $mood.' : '';

      final prompt =
          '''
Someone just wrote this journal reflection:
"$journalContent"

$moodLine

Their recent spending aligned to values:
$spendingLines

Offer a warm, thoughtful response to their reflection. Connect their feelings to how their energy is flowing through their values. Be gentle and encouraging.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        return const AiReflectionError(
          'Could not generate an insight right now. Please try again later.',
        );
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError(
        'Could not connect to the AI service. Please check your internet connection and try again.',
      );
    }
  }

  /// Suggests which value a transaction item belongs to based on description.
  /// Returns the value name (e.g., "Joy", "Health") or null.
  Future<AiReflectionResult> suggestValue({
    required String description,
    required List<ValueModel> values,
  }) async {
    try {
      final valueNames = values.map((v) => v.name).join(', ');

      final prompt =
          '''
The user has these life values: $valueNames.

They just made a transaction: "$description"

Which ONE value does this transaction best align with? Reply with ONLY the value name, nothing else. If you're not sure, pick the closest match.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return const AiReflectionError('Could not suggest a value.');
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError('Could not connect to AI service.');
    }
  }

  /// Analyzes transaction reflections (notes) grouped by value and finds
  /// emotional patterns, themes, and insights.
  Future<AiReflectionResult> analyzeTransactionReflections({
    required Map<String, List<String>> reflectionsByValue,
    required int totalTransactions,
    required int reflectedCount,
  }) async {
    try {
      final lines = reflectionsByValue.entries
          .map((e) {
            final notes = e.value.map((n) => '  - "$n"').join('\n');
            return '${e.key} (${e.value.length} reflections):\n$notes';
          })
          .join('\n\n');

      final prompt =
          '''
Analyze these personal reflections that someone wrote about their spending, grouped by life value.

$lines

Stats: $reflectedCount out of $totalTransactions transactions have reflections.

Look for:
1. Emotional patterns per value (which values bring joy vs anxiety?)
2. Any contradictions or tensions between what they say vs how they spend
3. One insight they might not see themselves

Write a warm, personal analysis (4-6 sentences). Don't list bullet points — write it like a thoughtful friend sharing an observation. End with one question that helps them go deeper.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return const AiReflectionError('Could not analyze reflections.');
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError('Could not connect to AI service.');
    }
  }

  /// Scans a receipt image and extracts transaction items.
  /// Returns a JSON string with items array.
  Future<AiReflectionResult> scanReceipt({
    required Uint8List imageBytes,
    required List<ValueModel> values,
  }) async {
    try {
      final valueNames = values.map((v) => v.name).join(', ');

      final prompt =
          '''
Look at this receipt image and extract each item purchased.

The user has these life values: $valueNames.

Return a valid JSON object with this exact structure:
{
  "items": [
    {
      "description": "item name",
      "amount": 25000,
      "value": "closest value name"
    }
  ],
  "date": "YYYY-MM-DD or null if not visible"
}

Rules:
- "amount" must be an integer in Indonesian Rupiah (no decimals)
- "value" must be one of: $valueNames
- If you can't read an amount, estimate based on the item
- Extract ALL visible items
- Return ONLY valid JSON, no other text
''';

      final response = await _model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return const AiReflectionError('Could not read the receipt.');
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError(
        'Could not process the receipt. Please try again.',
      );
    }
  }

  /// Generates a personalized daily journal prompt based on spending and mood.
  Future<AiReflectionResult> generateDailyPrompt({
    required Map<String, int> spendingByValue,
    required List<ValueModel> values,
    required List<String> recentMoods,
    required int todayExpense,
    required int todayIncome,
  }) async {
    try {
      final valueMap = {for (final v in values) v.id: v};
      final spendingLines = spendingByValue.entries
          .map((e) {
            final name = valueMap[e.key]?.name ?? 'Unknown';
            return '- $name: ${CurrencyUtils.format(e.value)}';
          })
          .join('\n');

      final moodLine = recentMoods.isNotEmpty
          ? 'Recent moods: ${recentMoods.join(', ')}.'
          : 'No mood entries recorded recently.';

      final todayLine = todayExpense > 0 || todayIncome > 0
          ? 'Today: spent ${CurrencyUtils.format(todayExpense)}, earned ${CurrencyUtils.format(todayIncome)}.'
          : 'No transactions recorded today yet.';

      final prompt =
          '''
Generate ONE personalized, thoughtful journal prompt for this person to reflect on.

$moodLine
$todayLine

This month's spending by value:
$spendingLines

The prompt should be a single question (1-2 sentences) that connects their spending patterns to their inner life. Make it feel personal and specific to their data — not generic. Don't mention exact numbers, just reference patterns.

Reply with ONLY the prompt question, nothing else.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return const AiReflectionError('Could not generate a prompt.');
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError('Could not connect to AI service.');
    }
  }

  /// Generates a weekly spending + mood digest.
  Future<AiReflectionResult> generateWeeklyDigest({
    required Map<String, int> spendingByValue,
    required List<ValueModel> values,
    required int totalExpense,
    required int totalIncome,
    required int transactionCount,
    required List<String> moods,
    required int journalCount,
  }) async {
    try {
      final valueMap = {for (final v in values) v.id: v};
      final spendingLines = spendingByValue.entries
          .map((e) {
            final name = valueMap[e.key]?.name ?? 'Unknown';
            return '- $name: ${CurrencyUtils.format(e.value)}';
          })
          .join('\n');

      final moodSummary = moods.isNotEmpty
          ? 'Moods this week: ${moods.join(', ')}.'
          : 'No mood entries this week.';

      final prompt =
          '''
Write a brief, warm weekly reflection digest (3-5 sentences) for this person.

$moodSummary
Journal entries written: $journalCount.
Total transactions: $transactionCount.
Income: ${CurrencyUtils.format(totalIncome)}, Expenses: ${CurrencyUtils.format(totalExpense)}.

Spending by value:
$spendingLines

Summarize their week's relationship with money. Note patterns between mood and spending if visible. End with one gentle observation or encouragement. Keep it personal and warm.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return const AiReflectionError('Could not generate digest.');
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError('Could not connect to AI service.');
    }
  }

  /// Generates one combined weekly insight from spending notes and a
  /// weekly check-in.
  Future<AiReflectionResult> generateWeeklyNarrative({
    required Map<String, int> spendingByValue,
    required List<ValueModel> values,
    required List<String> transactionNotes,
    required String? weeklyCheckInContent,
    required String? mood,
  }) async {
    try {
      final valueMap = {for (final v in values) v.id: v};
      final spendingLines = spendingByValue.isEmpty
          ? '- No value-linked spending was recorded this week.'
          : spendingByValue.entries
                .map((e) {
                  final name = valueMap[e.key]?.name ?? 'Unknown';
                  return '- $name: ${CurrencyUtils.format(e.value)}';
                })
                .join('\n');

      final noteLines = transactionNotes.isEmpty
          ? '- No spending notes were written this week.'
          : transactionNotes.take(6).map((note) => '- "$note"').join('\n');

      final checkInLine = weeklyCheckInContent?.trim().isNotEmpty == true
          ? 'Weekly check-in:\n"${weeklyCheckInContent!.trim()}"'
          : 'No weekly check-in has been written yet.';
      final moodLine = mood != null ? 'Mood for the check-in: $mood.' : '';

      final prompt =
          '''
Write one concise weekly insight (3-5 sentences) for a values-based money reflection app.

This week's spending by value:
$spendingLines

Spending notes from saved sessions:
$noteLines

$checkInLine
$moodLine

Synthesize the numbers, the short spending notes, and the weekly check-in when available. Name one meaningful pattern without sounding clinical. End with one gentle takeaway or question. Do not use bullet points.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return const AiReflectionError('Could not generate a weekly insight.');
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError('Could not connect to AI service.');
    }
  }

  /// Continues a journal conversation — AI responds to a follow-up message.
  Future<AiReflectionResult> continueJournalChat({
    required String originalEntry,
    required String previousAiResponse,
    required String userReply,
    required String? mood,
  }) async {
    try {
      final moodLine = mood != null ? 'Their mood: $mood.' : '';

      final prompt =
          '''
This is an ongoing journal conversation.

Their original journal entry:
"$originalEntry"

Your previous response:
"$previousAiResponse"

Their new reply:
"$userReply"

$moodLine

Continue the conversation. Be warm, thoughtful, and help them explore their relationship with money and values. Keep it to 2-3 sentences. Ask a follow-up question if natural.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return const AiReflectionError('Could not generate a response.');
      }
      return AiReflectionSuccess(text);
    } on GenerativeAIException catch (e) {
      return AiReflectionError(_friendlyError(e.message));
    } catch (_) {
      return const AiReflectionError('Could not connect to AI service.');
    }
  }

  static String _friendlyError(String message) {
    if (message.contains('API key')) {
      return 'Your API key appears to be invalid. Please check it in Settings.';
    }
    if (message.contains('quota') || message.contains('rate')) {
      return 'You\'ve reached the usage limit. Please wait a moment and try again.';
    }
    return 'Could not generate a reflection right now. Please try again later.';
  }
}

// ---------------------------------------------------------------------------
// Provider — returns null when AI is disabled or no key
// ---------------------------------------------------------------------------

final aiReflectionServiceProvider = Provider<AiReflectionService?>((ref) {
  final enabled = ref.watch(aiReflectionEnabledProvider).valueOrNull ?? false;
  final apiKey = ref.watch(geminiApiKeyProvider).valueOrNull;

  if (!enabled || apiKey == null || apiKey.isEmpty) return null;
  return AiReflectionService(apiKey);
});
