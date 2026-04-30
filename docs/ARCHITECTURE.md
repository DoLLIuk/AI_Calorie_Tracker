# Current Architecture

## 1) Scope and Repositories
- Frontend app (this repository): `C:\Users\golov\develop\my_new_app`
- Backend API used by frontend: configurable via `API_BASE_URL` (FastAPI service, currently integrated through `/v0/ai/photo-food` endpoints)

## 2) Runtime Architecture (Frontend)

### App bootstrap and state hydration
- Entry point: `lib/main.dart`
- `MyApp` creates or receives `PhotoFoodController`, then hydrates persisted state from `SharedPreferences`.
- Persisted keys:
  - `app.onboarding.result`
  - `app.onboarding.draft`
  - `app.meals`
- App gate logic:
  - If hydration is not finished: bootstrap loading screen.
  - If onboarding is completed (or `skipOnboarding == true`): open app shell.
  - Otherwise: open onboarding flow.

### App shell and navigation
- `_AppShell` uses `IndexedStack` with two tabs:
  - Home (`_CaloriesHomePage`)
  - Profile (`ProfilePage`)
- FAB is active on Home only and opens add-flow actions:
  - Take photo
  - Choose from gallery
  - Add manually

### Domains and modules
- `lib/meal_type.dart`:
  - `MealType` enum (`breakfast`, `lunch`, `dinner`, `snack`)
  - time-based classification helpers
  - labels/icons used by UI
- `lib/meal_session.dart`:
  - session model, thresholds, and session builder service
  - session tier classification (`mainMeal` vs `extra`)
  - user override support for final category
- `lib/photo_food/*`:
  - API DTO models
  - API client (`http` multipart + JSON requests)
  - controller state machine
  - picker abstraction
  - repository interface
- Manual meal add/edit nutrition sync:
  - currently implemented locally in `lib/main.dart`
  - `_MealFormDraft` is the state/calculation helper for realtime manual meal editing
  - see `docs/MEAL_EDIT_AUTO_CALC.md` for the exact product rules and edge cases
- `lib/onboarding.dart`:
  - multi-step onboarding flow
  - profile validation
  - nutrition plan calculations

## 3) Current Meal Timeline and Sorting Logic

### Time-of-day classification windows (current)
Used by `classifyMealTypeByTime` and `classifyMainMealByStartTime`:
- Breakfast: `04:00 - 10:29`
- Lunch: `10:30 - 16:29`
- Dinner: `16:30 - 23:29`
- Snack: `23:30 - 03:59`

### Sessionization
- Meals for a selected day are grouped into sessions using a rolling gap rule:
  - If the next meal is within `15 minutes` of the previous one, it stays in the same session.
  - Otherwise, a new session starts.
- Session totals are aggregated (`kcal`, `protein`, `fat`, `carbs`).

### Auto type and tier assignment
- Session auto type is derived from session start time window.
- Session tier is based on calorie thresholds relative to daily target:
  - Breakfast threshold: `clamp(dailyTarget * 0.10, 220, 300)`
  - Lunch threshold: `clamp(dailyTarget * 0.18, 350, 350)`
  - Dinner threshold: `clamp(dailyTarget * 0.20, 400, 400)`
  - Snack is always `extra`
- Below threshold => `extra`, otherwise => `mainMeal`.

### User override behavior
- Any meal can carry `userSelectedType`.
- For a session, the latest entry with manual selection wins.
- Final category (`finalType`) is override if present, otherwise auto type.
- In the home model sync, session metadata is re-applied to each meal:
  - `sessionId`
  - `autoDetectedType`
  - `autoDetectedTier`
  - `finalType`
  - `finalTier`

### Sorting and UI ordering (current)
- Selected-day sessions are sorted by `startTime` descending (latest first).
- Category cards are rendered in fixed business order:
  - Breakfast -> Lunch -> Dinner -> Snacks
- Inside each category, sessions are sorted by `startTime` descending.
- For non-snack categories, sessions are split into sections:
  - `Main meal`
  - `Extras`
- Latest added meal card uses selected-day meals sorted by `timestamp` descending.

## 4) API Integration

### Authentication and config
- Runtime config source: `lib/app_config.dart`
- Required `--dart-define` values:
  - `API_BASE_URL`
  - `API_KEY`
- API key is sent as header: `X-API-Key: <API_KEY>`

### Endpoints used
- `POST /v0/ai/photo-food`
  - multipart field `image`
  - `locale` currently set to `ru-RU`
  - optional `meal_time`
- `POST /v0/ai/photo-food/confirm-portion`
  - JSON body: `request_id`, `portion_g`

### Network constraints and validation
- Allowed file types: `jpeg`, `png`, `webp`
- Max file size: `8 MB`
- Timeout: `25s`
- Client maps API/network errors to user-facing messages via `mapErrorCodeToMessage`.

## 5) Persistence Model
- Onboarding result and draft are persisted between restarts.
- Meals are persisted as serialized `_MealEntry` records.
- During decode, legacy fallback for meal type fields is preserved for compatibility.

## 6) Onboarding Output Usage
- `OnboardingResult.plan` drives:
  - daily calorie target for home progress
  - macro targets in cards and summaries
  - profile summary display

## 7) Test Coverage (Current Focus)
- Meal type boundary classification tests
- Session grouping and tiering tests
- Manual override behavior tests
- Widget tests for onboarding flow, latest card, category sections, and add/edit interactions
- API parsing and validation tests

## 8) Launch and Deployment (Current)

### Local/dev run
```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://<backend-host>:8000 \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

### Device/QA build examples
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<backend-host> \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>

flutter build ios --release \
  --dart-define=API_BASE_URL=https://<backend-host> \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

### Current deployment model
- Frontend is built and distributed as standard Flutter app artifacts (manual `flutter build` flow).
- Backend is deployed separately and must expose the `/v0/ai/photo-food` API contract.
- No frontend CI/CD pipeline is defined in this repository at the moment.
