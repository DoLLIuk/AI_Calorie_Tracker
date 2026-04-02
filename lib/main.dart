import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'meal_session.dart';
import 'meal_type.dart';
import 'onboarding.dart';
import 'photo_food/api_client.dart';
import 'photo_food/api_error.dart';
import 'photo_food/controller.dart';
import 'photo_food/models.dart';
import 'photo_food/photo_picker.dart';
import 'photo_food/repository.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  final PhotoFoodController? controller;
  final AppConfig? config;
  final PhotoFoodRepository? repository;
  final PhotoPicker? photoPicker;
  final bool skipOnboarding;
  final OnboardingResult? onboardingResult;

  const MyApp({
    super.key,
    this.controller,
    this.config,
    this.repository,
    this.photoPicker,
    this.skipOnboarding = false,
    this.onboardingResult,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _onboardingResultKey = 'app.onboarding.result';
  static const _onboardingDraftKey = 'app.onboarding.draft';
  static const _mealsKey = 'app.meals';

  late final PhotoFoodController _controller;
  late final bool _ownsController;
  OnboardingResult? _onboardingResult;
  OnboardingDraft? _onboardingDraft;
  List<_MealEntry> _persistedMeals = const [];
  bool _isHydrated = false;
  Future<void> _persistQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _onboardingResult = widget.onboardingResult;

    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final config = widget.config ?? AppConfig.fromEnvironment();
      final repository = widget.repository ?? PhotoFoodApiClient(config: config);
      final picker = widget.photoPicker ?? ImagePickerPhotoPicker();
      _controller = PhotoFoodController(repository: repository, photoPicker: picker);
      _ownsController = true;
    }

    _hydrateState();
  }

  Future<SharedPreferences?> _prefsOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _hydrateState() async {
    final prefs = await _prefsOrNull();
    if (!mounted) return;

    if (prefs != null) {
      final resultRaw = prefs.getString(_onboardingResultKey);
      final draftRaw = prefs.getString(_onboardingDraftKey);
      final mealsRaw = prefs.getString(_mealsKey);

      final restoredResult = widget.onboardingResult ?? _decodeOnboardingResult(resultRaw);
      final restoredDraft = _decodeOnboardingDraft(draftRaw);
      final restoredMeals = _decodeMeals(mealsRaw);

      setState(() {
        _onboardingResult = restoredResult;
        _onboardingDraft = restoredDraft;
        _persistedMeals = restoredMeals;
        _isHydrated = true;
      });
      if (kDebugMode) {
        debugPrint('[persistence] Hydrated app state');
      }
      return;
    }

    setState(() => _isHydrated = true);
    if (kDebugMode) {
      debugPrint('[persistence] Hydration skipped: SharedPreferences unavailable');
    }
  }

  Future<void> _persistState() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return;

    if (_onboardingResult == null) {
      await prefs.remove(_onboardingResultKey);
    } else {
      await prefs.setString(_onboardingResultKey, jsonEncode(_encodeOnboardingResult(_onboardingResult!)));
    }

    if (_onboardingDraft == null) {
      await prefs.remove(_onboardingDraftKey);
    } else {
      await prefs.setString(_onboardingDraftKey, jsonEncode(_onboardingDraft!.toJson()));
    }

    await prefs.setString(_mealsKey, jsonEncode(_persistedMeals.map((m) => m.toJson()).toList()));
  }

  Future<void> _enqueuePersistState({required String reason}) {
    _persistQueue = _persistQueue.then((_) async {
      try {
        await _persistState();
        if (kDebugMode && reason != 'draft_changed' && reason != 'meals_changed') {
          debugPrint('[persistence] Persisted: $reason');
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[persistence] Persist failed ($reason): $error');
        }
      }
    });
    return _persistQueue;
  }

  Future<void> _handleOnboardingCompleted(OnboardingResult result) async {
    setState(() {
      _onboardingResult = result;
      _onboardingDraft = null;
    });
    await _enqueuePersistState(reason: 'onboarding_completed');
  }

  Future<void> _openProfileEditor(BuildContext context) async {
    final initialDraft = _buildProfileEditDraft();
    final updatedResult = await Navigator.of(context).push<OnboardingResult>(
      MaterialPageRoute(
        builder: (routeContext) => OnboardingFlow(
          initialDraft: initialDraft,
          popOnBackAtEntryStep: true,
          onDraftChanged: _handleOnboardingDraftChanged,
          onCompleted: (result) async => Navigator.of(routeContext).pop(result),
        ),
      ),
    );
    if (!mounted || updatedResult == null) return;
    await _handleOnboardingCompleted(updatedResult);
  }

  OnboardingDraft _buildProfileEditDraft() {
    final result = _onboardingResult;
    if (result != null) {
      return OnboardingDraft(
        step: 2,
        goalType: result.goalType,
        sexType: result.sex == SexType.male ? SexType.male : SexType.female,
        activityLevel: result.activityLevel,
        targetPace: result.targetPace,
        macroProfile: result.macroProfile,
        heightUnit: HeightUnit.cm,
        weightUnit: WeightUnit.kg,
        ageText: result.age.toString(),
        heightText: _formatEditableNumber(result.heightCm),
        feetText: '',
        inchesText: '',
        weightText: _formatEditableNumber(result.weightKg),
      );
    }
    return _onboardingDraft ??
        const OnboardingDraft(
          step: 2,
          goalType: null,
          sexType: null,
          activityLevel: null,
          targetPace: null,
          macroProfile: MacroProfile.balanced,
          heightUnit: HeightUnit.cm,
          weightUnit: WeightUnit.kg,
          ageText: '',
          heightText: '',
          feetText: '',
          inchesText: '',
          weightText: '',
        );
  }

  String _formatEditableNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  void _handleOnboardingDraftChanged(OnboardingDraft draft) {
    _onboardingDraft = draft;
    _enqueuePersistState(reason: 'draft_changed');
  }

  void _handleMealsChanged(List<_MealEntry> meals) {
    _persistedMeals = List<_MealEntry>.from(meals);
    _enqueuePersistState(reason: 'meals_changed');
  }

  void _resetOnboardingForTesting() {
    setState(() {
      _onboardingResult = null;
      _onboardingDraft = null;
    });
    _enqueuePersistState(reason: 'onboarding_reset');
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calories',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B66F6)),
      ),
      home: !_isHydrated
          ? const _BootstrapLoadingScreen()
          : widget.skipOnboarding || _onboardingResult != null
              ? _AppShell(
                  controller: _controller,
                  onboardingResult: _onboardingResult,
                  initialMeals: _persistedMeals,
                  onMealsChanged: _handleMealsChanged,
                  onResetOnboarding: _resetOnboardingForTesting,
                  onEditProfile: _openProfileEditor,
                )
              : OnboardingFlow(
                  initialDraft: _onboardingDraft,
                  onDraftChanged: _handleOnboardingDraftChanged,
                  onCompleted: _handleOnboardingCompleted,
                ),
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(key: Key('bootstrap-loading')),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  final PhotoFoodController controller;
  final OnboardingResult? onboardingResult;
  final List<_MealEntry> initialMeals;
  final ValueChanged<List<_MealEntry>> onMealsChanged;
  final VoidCallback onResetOnboarding;
  final Future<void> Function(BuildContext context) onEditProfile;

  const _AppShell({
    required this.controller,
    this.onboardingResult,
    required this.initialMeals,
    required this.onMealsChanged,
    required this.onResetOnboarding,
    required this.onEditProfile,
  });

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int selectedTab = 0;
  final GlobalKey<_CaloriesHomePageState> _homeKey = GlobalKey<_CaloriesHomePageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: [
          _CaloriesHomePage(
            key: _homeKey,
            controller: widget.controller,
            onboardingResult: widget.onboardingResult,
            initialMeals: widget.initialMeals,
            onMealsChanged: widget.onMealsChanged,
          ),
          ProfilePage(
            onboardingResult: widget.onboardingResult,
            onResetOnboarding: widget.onResetOnboarding,
            onEditProfile: () => widget.onEditProfile(context),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        key: const Key('fab-add'),
        backgroundColor: const Color(0xFF2B66F6),
        foregroundColor: Colors.white,
        onPressed: selectedTab == 0 ? () => _homeKey.currentState?._onPlusTap() : null,
        child: const Icon(Icons.add, size: 32),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.white,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavButton(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: selectedTab == 0,
                onTap: () => setState(() => selectedTab = 0),
              ),
              const SizedBox(width: 48),
              _NavButton(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: selectedTab == 1,
                onTap: () => setState(() => selectedTab = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaloriesHomePage extends StatefulWidget {
  final PhotoFoodController controller;
  final OnboardingResult? onboardingResult;
  final List<_MealEntry> initialMeals;
  final ValueChanged<List<_MealEntry>> onMealsChanged;

  const _CaloriesHomePage({
    super.key,
    required this.controller,
    this.onboardingResult,
    this.initialMeals = const [],
    required this.onMealsChanged,
  });

  @override
  State<_CaloriesHomePage> createState() => _CaloriesHomePageState();
}

class _CaloriesHomePageState extends State<_CaloriesHomePage> {
  int selectedDay = 5;
  String? _lastErrorKey;
  final MealSessionService _mealSessionService = const MealSessionService();
  final List<_MealEntry> meals = [];
  final Map<String, MealSession> _sessionsByEntryId = {};
  final Set<MealType> _expandedCategories = <MealType>{};

  List<_DayItem> get days {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 5));
    return List.generate(7, (i) {
      final day = start.add(Duration(days: i));
      return _DayItem(
        weekDay: _weekdayLabel(day.weekday),
        dayNum: day.day.toString(),
        date: _dateOnly(day),
      );
    });
  }

  DateTime get _selectedDate => days[selectedDay].date;
  List<_MealEntry> get _selectedMeals => meals.where((m) => _isSameDate(m.day, _selectedDate)).toList(growable: false);
  List<MealSession> get _selectedSessions {
    final deduplicated = <String, MealSession>{};
    for (final meal in _selectedMeals) {
      final session = _sessionsByEntryId[meal.requestId];
      if (session != null) {
        deduplicated[session.id] = session;
      }
    }
    final sessions = deduplicated.values.toList(growable: false)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  double get _sumKcal => _selectedSessions.fold(0.0, (sum, session) => sum + session.totalKcal);
  double get _sumProtein => _selectedSessions.fold(0.0, (sum, session) => sum + session.totalProtein);
  double get _sumCarbs => _selectedSessions.fold(0.0, (sum, session) => sum + session.totalCarbs);
  double get _sumFats => _selectedSessions.fold(0.0, (sum, session) => sum + session.totalFat);
  _MealEntry? get _latestAddedMealForSelectedDay {
    if (_selectedMeals.isEmpty) return null;
    final ordered = List<_MealEntry>.from(_selectedMeals)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ordered.first;
  }

  @override
  void initState() {
    super.initState();
    meals.addAll(widget.initialMeals);
    _rebuildAllSessions();
    widget.controller.addListener(_onControllerUpdated);
  }

  void _notifyMealsChanged() {
    widget.onMealsChanged(List<_MealEntry>.from(meals));
  }

  double get _dailyCalorieTarget => widget.onboardingResult?.plan.calorieTarget.toDouble() ?? 2000.0;

  void _rebuildAllSessions() {
    _sessionsByEntryId.clear();
    final days = meals.map((e) => _dateOnly(e.day)).toSet();
    for (final day in days) {
      _rebuildSessionsForDay(day, notify: false);
    }
  }

  void _rebuildSessionsForDay(DateTime day, {bool notify = true}) {
    final dayOnly = _dateOnly(day);
    final dayMeals = meals.where((m) => _isSameDate(m.day, dayOnly)).toList(growable: false);
    final dayEntries = dayMeals
        .map(
          (meal) => MealSessionEntry(
            id: meal.requestId,
            timestamp: meal.timestamp,
            name: meal.name,
            kcal: meal.kcal,
            proteinG: meal.proteinG,
            fatG: meal.fatG,
            carbsG: meal.carbsG,
            userSelectedSessionType: meal.userSelectedType,
          ),
        )
        .toList(growable: false);

    final sessions = _mealSessionService.buildSessionsForDay(
      day: dayOnly,
      entries: dayEntries,
      dailyCalorieTarget: _dailyCalorieTarget,
    );

    _sessionsByEntryId.removeWhere((_, session) => _isSameDate(session.date, dayOnly));
    for (final session in sessions) {
      for (final entry in session.entries) {
        _sessionsByEntryId[entry.id] = session;
      }
    }

    for (var i = 0; i < meals.length; i++) {
      final meal = meals[i];
      if (!_isSameDate(meal.day, dayOnly)) {
        continue;
      }
      final session = _sessionsByEntryId[meal.requestId];
      if (session == null) {
        continue;
      }
      meals[i] = meal.copyWith(
        sessionId: session.id,
        autoDetectedType: session.autoDetectedType,
        autoDetectedTier: session.autoDetectedTier,
        finalType: session.overriddenByUser ? meal.userSelectedType ?? session.finalType : session.autoDetectedType,
        finalTier: session.finalTier,
      );
    }

    if (notify) {
      _notifyMealsChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdated);
    super.dispose();
  }

  void _onControllerUpdated() {
    final state = widget.controller.state;
    if (state.response != null && (state.status == HomeStatus.awaitingPortion || state.status == HomeStatus.loaded)) {
      _upsertMealFromResponse(state.response!);
    }

    final error = state.error;
    if (error == null || !mounted) return;

    final key = '${error.code}:${error.requestId ?? ''}';
    if (_lastErrorKey == key) return;
    _lastErrorKey = key;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(mapErrorCodeToMessage(error.code))));
  }

  void _upsertMealFromResponse(PhotoFoodResponse response) {
    final totals = response.meta.estimatedTotals;
    final now = DateTime.now();
    final entryTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    final meal = _MealEntry(
      requestId: response.requestId,
      origin: MealOrigin.ai,
      name: response.item.name,
      day: _selectedDate,
      timestamp: entryTimestamp,
      kcal: totals?.kcal ?? 0,
      proteinG: totals?.proteinG ?? 0,
      carbsG: totals?.carbsG ?? 0,
      fatG: totals?.fatG ?? 0,
      portionG: response.meta.estimatedPortionG,
      confidence: response.item.confidence,
      per100Kcal: response.item.nutritionPer100g.kcal,
      per100ProteinG: response.item.nutritionPer100g.proteinG,
      per100CarbsG: response.item.nutritionPer100g.carbsG,
      per100FatG: response.item.nutritionPer100g.fatG,
      userSelectedType: null,
      sessionId: '',
      autoDetectedType: MealType.snack,
      autoDetectedTier: MealSessionTier.extra,
      finalType: MealType.snack,
      finalTier: MealSessionTier.extra,
    );

    final idx = meals.indexWhere((e) => e.requestId == response.requestId);
    setState(() {
      if (idx >= 0) {
        meals[idx] = meal;
      } else {
        meals.insert(0, meal);
      }
      _rebuildSessionsForDay(_selectedDate, notify: false);
    });
    _notifyMealsChanged();
  }

  Future<void> _onPlusTap() async {
    final action = await _showAddActionSheet();
    if (action == null) return;

    if (action == _AddAction.manual) {
      await _showManualMealSheet();
      return;
    }

    final source = action == _AddAction.camera ? PickSource.camera : PickSource.gallery;
    await widget.controller.pickAndAnalyze(source);
    if (!mounted) return;

    if (widget.controller.state.status == HomeStatus.awaitingPortion) {
      await _showPortionBottomSheet();
    }
  }
  Future<_AddAction?> _showAddActionSheet() {
    return showModalBottomSheet<_AddAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('pick-camera'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.of(context).pop(_AddAction.camera),
              ),
              ListTile(
                key: const Key('pick-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(_AddAction.gallery),
              ),
              ListTile(
                key: const Key('add-manual'),
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('Add manually'),
                onTap: () => Navigator.of(context).pop(_AddAction.manual),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showManualMealSheet({_MealEntry? editingMeal}) async {
    final nameCtrl = TextEditingController(text: editingMeal?.name ?? '');
    final kcalCtrl = TextEditingController(text: editingMeal == null ? '' : editingMeal.kcal.toStringAsFixed(1));
    final gramsCtrl = TextEditingController(text: editingMeal?.portionG == null ? '' : editingMeal!.portionG!.toStringAsFixed(1));
    final proteinCtrl = TextEditingController(text: editingMeal == null ? '' : editingMeal.proteinG.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: editingMeal == null ? '' : editingMeal.fatG.toStringAsFixed(1));
    final carbsCtrl = TextEditingController(text: editingMeal == null ? '' : editingMeal.carbsG.toStringAsFixed(1));
    var selectedMealType = editingMeal?.userSelectedType ?? editingMeal?.finalType ?? classifyMealTypeByTime(DateTime.now());
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final media = MediaQuery.of(context);
        final bottomInset = max(media.viewInsets.bottom, media.padding.bottom + 16);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(editingMeal == null ? 'Add Meal' : 'Edit Meal', style: const TextStyle(fontSize: 34 / 1.5, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _sheetInput(controller: nameCtrl, label: 'Meal Name', hint: 'e.g. Caesar Salad'),
                      const SizedBox(height: 12),
                      _sheetInput(controller: kcalCtrl, label: 'Calories', hint: '0', numeric: true),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _sheetInput(controller: gramsCtrl, label: 'Weight (g)', hint: '250', numeric: true)),
                          const SizedBox(width: 10),
                          Expanded(child: _sheetInput(controller: proteinCtrl, label: 'Protein (g)', hint: '20', numeric: true)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _sheetInput(controller: fatCtrl, label: 'Fat (g)', hint: '8', numeric: true)),
                          const SizedBox(width: 10),
                          Expanded(child: _sheetInput(controller: carbsCtrl, label: 'Carbs (g)', hint: '30', numeric: true)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Meal Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _mealTypeTile(
                              key: const Key('meal-type-breakfast'),
                              mealType: MealType.breakfast,
                              selected: selectedMealType == MealType.breakfast,
                              onTap: () => setSheetState(() => selectedMealType = MealType.breakfast),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _mealTypeTile(
                              key: const Key('meal-type-lunch'),
                              mealType: MealType.lunch,
                              selected: selectedMealType == MealType.lunch,
                              onTap: () => setSheetState(() => selectedMealType = MealType.lunch),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _mealTypeTile(
                              key: const Key('meal-type-dinner'),
                              mealType: MealType.dinner,
                              selected: selectedMealType == MealType.dinner,
                              onTap: () => setSheetState(() => selectedMealType = MealType.dinner),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _mealTypeTile(
                              key: const Key('meal-type-snack'),
                              mealType: MealType.snack,
                              selected: selectedMealType == MealType.snack,
                              onTap: () => setSheetState(() => selectedMealType = MealType.snack),
                            ),
                          ),
                        ],
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(formError!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7E9EF1),
                            minimumSize: const Size.fromHeight(58),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: () {
                            final meal = _buildManualMeal(
                              original: editingMeal,
                              name: nameCtrl.text,
                              kcal: kcalCtrl.text,
                              grams: gramsCtrl.text,
                              protein: proteinCtrl.text,
                              fat: fatCtrl.text,
                              carbs: carbsCtrl.text,
                              mealType: selectedMealType,
                            );
                            if (meal == null) {
                              setSheetState(() => formError = 'Check fields: name is required and numbers must be >= 0.');
                              return;
                            }

                            setState(() {
                              final idx = meals.indexWhere((m) => m.requestId == meal.requestId);
                              if (idx >= 0) {
                                meals[idx] = meal;
                              } else {
                                meals.insert(0, meal);
                              }
                              _rebuildSessionsForDay(meal.day, notify: false);
                            });
                            _notifyMealsChanged();
                            Navigator.of(context).pop();
                          },
                          child: Text(editingMeal == null ? 'Add Meal' : 'Save Changes', style: const TextStyle(fontSize: 22 / 1.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _sheetInput({required TextEditingController controller, required String label, required String hint, bool numeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF2F4F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _mealTypeTile({required Key key, required MealType mealType, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 88,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF4FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFD5DAE5), width: selected ? 2 : 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(mealTypeIcon(mealType), color: selected ? const Color(0xFF2563EB) : const Color(0xFF8E97A8), size: 26),
            const SizedBox(height: 6),
            Text(mealTypeLabel(mealType), style: TextStyle(fontWeight: FontWeight.w700, color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF111827))),
          ],
        ),
      ),
    );
  }
  _MealEntry? _buildManualMeal({
    required _MealEntry? original,
    required String name,
    required String kcal,
    required String grams,
    required String protein,
    required String fat,
    required String carbs,
    required MealType mealType,
  }) {
    final mealName = name.trim();
    final gramsValue = _parseNonNegative(grams);

    if (mealName.isEmpty || gramsValue == null) {
      return null;
    }

    if (original != null) {
      final oldGrams = original.portionG;
      if (oldGrams == null || oldGrams <= 0 || gramsValue <= 0) {
        return null;
      }

      final factor = gramsValue / oldGrams;
      return _MealEntry(
        requestId: original.requestId,
        origin: original.origin,
        name: mealName,
        day: original.day,
        timestamp: original.timestamp,
        kcal: original.kcal * factor,
        proteinG: original.proteinG * factor,
        carbsG: original.carbsG * factor,
        fatG: original.fatG * factor,
        portionG: gramsValue,
        confidence: original.confidence,
        per100Kcal: original.per100Kcal,
        per100ProteinG: original.per100ProteinG,
        per100CarbsG: original.per100CarbsG,
        per100FatG: original.per100FatG,
        userSelectedType: mealType,
        sessionId: original.sessionId,
        autoDetectedType: original.autoDetectedType,
        autoDetectedTier: original.autoDetectedTier,
        finalType: mealType,
        finalTier: original.finalTier,
      );
    }

    final kcalValue = _parseNonNegative(kcal);
    final proteinValue = _parseNonNegative(protein);
    final fatValue = _parseNonNegative(fat);
    final carbsValue = _parseNonNegative(carbs);

    if (kcalValue == null || proteinValue == null || fatValue == null || carbsValue == null || gramsValue <= 0) {
      return null;
    }

    final factor = 100.0 / gramsValue;
    final now = DateTime.now();
    final entryTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    return _MealEntry(
      requestId: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      origin: MealOrigin.manual,
      name: mealName,
      day: _selectedDate,
      timestamp: entryTimestamp,
      kcal: kcalValue,
      proteinG: proteinValue,
      carbsG: carbsValue,
      fatG: fatValue,
      portionG: gramsValue,
      confidence: 1.0,
      per100Kcal: kcalValue * factor,
      per100ProteinG: proteinValue * factor,
      per100CarbsG: carbsValue * factor,
      per100FatG: fatValue * factor,
      userSelectedType: mealType,
      sessionId: '',
      autoDetectedType: MealType.snack,
      autoDetectedTier: MealSessionTier.extra,
      finalType: mealType,
      finalTier: MealSessionTier.extra,
    );
  }
  double? _parseNonNegative(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  Future<void> _showPortionBottomSheet() async {
    final response = widget.controller.state.response;
    if (response == null) return;

    final aiEstimate = response.meta.estimatedPortionG;
    final inputController = TextEditingController(text: (aiEstimate ?? 250).toStringAsFixed(0));
    String? localError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final bottomInset = max(media.viewInsets.bottom, media.padding.bottom + 16);

        return AnimatedPadding(
          key: const Key('portion-sheet'),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final isLoading = widget.controller.state.status == HomeStatus.confirmingPortion;
              return Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Confirm portion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Enter grams (1-2000) for accurate calories and macros.'),
                    const SizedBox(height: 6),
                    Text(
                      aiEstimate == null
                          ? 'AI estimate is unavailable.'
                          : 'AI estimate: ${aiEstimate.toStringAsFixed(0)} g',
                      key: const Key('portion-ai-estimate'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('portion-input'),
                      controller: inputController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Grams', errorText: localError, border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('portion-confirm'),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final validation = PhotoFoodController.validatePortionInput(inputController.text);
                                if (validation != null) {
                                  setModalState(() => localError = validation);
                                  return;
                                }
                                final grams = double.parse(inputController.text.trim().replaceAll(',', '.'));
                                final ok = await widget.controller.confirmPortion(grams);
                                if (!context.mounted) return;
                                if (ok) Navigator.of(context).pop();
                              },
                        child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm portion'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const Key('portion-use-ai-estimate'),
                        onPressed: isLoading || aiEstimate == null
                            ? null
                            : () async {
                                final ok = await widget.controller.confirmPortionWithAiEstimate();
                                if (!context.mounted) return;
                                if (ok) Navigator.of(context).pop();
                              },
                        child: const Text('Not sure, use AI estimate'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showMealDetails(_MealEntry meal) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Meal type: ${mealTypeLabel(meal.finalType)}'),
                Text('Confidence: ${(meal.confidence * 100).toStringAsFixed(0)}%'),
                Text('Time: ${_timeLabelFromDateTime(meal.timestamp)}'),
                const SizedBox(height: 12),
                Text('Portion: ${meal.portionG?.toStringAsFixed(0) ?? '-'} g'),
                Text('Calories: ${meal.kcal.toStringAsFixed(1)} kcal'),
                Text('Protein: ${meal.proteinG.toStringAsFixed(1)} g'),
                Text('Fat: ${meal.fatG.toStringAsFixed(1)} g'),
                Text('Carbs: ${meal.carbsG.toStringAsFixed(1)} g'),
                const Divider(height: 24),
                const Text('Per 100g', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Kcal: ${meal.per100Kcal.toStringAsFixed(1)}'),
                Text('P: ${meal.per100ProteinG.toStringAsFixed(1)} g'),
                Text('F: ${meal.per100FatG.toStringAsFixed(1)} g'),
                Text('C: ${meal.per100CarbsG.toStringAsFixed(1)} g'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _showManualMealSheet(editingMeal: meal);
                        },
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () {
                          setState(() {
                            meals.removeWhere((m) => m.requestId == meal.requestId);
                            _rebuildSessionsForDay(meal.day, notify: false);
                          });
                          _notifyMealsChanged();
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _MealEntry? _mealById(String mealId) {
    for (final meal in meals) {
      if (meal.requestId == mealId) {
        return meal;
      }
    }
    return null;
  }

  double _categoryGoalKcal(MealType type, double dailyTarget) {
    switch (type) {
      case MealType.breakfast:
        return dailyTarget * 0.30;
      case MealType.lunch:
        return dailyTarget * 0.40;
      case MealType.dinner:
        return dailyTarget * 0.25;
      case MealType.snack:
        return dailyTarget * 0.05;
    }
  }

  List<_CategorySectionModel> _buildCategorySections(List<MealSession> sessions, double dailyTarget) {
    const orderedTypes = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];

    final grouped = <MealType, List<MealSession>>{
      MealType.breakfast: <MealSession>[],
      MealType.lunch: <MealSession>[],
      MealType.dinner: <MealSession>[],
      MealType.snack: <MealSession>[],
    };

    for (final session in sessions) {
      grouped[session.finalType]!.add(session);
    }

    for (final type in orderedTypes) {
      grouped[type]!.sort((a, b) => b.startTime.compareTo(a.startTime));
    }

    return orderedTypes
        .map(
          (type) {
            final categorySessions = grouped[type]!;
            final mainSessions = <MealSession>[];
            final extraSessions = <MealSession>[];
            final snackSessions = <MealSession>[];

            if (type == MealType.snack) {
              snackSessions.addAll(categorySessions);
            } else {
              for (final session in categorySessions) {
                if (session.finalTier == MealSessionTier.mainMeal) {
                  mainSessions.add(session);
                } else {
                  extraSessions.add(session);
                }
              }
            }

            return _CategorySectionModel(
              type: type,
              goalKcal: _categoryGoalKcal(type, dailyTarget),
              consumedKcal: categorySessions.fold(0.0, (sum, session) => sum + session.totalKcal),
              mainSessions: mainSessions,
              extraSessions: extraSessions,
              snackSessions: snackSessions,
            );
          },
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final daySessions = _selectedSessions;
        final latestMeal = _latestAddedMealForSelectedDay;

        final consumed = _sumKcal;
        final calorieTarget = widget.onboardingResult?.plan.calorieTarget.toDouble() ?? 2000.0;
        final remaining = max(0.0, calorieTarget - consumed);
        final progress = consumed <= 0 ? 0.0 : (consumed / calorieTarget).clamp(0.0, 1.0);
        final categorySections = _buildCategorySections(daySessions, calorieTarget);

        final protein = _sumProtein;
        final carbs = _sumCarbs;
        final fat = _sumFats;

        final isLoading = state.status == HomeStatus.pickingImage || state.status == HomeStatus.uploading || state.status == HomeStatus.confirmingPortion;

        return Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(fireCount: daySessions.length),
                    const SizedBox(height: 18),
                    _buildDaysRow(),
                    const SizedBox(height: 18),
                    _buildCaloriesCard(consumed: consumed, remaining: remaining, progress: progress),
                    const SizedBox(height: 14),
                    _buildMacros(protein: protein, carbs: carbs, fat: fat),
                    const SizedBox(height: 14),
                    _LatestAddedMealCard(
                      meal: latestMeal,
                      onTap: latestMeal == null ? null : () => _showMealDetails(latestMeal),
                    ),
                    const SizedBox(height: 20),
                    const Text('History', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    ...categorySections.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CategorySectionCard(
                          model: section,
                          expanded: _expandedCategories.contains(section.type),
                          onToggle: () {
                            setState(() {
                              if (_expandedCategories.contains(section.type)) {
                                _expandedCategories.remove(section.type);
                              } else {
                                _expandedCategories.add(section.type);
                              }
                            });
                          },
                          onTapMeal: (mealId) {
                            final meal = _mealById(mealId);
                            if (meal != null) {
                              _showMealDetails(meal);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x66000000),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader({required int fireCount}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Calories', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFFF1DC), borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_outlined, color: Color(0xFFE38A1F), size: 18),
              const SizedBox(width: 6),
              Text(fireCount.toString(), style: const TextStyle(color: Color(0xFFB47628), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDaysRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(days.length, (index) {
          final isSelected = index == selectedDay;
          return Padding(
            padding: EdgeInsets.only(right: index == days.length - 1 ? 0 : 10),
            child: GestureDetector(
              key: Key('day-chip-$index'),
              onTap: () => setState(() => selectedDay = index),
              child: Column(
                children: [
                  Text(days[index].weekDay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFF2B66F6) : const Color(0xFF6F7282))),
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: isSelected ? const Color(0xFF2B66F6) : const Color(0xFFECEEF2), shape: BoxShape.circle),
                    child: Text(days[index].dayNum, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF34374A), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCaloriesCard({required double consumed, required double remaining, required double progress}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3B77FF), Color(0xFF8D2EF4)]),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberBlock(label: 'Consumed', main: consumed.toStringAsFixed(0), sub: 'kcal', alignEnd: false, light: true),
              _NumberBlock(label: 'Remaining', main: remaining.toStringAsFixed(0), sub: 'kcal', alignEnd: true, light: true),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(value: progress, backgroundColor: const Color(0x80FFFFFF), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0E0F16))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacros({required double protein, required double carbs, required double fat}) {
    final targetProtein = widget.onboardingResult?.plan.proteinTargetG.toDouble() ?? 150;
    final targetCarbs = widget.onboardingResult?.plan.carbsTargetG.toDouble() ?? 200;
    final targetFat = widget.onboardingResult?.plan.fatTargetG.toDouble() ?? 60;

    return Row(
      children: [
        Expanded(child: _MacroCard(title: 'Protein', amount: '${protein.toStringAsFixed(0)}g', amountColor: const Color(0xFF2B66F6), goal: 'of ${targetProtein.toStringAsFixed(0)}g', left: '${max(0.0, targetProtein - protein).toStringAsFixed(0)}g left', value: (protein / targetProtein).clamp(0.0, 1.0))),
        const SizedBox(width: 10),
        Expanded(child: _MacroCard(title: 'Carbs', amount: '${carbs.toStringAsFixed(0)}g', amountColor: const Color(0xFFE5793A), goal: 'of ${targetCarbs.toStringAsFixed(0)}g', left: '${max(0.0, targetCarbs - carbs).toStringAsFixed(0)}g left', value: (carbs / targetCarbs).clamp(0.0, 1.0))),
        const SizedBox(width: 10),
        Expanded(child: _MacroCard(title: 'Fats', amount: '${fat.toStringAsFixed(0)}g', amountColor: const Color(0xFF25A55F), goal: 'of ${targetFat.toStringAsFixed(0)}g', left: '${max(0.0, targetFat - fat).toStringAsFixed(0)}g left', value: (fat / targetFat).clamp(0.0, 1.0))),
      ],
    );
  }

}

enum _AddAction { camera, gallery, manual }
enum MealOrigin { ai, manual }

class ProfilePage extends StatelessWidget {
  final OnboardingResult? onboardingResult;
  final VoidCallback onResetOnboarding;
  final Future<void> Function() onEditProfile;

  const ProfilePage({super.key, this.onboardingResult, required this.onResetOnboarding, required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    final result = onboardingResult;
    final calorieTarget = result?.plan.calorieTarget ?? 2000;
    final proteinTarget = result?.plan.proteinTargetG ?? 150;
    final fatTarget = result?.plan.fatTargetG ?? 60;
    final carbsTarget = result?.plan.carbsTargetG ?? 220;

    final ageValue = result?.age.toString() ?? '--';
    final heightValue = result == null ? '--' : '${result.heightCm.toStringAsFixed(0)} cm';
    final weightValue = result == null ? '--' : '${result.weightKg.toStringAsFixed(1)} kg';

    final bmi = result == null ? null : result.weightKg / pow(result.heightCm / 100, 2);
    final bmiValue = bmi == null ? '--' : bmi.toStringAsFixed(1);

    final trendKg = switch (result?.goalType) {
      GoalType.loseWeight => -1.2,
      GoalType.gainWeight => 1.1,
      GoalType.maintain || GoalType.trackOnly || null => 0.0,
    };
    final trendLabel = trendKg > 0 ? '+${trendKg.toStringAsFixed(1)}kg' : '${trendKg.toStringAsFixed(1)}kg';
    final trendCaption = trendKg == 0 ? 'steady this week' : 'this week';

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lumina Health',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF20243A)),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD5DAE6)),
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.person, size: 20, color: Color(0xFF2F66F6)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE9E7EE),
                      border: Border.all(color: const Color(0xFFD9DFEE), width: 2),
                    ),
                    child: const Icon(Icons.phone_iphone_rounded, size: 44, color: Color(0xFFFFA377)),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () {
                        onEditProfile();
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2F66F6),
                        ),
                        child: const Icon(Icons.edit, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                result == null ? 'Your Profile' : '${_sexLabel(result.sex)} Profile',
                style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w800, color: Color(0xFF222A44)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _ProfileChip(label: result == null ? 'GOAL' : _goalLabel(result.goalType).toUpperCase()),
                  _ProfileChip(
                    label: result == null ? 'ACTIVITY' : _activityLabel(result.activityLevel).toUpperCase(),
                    bg: const Color(0xFFD7DBE8),
                    textColor: const Color(0xFF4F5978),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ProfileMetricCard(title: 'Age', value: ageValue, valueColor: const Color(0xFF2B66F6)),
                _ProfileMetricCard(title: 'Height', value: heightValue, valueColor: const Color(0xFF2B66F6)),
                _ProfileMetricCard(title: 'Weight', value: weightValue, valueColor: const Color(0xFF25A55F)),
                _ProfileMetricCard(title: 'BMI', value: bmiValue, valueColor: const Color(0xFFE5793A)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EBF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weekly Consistency', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2B3045))),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Text(
                          'weight trend over last 7 days',
                          style: TextStyle(fontSize: 11, color: Color(0xFF76809C), fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        trendLabel,
                        style: const TextStyle(fontSize: 34, color: Color(0xFF2F66F6), fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      trendCaption,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9DA5BC), fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _WeeklyBars(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Badges & Streaks', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF283151))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _BadgeCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Color(0xFFFF9A33),
                    title: '3-DAY STREAK',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _BadgeCard(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: Color(0xFF2F66F6),
                    title: 'PROTEIN MASTER',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _BadgeCard(
                    icon: Icons.verified_user_rounded,
                    iconColor: Color(0xFF3AA35B),
                    title: 'WEIGHT HERO',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Daily Targets', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF283151))),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EBF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Calories Target', style: TextStyle(fontSize: 12, color: Color(0xFF7E8293))),
                  const SizedBox(height: 4),
                  Text(
                    '$calorieTarget kcal',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF111322)),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: 0,
                        backgroundColor: Color(0xFFD7D9DE),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF111322)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$calorieTarget kcal left',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroCard(
                          title: 'Protein',
                          amount: '0g',
                          amountColor: const Color(0xFF2B66F6),
                          goal: 'of ${proteinTarget}g',
                          left: '${proteinTarget}g left',
                          value: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MacroCard(
                          title: 'Carbs',
                          amount: '0g',
                          amountColor: const Color(0xFFE5793A),
                          goal: 'of ${carbsTarget}g',
                          left: '${carbsTarget}g left',
                          value: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MacroCard(
                          title: 'Fats',
                          amount: '0g',
                          amountColor: const Color(0xFF25A55F),
                          goal: 'of ${fatTarget}g',
                          left: '${fatTarget}g left',
                          value: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountSettingsPage(
                      onboardingResult: result,
                      onLogout: onResetOnboarding,
                      onEditProfile: onEditProfile,
                    ),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.settings, size: 17, color: Color(0xFF606A84)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('App Preferences', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF293252))),
                    ),
                    Icon(Icons.chevron_right, size: 19, color: Color(0xFF606A84)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('reset-onboarding-btn'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFD2212D),
                  minimumSize: const Size.fromHeight(56),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: onResetOnboarding,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_circle_filled_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('RESET ONBOARDING', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const _ProfileChip({
    required this.label,
    this.bg = const Color(0xFFAEC2F7),
    this.textColor = const Color(0xFF2D4A9E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.25),
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _ProfileMetricCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 38) / 2,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 30, color: valueColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: 0,
                backgroundColor: Color(0xFFD7D9DE),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF111322)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars();

  @override
  Widget build(BuildContext context) {
    const bars = [0.30, 0.70, 0.45, 0.78, 0.52, 0.88, 0.62];
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars.length, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 7,
                        height: 66 * bars[index],
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F95D8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[index], style: const TextStyle(fontSize: 8, color: Color(0xFF8D95AD), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _BadgeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF576180)),
          ),
        ],
      ),
    );
  }
}

class AccountSettingsPage extends StatefulWidget {
  final OnboardingResult? onboardingResult;
  final VoidCallback onLogout;
  final Future<void> Function() onEditProfile;

  const AccountSettingsPage({
    super.key,
    required this.onboardingResult,
    required this.onLogout,
    required this.onEditProfile,
  });

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool pushNotifications = true;
  bool twoFactor = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.onboardingResult;
    final userName = result == null ? 'Member' : '${_sexLabel(result.sex)} Member';
    final subtitle = result == null
        ? 'Manage your personal health profile and preferences'
        : '${_goalLabel(result.goalType)} | ${_activityLabel(result.activityLevel)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F6),
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Account',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF2C3558)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8088A2), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    widget.onEditProfile();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5C7AE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.face_rounded, color: Color(0xFFB06B42)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF29324E)),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Premium member since 2025',
                                style: TextStyle(fontSize: 11, color: Color(0xFF8A91A8), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(color: Color(0xFF2E6AF5), shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Preferences'),
              _SettingsCard(
                child: _SettingsSwitchRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFF2E6AF5),
                  title: 'Push Notifications',
                  subtitle: 'Reminder at 9:00 AM and 6:15 PM',
                  value: pushNotifications,
                  onChanged: (value) => setState(() => pushNotifications = value),
                ),
              ),
              const SizedBox(height: 8),
              _SettingsCard(
                child: _SettingsChevronRow(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF8B4DE8),
                  title: 'Language',
                  subtitle: 'App localization',
                  value: 'English',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Security'),
              _SettingsCard(
                child: _SettingsChevronRow(
                  icon: Icons.lock_rounded,
                  iconColor: const Color(0xFFE36A6A),
                  title: 'Change Password',
                  subtitle: 'Last updated 5 months ago',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 8),
              _SettingsCard(
                child: _SettingsSwitchRow(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF2E6AF5),
                  title: 'Two-Factor Auth',
                  subtitle: 'Secure your health data',
                  value: twoFactor,
                  onChanged: (value) => setState(() => twoFactor = value),
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Support'),
              _SettingsCard(
                child: _SettingsChevronRow(
                  icon: Icons.help_rounded,
                  iconColor: const Color(0xFFB58D36),
                  title: 'Help Center',
                  subtitle: 'FAQs and documentation',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Подтверждение'),
                          content: const Text('Вы уверены, что хотите выйти?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Отмена'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD2212D), foregroundColor: Colors.white),
                              child: const Text('Выйти'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed == true && context.mounted) {
                      Navigator.of(context).pop();
                      widget.onLogout();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 50),
                    backgroundColor: const Color(0xFFD2212D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'APP VERSION: 1.0.0 (1001)',
                  style: TextStyle(fontSize: 9, color: Color(0xFF9CA2B7), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String label;

  const _SettingsSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 10, color: Color(0xFFA2A9BD), fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: child,
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _SettingsIcon(icon: icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2A3353))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF8A91A8), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF2E6AF5),
            inactiveTrackColor: const Color(0xFFC6CDDD),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _SettingsChevronRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback onTap;

  const _SettingsChevronRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            _SettingsIcon(icon: icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2A3353))),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF8A91A8), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (value != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7ECFF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  value!,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF2E6AF5), fontWeight: FontWeight.w700),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8690AB), size: 18),
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

String _goalLabel(GoalType goal) {
  switch (goal) {
    case GoalType.loseWeight:
      return 'Lose fat';
    case GoalType.maintain:
      return 'Maintain';
    case GoalType.gainWeight:
      return 'Gain muscle';
    case GoalType.trackOnly:
      return 'Just track';
  }
}

String _activityLabel(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary:
      return 'Sedentary';
    case ActivityLevel.lightlyActive:
      return 'Lightly active';
    case ActivityLevel.moderatelyActive:
      return 'Moderately active';
    case ActivityLevel.veryActive:
      return 'Very active';
    case ActivityLevel.athlete:
      return 'Very active';
  }
}

class _MealEntry {
  final String requestId;
  final MealOrigin origin;
  final String name;
  final DateTime day;
  final DateTime timestamp;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? portionG;
  final double confidence;
  final double per100Kcal;
  final double per100ProteinG;
  final double per100CarbsG;
  final double per100FatG;
  final MealType? userSelectedType;
  final MealType autoDetectedType;
  final MealType finalType;
  final MealSessionTier autoDetectedTier;
  final MealSessionTier finalTier;
  final String sessionId;

  const _MealEntry({
    required this.requestId,
    required this.origin,
    required this.name,
    required this.day,
    required this.timestamp,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.portionG,
    required this.confidence,
    required this.per100Kcal,
    required this.per100ProteinG,
    required this.per100CarbsG,
    required this.per100FatG,
    required this.userSelectedType,
    required this.autoDetectedType,
    required this.finalType,
    required this.autoDetectedTier,
    required this.finalTier,
    required this.sessionId,
  });

  String get time => _timeLabelFromDateTime(timestamp);
  MealType get mealType => finalType;
  String get title => mealTypeLabel(finalType);
  IconData get icon => mealTypeIcon(finalType);

  _MealEntry copyWith({
    String? requestId,
    MealOrigin? origin,
    String? name,
    DateTime? day,
    DateTime? timestamp,
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? portionG,
    bool clearPortionG = false,
    double? confidence,
    double? per100Kcal,
    double? per100ProteinG,
    double? per100CarbsG,
    double? per100FatG,
    MealType? userSelectedType,
    bool clearUserSelectedType = false,
    MealType? autoDetectedType,
    MealType? finalType,
    MealSessionTier? autoDetectedTier,
    MealSessionTier? finalTier,
    String? sessionId,
  }) {
    return _MealEntry(
      requestId: requestId ?? this.requestId,
      origin: origin ?? this.origin,
      name: name ?? this.name,
      day: day ?? this.day,
      timestamp: timestamp ?? this.timestamp,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      portionG: clearPortionG ? null : (portionG ?? this.portionG),
      confidence: confidence ?? this.confidence,
      per100Kcal: per100Kcal ?? this.per100Kcal,
      per100ProteinG: per100ProteinG ?? this.per100ProteinG,
      per100CarbsG: per100CarbsG ?? this.per100CarbsG,
      per100FatG: per100FatG ?? this.per100FatG,
      userSelectedType: clearUserSelectedType ? null : (userSelectedType ?? this.userSelectedType),
      autoDetectedType: autoDetectedType ?? this.autoDetectedType,
      finalType: finalType ?? this.finalType,
      autoDetectedTier: autoDetectedTier ?? this.autoDetectedTier,
      finalTier: finalTier ?? this.finalTier,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'origin': origin.name,
    'name': name,
    'day': day.toIso8601String(),
    'timestamp': timestamp.toIso8601String(),
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'portionG': portionG,
    'confidence': confidence,
    'per100Kcal': per100Kcal,
    'per100ProteinG': per100ProteinG,
    'per100CarbsG': per100CarbsG,
    'per100FatG': per100FatG,
    'userSelectedType': userSelectedType?.name,
    'autoDetectedType': autoDetectedType.name,
    'finalType': finalType.name,
    'autoDetectedTier': autoDetectedTier.name,
    'finalTier': finalTier.name,
    'sessionId': sessionId,
  };

  static _MealEntry? fromJson(Map<String, dynamic> json) {
    final origin = _enumByNameMain(MealOrigin.values, json['origin'] as String?);
    if (origin == null) return null;

    final legacyMealType = _enumByNameMain(MealType.values, json['mealType'] as String?);
    final userSelectedType = _enumByNameMain(MealType.values, json['userSelectedType'] as String?);
    final autoDetectedType = _enumByNameMain(MealType.values, json['autoDetectedType'] as String?) ?? legacyMealType ?? MealType.snack;
    final finalType = _enumByNameMain(MealType.values, json['finalType'] as String?) ?? legacyMealType ?? autoDetectedType;
    final autoDetectedTier =
        _enumByNameMain(MealSessionTier.values, json['autoDetectedTier'] as String?) ?? MealSessionTier.extra;
    final finalTier = _enumByNameMain(MealSessionTier.values, json['finalTier'] as String?) ?? autoDetectedTier;
    final day = DateTime.tryParse((json['day'] as String?) ?? '') ?? DateTime.now();
    final parsedTimestamp = DateTime.tryParse((json['timestamp'] as String?) ?? '');
    final legacyTime = (json['time'] as String?) ?? '';
    final timestamp = parsedTimestamp ?? _timestampFromDayAndTime(day, legacyTime);

    return _MealEntry(
      requestId: (json['requestId'] as String?) ?? '',
      origin: origin,
      name: (json['name'] as String?) ?? '',
      day: _dateOnly(day),
      timestamp: timestamp,
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
      portionG: (json['portionG'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      per100Kcal: (json['per100Kcal'] as num?)?.toDouble() ?? 0,
      per100ProteinG: (json['per100ProteinG'] as num?)?.toDouble() ?? 0,
      per100CarbsG: (json['per100CarbsG'] as num?)?.toDouble() ?? 0,
      per100FatG: (json['per100FatG'] as num?)?.toDouble() ?? 0,
      userSelectedType: userSelectedType,
      autoDetectedType: autoDetectedType,
      finalType: finalType,
      autoDetectedTier: autoDetectedTier,
      finalTier: finalTier,
      sessionId: (json['sessionId'] as String?) ?? '',
    );
  }
}

String _sexLabel(SexType sex) {
  switch (sex) {
    case SexType.male:
      return 'Male';
    case SexType.female:
      return 'Female';
  }
}

Map<String, dynamic> _encodeOnboardingResult(OnboardingResult result) {
  return {
    'goalType': result.goalType.name,
    'sex': result.sex.name,
    'age': result.age,
    'heightCm': result.heightCm,
    'weightKg': result.weightKg,
    'activityLevel': result.activityLevel.name,
    'targetPace': result.targetPace.name,
    'macroProfile': result.macroProfile.name,
    'plan': {
      'calorieTarget': result.plan.calorieTarget,
      'proteinTargetG': result.plan.proteinTargetG,
      'fatTargetG': result.plan.fatTargetG,
      'carbsTargetG': result.plan.carbsTargetG,
    },
  };
}

@visibleForTesting
OnboardingResult? decodeOnboardingResultForTest(String? raw) => _decodeOnboardingResult(raw);

OnboardingResult? _decodeOnboardingResult(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;
    final goalType = _enumByNameMain(GoalType.values, json['goalType'] as String?) ?? GoalType.maintain;
    final sex = _enumByNameMain(SexType.values, json['sex'] as String?) ?? SexType.male;
    final activityLevel = _enumByNameMain(ActivityLevel.values, json['activityLevel'] as String?) ?? ActivityLevel.moderatelyActive;
    final fallbackPace = switch (goalType) {
      GoalType.loseWeight => TargetPace.balanced,
      GoalType.gainWeight => TargetPace.leanBulk,
      GoalType.maintain || GoalType.trackOnly => TargetPace.maintain,
    };
    final targetPace = _enumByNameMain(TargetPace.values, json['targetPace'] as String?) ?? fallbackPace;
    final macroProfile = _enumByNameMain(MacroProfile.values, json['macroProfile'] as String?) ?? MacroProfile.balanced;
    final age = (json['age'] as num?)?.toInt() ?? 30;
    final heightCm = (json['heightCm'] as num?)?.toDouble() ?? 170;
    final weightKg = (json['weightKg'] as num?)?.toDouble() ?? 70;
    final planJson = json['plan'] as Map<String, dynamic>?;
    final fallbackPlan = calculateNutritionPlan(
      goalType: goalType,
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      pace: targetPace,
      macroProfile: macroProfile,
    );
    final plan = planJson == null
        ? fallbackPlan
        : NutritionPlan(
            calorieTarget: (planJson['calorieTarget'] as num?)?.toInt() ?? fallbackPlan.calorieTarget,
            proteinTargetG: (planJson['proteinTargetG'] as num?)?.toInt() ?? fallbackPlan.proteinTargetG,
            fatTargetG: (planJson['fatTargetG'] as num?)?.toInt() ?? fallbackPlan.fatTargetG,
            carbsTargetG: (planJson['carbsTargetG'] as num?)?.toInt() ?? fallbackPlan.carbsTargetG,
          );
    return OnboardingResult(
      goalType: goalType,
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      targetPace: targetPace,
      macroProfile: macroProfile,
      plan: plan,
    );
  } catch (_) {
    return null;
  }
}

OnboardingDraft? _decodeOnboardingDraft(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;
    return OnboardingDraft.fromJson(json);
  } catch (_) {
    return null;
  }
}

List<_MealEntry> _decodeMeals(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final json = jsonDecode(raw);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(_MealEntry.fromJson)
        .whereType<_MealEntry>()
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

T? _enumByNameMain<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
class _DayItem {
  final String weekDay;
  final String dayNum;
  final DateTime date;

  const _DayItem({required this.weekDay, required this.dayNum, required this.date});
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'MON';
    case DateTime.tuesday:
      return 'TUE';
    case DateTime.wednesday:
      return 'WED';
    case DateTime.thursday:
      return 'THU';
    case DateTime.friday:
      return 'FRI';
    case DateTime.saturday:
      return 'SAT';
    default:
      return 'SUN';
  }
}

String _timeLabelFromDateTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

DateTime _timestampFromDayAndTime(DateTime day, String timeLabel) {
  final parts = timeLabel.split(':');
  if (parts.length == 2) {
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours != null && minutes != null && hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60) {
      return DateTime(day.year, day.month, day.day, hours, minutes);
    }
  }
  return day;
}

class _NumberBlock extends StatelessWidget {
  final String label;
  final String main;
  final String sub;
  final bool alignEnd;
  final bool light;

  const _NumberBlock({required this.label, required this.main, required this.sub, required this.alignEnd, required this.light});

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : const Color(0xFF111322);
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(main, style: TextStyle(color: color, fontSize: 42, fontWeight: FontWeight.w700)),
        Text(sub, style: TextStyle(color: color.withValues(alpha: 0.95), fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color amountColor;
  final String goal;
  final String left;
  final double value;

  const _MacroCard({required this.title, required this.amount, required this.amountColor, required this.goal, required this.left, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE9EBF2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293))),
          const SizedBox(height: 4),
          Text(amount, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: amountColor)),
          Text(goal, style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293))),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(height: 6, child: LinearProgressIndicator(value: value, backgroundColor: const Color(0xFFD7D9DE), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF111322)))),
          ),
          const SizedBox(height: 8),
          Text(left, style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293))),
        ],
      ),
    );
  }
}

class _CategorySectionModel {
  final MealType type;
  final double goalKcal;
  final double consumedKcal;
  final List<MealSession> mainSessions;
  final List<MealSession> extraSessions;
  final List<MealSession> snackSessions;

  const _CategorySectionModel({
    required this.type,
    required this.goalKcal,
    required this.consumedKcal,
    required this.mainSessions,
    required this.extraSessions,
    required this.snackSessions,
  });
}

class _LatestAddedMealCard extends StatelessWidget {
  final _MealEntry? meal;
  final VoidCallback? onTap;

  const _LatestAddedMealCard({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = meal == null
        ? const Column(
            key: Key('latest-added-empty'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latest Added', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              SizedBox(height: 4),
              Text('No meals for this day yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Add a meal to see it here.', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            ],
          )
        : Column(
            key: const Key('latest-added-filled'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Latest Added', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 4),
              Text(meal!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    mealTypeLabel(meal!.finalType),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Text(_timeLabelFromDateTime(meal!.timestamp), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  const Spacer(),
                  Text('${meal!.kcal.toStringAsFixed(0)} kcal', style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          );

    return InkWell(
      key: const Key('latest-added-card'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D111827),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

class _CategorySectionCard extends StatelessWidget {
  final _CategorySectionModel model;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onTapMeal;

  const _CategorySectionCard({
    required this.model,
    required this.expanded,
    required this.onToggle,
    required this.onTapMeal,
  });

  String _typeKey(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snacks';
    }
  }

  Widget _buildSessionList(List<MealSession> sessions) {
    return Column(
      children: List.generate(sessions.length, (index) {
        final session = sessions[index];
        return Container(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          decoration: BoxDecoration(
            border: index == 0
                ? null
                : const Border(
                    top: BorderSide(color: Color(0xFF4B5563)),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_timeLabelFromDateTime(session.startTime)}-${_timeLabelFromDateTime(session.endTime)} • ${session.totalKcal.toStringAsFixed(0)} kcal',
                style: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...session.entries.map(
                (entry) => InkWell(
                  key: Key('category-entry-${entry.id}'),
                  onTap: () => onTapMeal(entry.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeLabelFromDateTime(entry.timestamp),
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.kcal.toStringAsFixed(0)} kcal',
                          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keySuffix = _typeKey(model.type);
    return Container(
      key: Key('category-card-$keySuffix'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F37), Color(0xFF1E2229)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4B5563), width: 1.1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6B7280)),
                    ),
                    child: Icon(mealTypeIcon(model.type), color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              model.type == MealType.snack ? 'Snacks' : mealTypeLabel(model.type),
                              style: const TextStyle(
                                fontSize: 31 / 1.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              expanded ? Icons.keyboard_arrow_down : Icons.arrow_forward,
                              color: const Color(0xFFD1D5DB),
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${model.consumedKcal.toStringAsFixed(0)} / ${model.goalKcal.toStringAsFixed(0)} Cal',
                          key: Key('category-kcal-$keySuffix'),
                          style: const TextStyle(
                            fontSize: 17 / 1.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              key: Key('category-content-$keySuffix'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: (model.mainSessions.isEmpty && model.extraSessions.isEmpty && model.snackSessions.isEmpty)
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 4),
                      child: Text('No sessions yet', style: TextStyle(color: Color(0xFF9CA3AF))),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (model.type == MealType.snack) ...[
                          _buildSessionList(model.snackSessions),
                        ] else ...[
                          if (model.mainSessions.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 6, bottom: 4),
                              child: Text(
                                'Main meal',
                                key: Key('main-meal-section-title'),
                                style: TextStyle(color: Color(0xFFE5E7EB), fontWeight: FontWeight.w700),
                              ),
                            ),
                            _buildSessionList(model.mainSessions),
                          ],
                          if (model.extraSessions.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 6, bottom: 4),
                              child: Text(
                                'Extras',
                                key: Key('extras-section-title'),
                                style: TextStyle(color: Color(0xFFE5E7EB), fontWeight: FontWeight.w700),
                              ),
                            ),
                            _buildSessionList(model.extraSessions),
                          ],
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2B66F6) : const Color(0xFF8E92A3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}


















































