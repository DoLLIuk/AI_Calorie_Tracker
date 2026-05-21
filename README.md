# my_new_app

A Flutter nutrition-tracking app built around one practical user experience: turn meal logging into a fast daily habit with onboarding-based nutrition targets, photo-assisted food entry, and session-aware history instead of a flat calorie list.

For the engineering and AI-agent reference, see [docs/agent_guide.md](docs/agent_guide.md).

## Why This Project Exists

Most calorie trackers make users do too much manual work before they get useful feedback. This project explores a tighter product loop:

- set a personalized calorie and macro target through onboarding
- log meals from a photo or a manual form
- resolve ambiguity only when needed
- show daily progress in a way that feels structured, not noisy

The product direction here is not “generic food diary.” It is a mobile nutrition experience that tries to reduce friction at the moment a user decides to log food.

## What It Does

- Personalized onboarding that calculates calorie and macro targets.
- Home dashboard with calorie progress, macro progress, coach-style guidance, and latest meal summary.
- Photo-based meal logging from camera or gallery.
- Clarification flow for ambiguous dishes before final analysis.
- Portion confirmation flow when the backend needs user input or an AI-estimate confirmation.
- Manual meal add/edit flow with realtime nutrition recalculation.
- Session-based history grouped into breakfast, lunch, dinner, and snacks.
- Local persistence for onboarding and meal data with `SharedPreferences`.

## Product Highlights

### Photo logging with practical ambiguity handling

The photo flow is not just “upload image -> show result.” The client supports a second clarification step for mixed or unclear dishes, then handles backend-driven portion confirmation when the estimate is uncertain.

That matters because it turns AI food recognition into a usable product flow instead of a single optimistic API call.

### Session-based meal history

Meals are grouped into sessions using time proximity and classified into meal categories with threshold-aware tiering. This gives the user a more interpretable day view than a raw chronological feed.

### Manual editing with structured nutrition logic

The manual meal form supports linked calories/macros behavior, session-scoped field locking, reset/restore flows, and conflict handling when user-entered values do not reconcile cleanly.

This is one of the most product-specific parts of the app and is covered by dedicated tests and documentation.

## Architecture Overview

This repository is the Flutter client. It owns:

- onboarding and nutrition-plan calculation
- app shell and UI
- local persistence
- meal sessionization and timeline logic
- manual meal editing behavior
- backend integration for photo-food analysis

The backend is a separate service and is used here as an API dependency, not embedded in this repository.

Core frontend flow:

`Onboarding -> nutrition targets -> meal logging -> local persistence -> session rebuild -> daily progress UI`

Photo flow:

`Camera/Gallery -> clarification (optional) -> backend analysis -> portion confirmation (optional) -> save meal -> refresh dashboard/history`

## Tech Stack

- Flutter
- Dart `^3.11.0`
- Material 3
- `http`, `http_parser`, `mime`
- `image_picker`
- `shared_preferences`

## Repository Structure

```text
lib/
  main.dart            app bootstrap, shell, home screen, add/edit meal flows
  onboarding.dart      onboarding UI and nutrition-plan calculation
  meal_session.dart    session grouping, thresholds, tiering, overrides
  meal_type.dart       meal classification by time window
  home_coach.dart      coach-card heuristics and messaging
  photo_food/          API client, models, controller, repository abstractions
  profile/             profile and account/settings screens
docs/
  agent_guide.md       canonical engineering + AI-agent reference
  MEAL_EDIT_AUTO_CALC.md
test/
  widget and unit tests for key product behavior
```

## API Integration

The app currently integrates with a separate backend through:

- `POST /v0/ai/photo-food`
- `POST /v0/ai/photo-food/confirm-portion`

Auth/config used by the client:

- header: `X-API-Key`
- compile-time config:
  - `API_BASE_URL`
  - `API_KEY`

## Setup

Prerequisites:

- Flutter SDK
- a running compatible backend for photo-food analysis
- values for `API_BASE_URL` and `API_KEY`

Run locally:

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://<backend-host>:8000 \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

Build examples:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<backend-host> \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>

flutter build ios --release \
  --dart-define=API_BASE_URL=https://<backend-host> \
  --dart-define=API_KEY=<PHOTO_FOOD_API_KEY>
```

## Validation

```bash
flutter test
```

The current test coverage focuses on:

- onboarding behavior
- meal-type boundaries
- session grouping and override behavior
- API parsing and validation
- clarification and portion-confirmation flows
- manual meal auto-calc and lock behavior

## Current Limitations

- Photo analysis depends on a separate backend service.
- API configuration is passed through `--dart-define` values at build/run time.
- A large amount of orchestration and UI logic still lives in `lib/main.dart`.
- Persistence is local-only and uses `SharedPreferences`, not a richer local database.
- Deployment is currently a manual Flutter build flow with no CI/CD pipeline in this repo.
- Some profile surfaces are presentational rather than fully backed by real historical analytics.

## Why This Repo Is Worth Reviewing

This project is strongest as an example of product-minded frontend engineering:

- translating uncertain AI/backend behavior into a usable client flow
- building non-trivial stateful UX in Flutter
- encoding real product rules in testable local logic
- balancing quick iteration with enough structure to keep features evolving

It is especially relevant for roles involving:

- Flutter or mobile product development
- frontend architecture for stateful UX
- AI-assisted consumer product interfaces
- early-stage MVP building with strong product/engineering overlap

## Next Improvements

- Extract more home/add/edit logic out of `lib/main.dart`.
- Improve production configuration and environment strategy.
- Expand test coverage around persistence and profile behavior.
- Continue separating product-facing and engineering-facing documentation.

## My Role

I built the project independently, including the Flutter client architecture, onboarding flow, photo-based meal logging UX, manual meal editing behavior, local persistence model, session-based history logic, backend API integration, and the test coverage around the most product-critical flows.
