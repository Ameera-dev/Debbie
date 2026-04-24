class MoneyEmotionOption {
  const MoneyEmotionOption({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;
}

class MoneyStoryPrompt {
  const MoneyStoryPrompt({required this.id, required this.prompt});

  final String id;
  final String prompt;
}

class MindfulnessContent {
  MindfulnessContent._();

  static const defaultCoolingOffThreshold = 500000;

  static const emotions = <MoneyEmotionOption>[
    MoneyEmotionOption(id: 'joyful', label: 'Joyful', emoji: '☀️'),
    MoneyEmotionOption(id: 'anxious', label: 'Anxious', emoji: '🌫️'),
    MoneyEmotionOption(id: 'impulsive', label: 'Impulsive', emoji: '⚡'),
    MoneyEmotionOption(id: 'intentional', label: 'Intentional', emoji: '🫶'),
    MoneyEmotionOption(id: 'generous', label: 'Generous', emoji: '🎁'),
    MoneyEmotionOption(id: 'guilty', label: 'Guilty', emoji: '🪞'),
    MoneyEmotionOption(id: 'proud', label: 'Proud', emoji: '🌱'),
  ];

  static const moneyStoryPrompts = <MoneyStoryPrompt>[
    MoneyStoryPrompt(
      id: 'earliest-memory',
      prompt: "What's your earliest memory of money?",
    ),
    MoneyStoryPrompt(
      id: 'parents',
      prompt: 'What did your parents teach you about money without saying it?',
    ),
    MoneyStoryPrompt(
      id: 'freedom',
      prompt: 'When was the last time money made you feel free?',
    ),
    MoneyStoryPrompt(
      id: 'younger-self',
      prompt: 'What would you tell your younger self about spending?',
    ),
    MoneyStoryPrompt(
      id: 'no-power',
      prompt: 'If money had no power over you, what would change?',
    ),
  ];

  static MoneyEmotionOption? emotionById(String? id) {
    if (id == null) return null;
    for (final option in emotions) {
      if (option.id == id) return option;
    }
    return null;
  }

  static MoneyStoryPrompt promptForMonth(DateTime monthStart) {
    final index =
        ((monthStart.year * 12) + monthStart.month) % moneyStoryPrompts.length;
    return moneyStoryPrompts[index];
  }
}
