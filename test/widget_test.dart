import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_new_app/main.dart';
import 'package:my_new_app/photo_food/controller.dart';
import 'package:my_new_app/photo_food/models.dart';
import 'package:my_new_app/photo_food/photo_picker.dart';
import 'package:my_new_app/photo_food/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tap + opens source bottom sheet', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets('requires confirmation opens portion bottom sheet', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(requiresConfirmation: true),
      photoPicker: _FakePicker(file: XFile('fake.jpg')),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('portion-sheet')), findsOneWidget);
    expect(find.byKey(const Key('portion-input')), findsOneWidget);
    expect(find.byKey(const Key('portion-use-ai-estimate')), findsOneWidget);
  });

  testWidgets('not sure action confirms portion using ai estimate', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(requiresConfirmation: true),
      photoPicker: _FakePicker(file: XFile('fake.jpg')),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('portion-use-ai-estimate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('portion-sheet')), findsNothing);
    expect(controller.state.status, HomeStatus.loaded);
    expect(controller.state.response?.meta.portionBasis, 'ai_estimate_confirmed');
  });

  testWidgets('onboarding back from Goal returns to Welcome', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Track calories from food photos'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text("What's your goal?"), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.text('Track calories from food photos'), findsOneWidget);
  });

  testWidgets('onboarding back from Result returns to Macro step', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Basic profile').evaluate().isNotEmpty) {
      await tester.tap(find.text('Male'));
      await tester.enterText(find.widgetWithText(TextField, 'Age'), '24');
      await tester.enterText(find.widgetWithText(TextField, 'Height, cm'), '178');
      await tester.enterText(find.widgetWithText(TextField, 'Weight, kg'), '82');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Activity level').evaluate().isNotEmpty) {
      await tester.tap(find.text('Moderately active'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Choose your pace').evaluate().isNotEmpty) {
      await tester.tap(find.text('Balanced').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Macro preference').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Your plan is ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.text('Macro preference'), findsOneWidget);
  });

  testWidgets('onboarding profile shows e.g. placeholders', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Basic profile'), findsOneWidget);
    expect(find.text('e.g. 24'), findsOneWidget);
    expect(find.text('e.g. 178'), findsOneWidget);
    expect(find.text('e.g. 82'), findsOneWidget);
  });

  testWidgets('onboarding profile validates new height and weight ranges', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Basic profile'), findsOneWidget);
    await tester.tap(find.text('Male'));
    await tester.enterText(find.widgetWithText(TextField, 'Age'), '24');
    await tester.enterText(find.widgetWithText(TextField, 'Height, cm'), '60');
    await tester.enterText(find.widgetWithText(TextField, 'Weight, kg'), '82');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Height must be between 70 and 220 cm.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Height, cm'), '178');
    await tester.enterText(find.widgetWithText(TextField, 'Weight, kg'), '20');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Weight must be between 30 and 250 kg.'), findsOneWidget);
  });

  testWidgets('home shows latest card and 4 category sections on empty day', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('latest-added-card')), findsOneWidget);
    expect(find.byKey(const Key('latest-added-empty')), findsOneWidget);
    expect(find.byKey(const Key('category-card-breakfast')), findsOneWidget);
    expect(find.byKey(const Key('category-card-lunch')), findsOneWidget);
    expect(find.byKey(const Key('category-card-dinner')), findsOneWidget);
    expect(find.byKey(const Key('category-card-snacks')), findsOneWidget);
  });

  testWidgets('latest card uses selected day and category entry opens details', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'CategoryTapMeal');
    await tester.enterText(fields.at(1), '420');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '24');
    await tester.enterText(fields.at(4), '12');
    await tester.enterText(fields.at(5), '40');
    await tester.tap(find.byKey(const Key('meal-type-lunch')));
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('latest-added-filled')), findsOneWidget);
    expect(find.text('CategoryTapMeal'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('category-card-lunch')));
    await tester.tap(find.byKey(const Key('category-card-lunch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-content-lunch')), findsOneWidget);

    final entryFinder = find.descendant(
      of: find.byKey(const Key('category-content-lunch')),
      matching: find.text('CategoryTapMeal'),
    );
    await tester.tap(entryFinder.first);
    await tester.pumpAndSettle();
    expect(find.text('Meal type: Lunch'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('day-chip-0')));
    await tester.tap(find.byKey(const Key('day-chip-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('latest-added-empty')), findsOneWidget);
  });

  testWidgets('lunch category splits sessions into Main meal and Extras', (tester) async {
    final today = DateTime.now();
    final dayOnly = DateTime(today.year, today.month, today.day);

    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        {
          'requestId': 'lunch_main',
          'origin': 'manual',
          'name': 'LunchMainMeal',
          'day': dayOnly.toIso8601String(),
          'timestamp': DateTime(dayOnly.year, dayOnly.month, dayOnly.day, 13, 0).toIso8601String(),
          'kcal': 420.0,
          'proteinG': 28.0,
          'carbsG': 35.0,
          'fatG': 14.0,
          'portionG': 250.0,
          'confidence': 1.0,
          'per100Kcal': 168.0,
          'per100ProteinG': 11.2,
          'per100CarbsG': 14.0,
          'per100FatG': 5.6,
          'userSelectedType': 'lunch',
          'autoDetectedType': 'lunch',
          'finalType': 'lunch',
          'autoDetectedTier': 'mainMeal',
          'finalTier': 'mainMeal',
          'sessionId': 'session_a',
        },
        {
          'requestId': 'lunch_extra',
          'origin': 'manual',
          'name': 'LunchExtraMeal',
          'day': dayOnly.toIso8601String(),
          'timestamp': DateTime(dayOnly.year, dayOnly.month, dayOnly.day, 14, 0).toIso8601String(),
          'kcal': 120.0,
          'proteinG': 2.0,
          'carbsG': 27.0,
          'fatG': 1.0,
          'portionG': 120.0,
          'confidence': 1.0,
          'per100Kcal': 100.0,
          'per100ProteinG': 1.7,
          'per100CarbsG': 22.5,
          'per100FatG': 0.8,
          'userSelectedType': 'lunch',
          'autoDetectedType': 'lunch',
          'finalType': 'lunch',
          'autoDetectedTier': 'extra',
          'finalTier': 'extra',
          'sessionId': 'session_b',
        },
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('category-card-lunch')));
    await tester.tap(find.byKey(const Key('category-card-lunch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-content-lunch')), findsOneWidget);
    expect(find.byKey(const Key('main-meal-section-title')), findsOneWidget);
    expect(find.byKey(const Key('extras-section-title')), findsOneWidget);
    expect(find.text('LunchMainMeal'), findsWidgets);
    expect(find.text('LunchExtraMeal'), findsWidgets);

    final snackKcal = find.descendant(
      of: find.byKey(const Key('category-card-snacks')),
      matching: find.byKey(const Key('category-kcal-snacks')),
    );
    expect(snackKcal, findsOneWidget);
    final snackKcalText = tester.widget<Text>(snackKcal).data ?? '';
    expect(snackKcalText, contains('0 /'));
  });


  testWidgets('activity step has 4 options without athlete', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Basic profile').evaluate().isNotEmpty) {
      await tester.tap(find.text('Male'));
      await tester.enterText(find.widgetWithText(TextField, 'Age'), '24');
      await tester.enterText(find.widgetWithText(TextField, 'Height, cm'), '178');
      await tester.enterText(find.widgetWithText(TextField, 'Weight, kg'), '82');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Activity level'), findsOneWidget);
    expect(find.text('Sedentary'), findsOneWidget);
    expect(find.text('Lightly active'), findsOneWidget);
    expect(find.text('Moderately active'), findsOneWidget);
    expect(find.text('Light workouts 1-2 times/week'), findsOneWidget);
    expect(find.text('Athlete'), findsNothing);
  });



  testWidgets('restores completed onboarding result on cold start', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    SharedPreferences.setMockInitialValues({
      'app.onboarding.result': jsonEncode({
        'goalType': 'loseWeight',
        'sex': 'male',
        'age': 28,
        'heightCm': 180.0,
        'weightKg': 82.0,
        'activityLevel': 'lightlyActive',
        'targetPace': 'balanced',
        'macroProfile': 'balanced',
        'plan': {
          'calorieTarget': 2200,
          'proteinTargetG': 150,
          'fatTargetG': 65,
          'carbsTargetG': 240,
        },
      }),
    });

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fab-add')), findsOneWidget);
    expect(find.text('Track calories from food photos'), findsNothing);
  });

  testWidgets('restores onboarding draft step when result is missing', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    SharedPreferences.setMockInitialValues({
      'app.onboarding.draft': jsonEncode({
        'step': 2,
        'goalType': 'loseWeight',
        'sexType': 'male',
        'activityLevel': null,
        'targetPace': null,
        'macroProfile': 'balanced',
        'heightUnit': 'cm',
        'weightUnit': 'kg',
        'ageText': '24',
        'heightText': '178',
        'feetText': '',
        'inchesText': '',
        'weightText': '82',
      }),
    });

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Basic profile'), findsOneWidget);
    expect(find.text('Track calories from food photos'), findsNothing);
  });

  testWidgets('editing meal grams recalculates kcal and macros proportionally', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test Meal');
    await tester.enterText(fields.at(1), '250');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Test Meal'));
    await tester.tap(find.text('Test Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(2), '100');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Test Meal'));
    await tester.tap(find.text('Test Meal'));
    await tester.pumpAndSettle();
    expect(find.text('Calories: 100.0 kcal'), findsOneWidget);
    expect(find.text('Protein: 10.0 g'), findsOneWidget);
    expect(find.text('Fat: 4.0 g'), findsOneWidget);
    expect(find.text('Carbs: 12.0 g'), findsOneWidget);
  });
  testWidgets('manual meal sheet shows redesigned meal type cards', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller, skipOnboarding: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    expect(find.text('Add Meal'), findsWidgets);
    expect(find.text('Meal Type'), findsOneWidget);
    expect(find.byKey(const Key('meal-type-breakfast')), findsOneWidget);
    expect(find.byKey(const Key('meal-type-lunch')), findsOneWidget);
    expect(find.byKey(const Key('meal-type-dinner')), findsOneWidget);
    expect(find.byKey(const Key('meal-type-snack')), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal-type-lunch')));
    await tester.pumpAndSettle();
  });
}

class _FakePicker implements PhotoPicker {
  final XFile? file;

  _FakePicker({required this.file});

  @override
  Future<XFile?> pick(PickSource source) async => file;
}

class _FakeRepository implements PhotoFoodRepository {
  final bool requiresConfirmation;

  _FakeRepository({this.requiresConfirmation = false});

  @override
  Future<PhotoFoodResponse> analyzePhoto(XFile image, {String locale = 'ru-RU', String? mealTime}) async {
    return PhotoFoodResponse(
      requestId: 'req_123',
      item: const Item(
        name: 'Oatmeal with berries',
        category: 'breakfast',
        foodType: 'solid',
        confidence: 0.92,
        nutritionPer100g: NutritionPer100g(kcal: 120, proteinG: 4, fatG: 3, carbsG: 18),
        warnings: [],
      ),
      uiFlags: UiFlags(
        requiresUserConfirmation: requiresConfirmation,
        highlightLevel: requiresConfirmation ? 'orange' : 'none',
      ),
      meta: Meta(
        needsConfirmation: requiresConfirmation,
        estimatedPortionG: requiresConfirmation ? 240 : 250,
        portionBasis: requiresConfirmation ? 'visual estimate' : 'model',
        confirmationSource: null,
        totalsAreEstimate: true,
        estimatedTotals: const EstimatedTotals(kcal: 300, proteinG: 10, fatG: 8, carbsG: 45),
      ),
    );
  }

  @override
  Future<PhotoFoodResponse> confirmPortion({required String requestId, double? portionG, bool useAiEstimate = false}) async {
    final confirmed = useAiEstimate ? 240.0 : (portionG ?? 0.0);
    return PhotoFoodResponse(
      requestId: requestId,
      item: const Item(
        name: 'Oatmeal with berries',
        category: 'breakfast',
        foodType: 'solid',
        confidence: 0.92,
        nutritionPer100g: NutritionPer100g(kcal: 120, proteinG: 4, fatG: 3, carbsG: 18),
        warnings: [],
      ),
      uiFlags: const UiFlags(requiresUserConfirmation: false, highlightLevel: 'none'),
      meta: Meta(
        needsConfirmation: false,
        estimatedPortionG: confirmed,
        portionBasis: useAiEstimate ? 'ai_estimate_confirmed' : 'user_confirmed',
        confirmationSource: useAiEstimate ? 'ai_estimate' : 'user_input',
        totalsAreEstimate: true,
        estimatedTotals: EstimatedTotals(
          kcal: confirmed * 1.2,
          proteinG: confirmed * 0.04,
          fatG: confirmed * 0.03,
          carbsG: confirmed * 0.18,
        ),
      ),
    );
  }
}






