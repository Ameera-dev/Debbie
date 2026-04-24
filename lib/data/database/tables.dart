class Tables {
  Tables._();

  static const userValues = 'user_values';
  static const valuesPlan = 'values_plan';
  static const goals = 'goals';
  static const transactions = 'transactions';
  static const transactionItems = 'transaction_items';
  static const journal = 'journal';
  static const dailyIntentions = 'daily_intentions';
  static const settings = 'settings';

  static const createUserValues =
      '''
    CREATE TABLE $userValues (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color TEXT NOT NULL,
      guardian_text TEXT,
      priority INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const createValuesPlan =
      '''
    CREATE TABLE $valuesPlan (
      id TEXT PRIMARY KEY,
      value_id TEXT NOT NULL REFERENCES $userValues(id) ON DELETE CASCADE,
      amount INTEGER NOT NULL,
      month TEXT NOT NULL,
      UNIQUE(value_id, month)
    )
  ''';

  static const createGoals =
      '''
    CREATE TABLE $goals (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      value_id TEXT NOT NULL REFERENCES $userValues(id),
      target_amount INTEGER,
      current_amount INTEGER DEFAULT 0,
      status TEXT DEFAULT 'active',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      completed_at TEXT
    )
  ''';

  // Session-level fields only; item-level fields live in transaction_items
  static const createTransactions =
      '''
    CREATE TABLE $transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'recorded',
      date TEXT NOT NULL,
      title TEXT,
      notes TEXT,
      image_path TEXT,
      pending_until TEXT,
      emotion TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const createTransactionItems =
      '''
    CREATE TABLE $transactionItems (
      id TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL REFERENCES $transactions(id) ON DELETE CASCADE,
      description TEXT NOT NULL,
      amount INTEGER NOT NULL,
      tags TEXT,
      value_id TEXT REFERENCES $userValues(id) ON DELETE SET NULL,
      goal_id TEXT REFERENCES $goals(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const createJournal =
      '''
    CREATE TABLE $journal (
      id TEXT PRIMARY KEY,
      content TEXT NOT NULL,
      mood TEXT,
      ai_response TEXT,
      entry_type TEXT NOT NULL DEFAULT 'legacy_entry',
      period_start TEXT,
      date TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const createDailyIntentions =
      '''
    CREATE TABLE $dailyIntentions (
      id TEXT PRIMARY KEY,
      date TEXT NOT NULL UNIQUE,
      value_id TEXT NOT NULL REFERENCES $userValues(id) ON DELETE CASCADE,
      reflection TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      reflected_at TEXT
    )
  ''';

  static const createSettings =
      '''
    CREATE TABLE $settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const aiReflections = 'ai_reflections';

  static const createAiReflections =
      '''
    CREATE TABLE $aiReflections (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      content TEXT NOT NULL,
      context_summary TEXT,
      date TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const allCreateStatements = [
    createUserValues,
    createValuesPlan,
    createGoals,
    createTransactions,
    createTransactionItems,
    createJournal,
    createDailyIntentions,
    createSettings,
    createAiReflections,
  ];
}

class SettingsKeys {
  SettingsKeys._();

  static const onboardingComplete = 'onboarding_complete';
  static const googleEmail = 'google_email';
  static const lastBackupDate = 'last_backup_date';
  static const darkMode = 'dark_mode';
  static const monthlyIncome = 'monthly_income';
  static const aiReflectionEnabled = 'ai_reflection_enabled';
  static const geminiApiKey = 'gemini_api_key';
  static const autoBackup = 'auto_backup';
  static const coolingOffThreshold = 'cooling_off_threshold';
}
