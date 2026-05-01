# my_new_app

Flutter calorie tracking app with onboarding-based nutrition targets, AI photo analysis, manual meal logging, and session-based meal history.

## What is implemented now
- Multi-step onboarding with saved draft and persisted final result.
- Home dashboard with:
  - daily calorie progress
  - macro progress (protein/carbs/fat)
  - latest added meal card
  - history grouped into Breakfast/Lunch/Dinner/Snacks
- Add meal flow:
  - camera photo -> AI analysis
  - gallery photo -> AI analysis
  - full manual add form (including meal type selection)
- Portion confirmation flow when backend asks for user confirmation.
- Meal edit/delete flow with realtime auto-calc, session-scoped locks, unlock/reset controls, and locked-calories conflict confirmation.
- Local persistence for onboarding + meals via `SharedPreferences`.

## Tech stack
- Flutter (Material 3)
- Dart SDK `^3.11.0`
- Packages:
  - `http`, `http_parser`, `mime` (API/multipart)
  - `image_picker` (camera/gallery)
  - `shared_preferences` (local persistence)

## Project structure
- `lib/main.dart` - app bootstrap, shell, home/meal UI, persistence orchestration, and manual meal sheet flow
- `lib/meal_edit_draft.dart` - extracted meal edit draft math and lock/conflict logic as a `part` of `main.dart`
- `lib/profile/` - profile tab, account settings screens, and shared profile labels
- `lib/onboarding.dart` - onboarding state, UI steps, nutrition calculations
- `lib/meal_type.dart` - meal type enum + labels/icons + boundary classification
- `lib/meal_session.dart` - session grouping, auto classification, tier logic, override resolution
- `lib/app_config.dart` - runtime config from dart defines
- `lib/photo_food/` - API client, repository contract, controller state machine, models, picker abstraction, error mapping
- `test/` - unit + widget tests for key behavior
- `docs/MEAL_EDIT_AUTO_CALC.md` - detailed rules for manual meal add/edit nutrition synchronization

## Current timeline/session logic

### Time windows
- Breakfast: `04:00 - 10:29`
- Lunch: `10:30 - 16:29`
- Dinner: `16:30 - 23:29`
- Snack: `23:30 - 03:59`

### Session grouping
- Meals are grouped into a single session when adjacent entries are no more than `15 minutes` apart.
- Otherwise, a new session is created.

### Session tiering
- For breakfast/lunch/dinner, session kcal is compared to dynamic thresholds from daily target.
- Tier is:
  - `mainMeal` if threshold reached
  - `extra` if below threshold
- Snacks are always `extra`.

### Sorting and rendering order
- Selected-day sessions are sorted by newest `startTime` first.
- Category cards always appear in this fixed order:
  - Breakfast -> Lunch -> Dinner -> Snacks
- Inside each category, sessions are also sorted newest first.
- `Latest Added` card is based on selected-day meals sorted by newest `timestamp`.

## API contract used by app
- `POST /v0/ai/photo-food`
  - multipart upload (`image`)
  - `locale` (`ru-RU` currently)
  - optional `meal_time`
- `POST /v0/ai/photo-food/confirm-portion`
  - JSON: `request_id`, `portion_g`

Authentication and config:
- Request header: `X-API-Key`
- Required runtime defines:
  - `API_BASE_URL`
  - `API_KEY`

Client constraints:
- max image size: `8 MB`
- accepted types: `image/jpeg`, `image/png`, `image/webp`
- request timeout: `25 seconds`

## Persistence details
- `app.onboarding.result` - final onboarding output
- `app.onboarding.draft` - current onboarding step/draft
- `app.meals` - serialized local meal entries with session metadata

## Run locally
```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://<backend-host>:8000 \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

## Build and deploy (current process)
Deployment is currently manual from the Flutter CLI.

### Android release artifact
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<backend-host> \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

### iOS release artifact
```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://<backend-host> \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

Current operational model:
- Frontend artifacts are built per environment (dev/stage/prod) by passing different `API_BASE_URL` and `API_KEY` values.
- Backend is deployed independently and must keep the same endpoint contract.
- No CI/CD deployment pipeline is configured inside this repo yet.

## Test
```bash
flutter test
```
