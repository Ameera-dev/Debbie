class AppStrings {
  AppStrings._();

  // App
  static const appName = 'Debbie';
  static const tagline = 'Discover the purpose behind your money';

  // Navigation
  static const navDashboard = 'Home';
  static const navTransactions = 'Transactions';
  static const navAdd = 'Add';
  static const navReflect = 'Reflect';
  static const navSettings = 'Settings';

  // Onboarding
  static const welcomeBegin = 'Begin';
  static const valuesScreenTitle = 'What matters most to you?';
  static const valuesScreenSubtitle =
      'Choose 3 to 7 values that guide your life';
  static const prioritizeTitle = 'Order your values';
  static const prioritizeSubtitle =
      'Drag to rank them from most to least important';
  static const planTitle = 'Align your energy';
  static const planSubtitle = 'How much do you earn each month?';
  static const goalsTitle = 'Set an intention';
  static const goalsSubtitle = 'What do you want to work toward?';
  static const completionTitle = "You're ready to live with intention";
  static const completionButton = 'Open Debbie';

  // Transactions
  static const addTransactionTitle = 'Add a transaction';
  static const editTransactionTitle = 'Edit transaction';
  static const income = 'Income';
  static const expense = 'Expense';
  static const descriptionHint = 'What was this for?';
  static const noteHint = 'Add a short note about what this spending meant';
  static const categoryHint = 'Category (optional)';
  static const saveTransaction = 'Save';

  // Dashboard
  static const greetingMorning = 'Good morning';
  static const greetingAfternoon = 'Good afternoon';
  static const greetingEvening = 'Good evening';
  static const alignmentScore = 'Aligned with your intentions';
  static const recentTransactions = 'Recent';
  static const seeAll = 'See all';
  static const valuesWheelTitle = 'Your energy this month';
  static const monthlySnapshot = 'Monthly snapshot';

  // Reflect
  static const reflectTitle = 'Weekly check-in';
  static const journalPlaceholder =
      'Past check-ins and older reflections will live here.';
  static const newEntry = 'Start weekly check-in';
  static const moodGrateful = 'Grateful';
  static const moodReflective = 'Reflective';
  static const moodUncertain = 'Uncertain';
  static const moodMotivated = 'Motivated';

  // Goals
  static const goalsEmpty =
      "You haven't set any intentions yet. Add one when you're ready.";
  static const goalActive = 'Active';
  static const goalCompleted = 'Completed';
  static const goalPaused = 'Paused';

  // Settings
  static const settingsTitle = 'Settings';
  static const settingsValues = 'Your Values';
  static const settingsAppearance = 'Appearance';
  static const settingsData = 'Data';
  static const settingsAbout = 'About';
  static const darkMode = 'Dark mode';
  static const connectGoogle = 'Connect Google Account';
  static const backupNow = 'Back Up Now';
  static const autoBackup = 'Auto-backup';
  static const madeWithIntention = 'Made with intention';

  // Backup
  static const backupSuccess = 'Your data is safely backed up';
  static const backingUp = 'Backing up your data...';
  static const restoring = 'Restoring your data...';
  static const restoreConfirmTitle = 'Replace your data?';
  static const restoreConfirmBody =
      'This will replace all your current data. Are you sure?';
  static const restoreConfirm = 'Yes, restore';
  static const restoreCancel = 'Cancel';
  static const restoreSuccess = 'Your data has been restored';
  static const selectBackup = 'Select a backup to restore';
  static const disconnectGoogle = 'Disconnect';
  static const autoBackupSubtitle =
      'Automatically back up when the app opens (once daily)';
  static const lastBackup = 'Last backup';
  static const never = 'Never';
  static const imageStorage = 'Image storage';
  static const backupCount = 'backups on Google Drive';

  // AI Transaction
  static const scanReceipt = 'Scan receipt';
  static const scanReceiptLoading = 'Reading your receipt...';
  static const scanReceiptNoAi =
      'Enable AI in Settings and add your Gemini API key to scan receipts.';

  // Export
  static const exportTitle = 'Export';
  static const exportCsv = 'Export as CSV';
  static const exportExcel = 'Export as Excel';
  static const exportCsvSubtitle = 'Spreadsheet-compatible, plain text';
  static const exportExcelSubtitle = 'Formatted .xlsx with styled headers';

  // Errors
  static const errorGeneric = 'Something went wrong. Please try again.';
  static const errorPermissionDenied =
      'Permission denied. Please enable access in Settings.';
  static const errorNoBackups = "You don't have any backups yet.";

  // Values Plan
  static const valuesPlan = 'Values Plan';
  static const essentials = 'Essentials';
  static const monthlyIncome = 'Monthly income';
  static const allocate = 'Allocate your energy';

  // Affirmations (dashboard celebration copy)
  static const affirmations = [
    'Beautiful, your energy is flowing with purpose.',
    'Your intentions are becoming reality.',
    'Every choice brings you closer to what matters.',
    'You are living with intention today.',
  ];

  // Weekly reflection prompts
  static const reflectionPrompts = [
    'How does that feel?',
    'Is this where you want your energy to flow?',
    'What would you change?',
  ];

  // AI Reflection
  static const settingsAiReflection = 'AI Reflection';
  static const aiReflectionToggle = 'Enable AI reflections';
  static const aiReflectionToggleSubtitle =
      'Get personalized reflections powered by Gemini';
  static const geminiApiKeyLabel = 'Gemini API Key';
  static const geminiApiKeyHint = 'Paste your Gemini API key';
  static const getAiReflection = 'Get AI Reflection';
  static const getAiInsight = 'Get AI Insight';
  static const aiReflectionLoading = 'Reflecting on your journey...';
  static const aiReflectionError =
      'Could not generate reflection. Please check your connection and API key.';
  static const aiReflectionNoKey =
      'Add your Gemini API key in Settings to enable AI reflections';

  // Onboarding Help Guide
  static const helpButtonLabel = 'Help me understand';

  static const helpPrioritizeTitle = 'Why order your values?';
  static const helpPrioritizeBody =
      'Think of your values as the things that make your life feel meaningful — '
      'family, health, personal growth, and so on.\n\n'
      'By putting them in order, you\'re telling yourself: '
      '"When I have to choose where my money goes, these are my priorities."\n\n'
      'There\'s no wrong answer. This is about what matters to YOU right now. '
      'You can always change this later.\n\n'
      'Drag the cards up or down to reorder them. '
      'The one at the top is what matters most to you today.';

  static const helpPlanTitle = 'What does "align your energy" mean?';
  static const helpPlanBody =
      'Most people think of money as something to restrict — '
      '"Don\'t spend too much on this, cut back on that."\n\n'
      'Debbie sees it differently. Your money is your energy. '
      'Every rupiah you spend is energy flowing somewhere. '
      'This screen helps you decide WHERE you want that energy to go.\n\n'
      'How it works:\n'
      '1. Enter your monthly income\n'
      '2. For each value, set a percentage — this is your intention\n'
      '3. The app calculates the actual amount automatically\n\n'
      'For example, if you earn Rp 10.000.000 and set Health to 10%, '
      'that means you intend to direct Rp 1.000.000 toward your health.\n\n'
      'As you log transactions later, Debbie will gently show you '
      'how your actual spending compares to your intentions. '
      'No judgment — just awareness.\n\n'
      'Tip: Expand each value card to see what it covers and '
      'a suggested percentage range to get you started.';

  // Intention moment (add transaction)
  static const intentionPrompts = [
    'Take a breath. Where is this energy going?',
    'Pause for a moment. What does this mean to you?',
    'Before you record, notice how this feels.',
    'A moment of awareness before the numbers.',
    'Let this be a small act of presence.',
  ];

  static const incomeAppreciationMessages = [
    'Take a moment to appreciate this arriving.',
    'Energy flowing in. Notice it with gratitude.',
    'Something earned, something received.',
  ];

  static const postSaveExpenseMessages = [
    'Recorded with intention.',
    'Another moment of awareness, captured.',
    'Your attention to this matters.',
  ];

  static const postSaveIncomeMessages = [
    'Received with gratitude.',
    'Noticed and appreciated.',
    'Energy arriving, acknowledged.',
  ];

  // Guided journal prompts
  static const guidedJournalPrompts = [
    'What purchase this week made you smile?',
    'Was there a moment you hesitated before spending?',
    'What felt most aligned with your values?',
    'Where did your energy flow that surprised you?',
    'What would you do differently with one purchase?',
    'Which moment of spending felt most like "you"?',
  ];

  // Monthly Insights
  static const monthlyInsightsTitle = 'Monthly Insights';
  static const encouragingMessages = [
    'You are living with beautiful intention.',
    'Your awareness is your superpower.',
    'Every mindful choice creates ripples of purpose.',
    'You are becoming more aligned every day.',
    'Your values are guiding you well.',
  ];
}
