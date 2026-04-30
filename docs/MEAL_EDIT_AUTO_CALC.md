# Meal Edit Auto-Calc

## Purpose

This document explains the current `Add Meal / Edit Meal` nutrition form behavior in the Flutter client.

The goal is to help future developers or AI agents change the feature safely without re-discovering the product rules from widget tests.

Important:
- This logic is frontend-only and runs on the device.
- Backend is not involved in manual meal add/edit recalculation.
- Current implementation lives in `lib/main.dart` inside the manual meal bottom sheet flow and `_MealFormDraft`.

## Core Rules

The form has five linked nutrition fields:
- `Calories`
- `Weight`
- `Protein`
- `Fat`
- `Carbs`

### Calories formula

Calories are derived from macros with the standard formula:

```text
protein * 4 + fat * 9 + carbs * 4
```

### Weight behavior

`Weight` is always a manual user-controlled field.

Rules:
- `Weight` is never derived from calories or macros.
- If the user edits `Weight`, it becomes the source of change for that interaction.
- `Weight` scales only unlocked nutrition values.
- `Weight` does not participate in locked-calories auto-adjust confirm as an auto-adjust target.

This is intentional and should not be changed casually. Product decision: weight is treated as a physical quantity, not a derived nutrition number.

## Session-Scoped Locking

Each manual edit session starts when the meal sheet opens and ends when the sheet closes.

Within one open session:
- any field the user edits manually becomes locked
- any nutrition field can also be locked with a double tap, even before changing its value
- locked fields get a yellow outline
- locked fields show a small unlock icon
- auto-calculation can change only unlocked fields

Locks are not persisted across sheet openings.

When the user closes and reopens the sheet:
- all locks reset
- all session-only manual intent resets

## Realtime Recalculation Rules

### If the user edits `Weight`

- scale unlocked `Calories`, `Protein`, `Fat`, `Carbs` proportionally
- do not auto-change locked nutrition fields
- do not derive a new `Weight` from anything else

### If the user edits `Protein`, `Fat`, or `Carbs`

- the edited macro becomes locked
- if `Calories` is not locked, recalculate `Calories` from macros
- if `Calories` is already locked, do not overwrite `Calories`
- if the new macro value causes a conflict with locked calories, keep the conflict state visible

### If the user edits `Calories`

- `Calories` becomes locked
- scale only unlocked macros proportionally to match the new calorie target
- keep locked macros unchanged
- if no valid rebalance is possible, keep the conflict visible instead of guessing

## Manual Intent vs Locked Fields

The feature tracks both:
- `lockedFields`
- `manuallyEditedMacroFields`

Why both exist:
- `lockedFields` control current UI and auto-calc permissions
- `manuallyEditedMacroFields` define which macro fields count as explicit user intent for locked-calories confirm logic

Double-tap locking adds a field to `lockedFields`, but does not count as a manual macro value change by itself.

This distinction matters because confirm-flow must respect all manually edited macros in the current sheet session, not only the last edited macro.

## Locked Calories Confirm Flow

Special confirm is shown only for this product case:
- `Calories` is locked
- there is a macro/calorie conflict
- at least one other macro is still safe to auto-adjust

Confirm copy:
- title: `Keep calories fixed?`
- body: `We’ll keep calories fixed and rebalance the other macros.`
- secondary: `Keep editing`
- primary: `Auto-adjust & save`

### What confirm respects

When confirm is built, the following are treated as fixed:
- locked `Calories`
- all locked macro fields
- all macro fields manually edited in the current sheet session

Only remaining unlocked and not-manually-edited macros may be rebalanced automatically.

### If the user taps `Keep editing`

- do not save
- keep the sheet open
- show helper text:

```text
Calories are locked. Unlock another macro or reset auto-calc to rebalance this meal.
```

### If the user taps `Auto-adjust & save`

- rebalance only the remaining allowed macros
- keep locked calories unchanged
- keep all manually edited macros unchanged
- save immediately

## Explicit Warning States

### Fully manual macro state

If `Calories` is locked and all macros are already manually fixed in the current session, confirm should not open.

Show this message instead:

```text
All macros are manually locked. Unlock one macro or reset auto-calc to continue.
```

### Rebalance helper

If the user backs out of confirm with `Keep editing`, show:

```text
Calories are locked. Unlock another macro or reset auto-calc to rebalance this meal.
```

## Reset and Unlock UX

### Unlock one field

The field-level unlock icon:
- removes the lock from that field
- removes that macro from `manuallyEditedMacroFields` if applicable
- immediately recalculates based on the remaining locked state

### Reset auto-calc

`Reset auto-calc`:
- clears all locks
- clears all session manual macro intent
- recalculates `Calories` from the current macros
- keeps `Weight` unchanged

## Analytics / Debug Tracking

There is no external analytics SDK yet.

Current lightweight tracking uses `debugPrint` in debug mode through `_trackMealEditEvent`.

Tracked events:
- `meal_edit_locked_conflict_prompt_shown`
- `meal_edit_locked_conflict_keep_editing`
- `meal_edit_locked_conflict_auto_adjust_saved`
- `meal_edit_locked_conflict_unresolvable`
- `meal_edit_reset_auto_calc`
- `meal_edit_unlock_field`

Current payload fields may include:
- `source` (`add` or `edit`)
- `locked_fields_count`
- `manually_edited_macro_count`
- `adjusted_fields`
- `has_conflict`

If the team later adds a real analytics SDK, this helper is the intended replacement point.

## Test Coverage

Widget coverage currently includes:
- `Weight -> unlocked nutrition values`
- `Macro -> Calories`
- `Calories -> unlocked macros`
- yellow locked styling + unlock icon
- unlock recalculation
- reset auto-calc behavior
- locked-calories confirm flow
- confirm respecting multiple manual macro edits in one session
- fully manual macro conflict without confirm
- grouped-history edit path save behavior

Main test file:
- `test/widget_test.dart`

## Refactor Guidance

Current implementation is acceptable for the present app size because:
- the feature is private to one screen
- behavior is heavily covered by widget tests
- product rules changed rapidly during implementation

Recommended future extraction point:
- move `_MealEditField`
- move `_MealLockedCaloriesAutoAdjustProposal`
- move `_MealFormDraft`

Suggested destination:
- `lib/meal_edit/meal_form_draft.dart`
- or a small `lib/meal_edit/` folder if the screen continues growing

Do this when one of these becomes true:
- more nutrition editing screens are added
- validation/copy needs localization
- analytics becomes production-grade
- `lib/main.dart` becomes meaningfully harder to navigate

Until then, avoid refactoring just for file-count cleanliness if it risks destabilizing the math.
