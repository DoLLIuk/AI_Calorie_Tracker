# Beta Analytics Contract

Status: event schema, in-app instrumentation, Firebase adapter, and Android/iOS Firebase configuration files are implemented. Real-device verification in Firebase DebugView is still required.

Last updated: 2026-07-09

## Purpose

Measure the Beta v1 core loop without collecting meal contents, photos, body measurements, API keys, request IDs, or other unnecessary personal data.

The client owns a provider-neutral `Analytics` interface in `lib/analytics.dart`. Android and iOS release builds use `FirebaseAnalyticsAdapter`; unsupported desktop targets keep the debug-only implementation. It sends only the events and properties in this document.

Before beta invitations, verify the events in a real Android and iOS device build through Firebase DebugView. Until then, the analytics release gate in `BETA_V1_CHECKLIST.md` remains unchecked.

## Required Events

| Event | When it fires | Allowed properties |
| --- | --- | --- |
| `onboarding_completed` | A new user finishes onboarding. | None |
| `first_meal_logged` | The user's first saved meal is added. | None |
| `meal_logged` | A newly saved meal is added. | `source`: `ai` or `manual`; `day_offset`: integer relative to the current local day; `creates_new_session`: boolean |
| `photo_analysis_succeeded` | The photo analysis request returns a usable response. | `source`: `camera` or `gallery`; `requires_portion_confirmation`: boolean |
| `photo_analysis_failed` | The photo analysis request fails. | `source`: `camera` or `gallery`; `error_code` |
| `manual_fallback_used` | The user selects **Add manually** from a photo error. | `error_code` |
| `meal_edited` | A saved meal is changed. | `source`: `ai` or `manual` |
| `meal_deleted` | A saved meal is deleted. | `source`: `ai` or `manual` |

`day_offset` lets the provider group a meal with its intended diary day without receiving the raw date or timezone. `creates_new_session` identifies a new app meal session without exposing its timestamp or session ID. Do not send raw dates, timezones, meal timestamps, or session IDs unless there is a documented product need.

## Derived Beta Metrics

- **Onboarding completion:** unique users with `onboarding_completed`.
- **First meal rate:** users with `first_meal_logged` after onboarding.
- **Activation:** users with at least 3 `meal_logged` events and at least 2 events where `creates_new_session` is true for the intended diary day.
- **Early return:** an additional `meal_logged` event with `day_offset = 0` on the next calendar day after activation.
- **Photo failure rate:** `photo_analysis_failed / (photo_analysis_succeeded + photo_analysis_failed)`.
- **Manual fallback usage:** users or events with `manual_fallback_used`.
- **Editing/deletion rate:** counts of `meal_edited` and `meal_deleted` relative to logged meals.

## Provider Integration Rules

When a provider is chosen:

1. Implement a separate `Analytics` adapter; do not add provider calls directly to widgets or controllers.
2. Keep the exact event names above stable for the first beta cycle.
3. Send only the listed properties.
4. Do not initialize the provider with `API_KEY`, meal names, images, nutrition values, onboarding inputs, or backend request IDs.
5. Document the provider's privacy configuration, retention, consent requirement, and dashboard queries before enabling release builds.
6. Add an adapter test and verify a real iOS and Android beta build before checking the analytics release gate.
