# Personalized AI Nutrition Coach

Status: future product direction, not MVP.

Last updated: 2026-07-06

## 1. Purpose

This document defines the future AI nutrition coach concept for AI Calorie Tracker.

The goal is not to copy Fitbit, Google Health, or a broad wearable-based health coach. The goal is to build a nutrition-first assistant that becomes useful because it understands the user's food log, goals, current day, recurring eating patterns, and optional external activity context.

The current app must continue to work as a strong food logger without this feature.

## 2. Product Positioning

AI Calorie Tracker should remain focused on nutrition.

Future coach positioning:

`a calm personal nutritionist inside the food diary`

The coach should help the user answer:

- What should I do next today?
- How should I adjust the next meal?
- Why am I missing protein or exceeding calories?
- How can I stay close to my plan without overthinking?
- How should activity context affect food choices?

It should not become:

- a first-party workout tracker;
- a sleep product;
- a medical advisor;
- a general lifestyle chatbot;
- a wearable dashboard;
- a replacement for a clinician or registered dietitian.

## 3. Product Shape: Today + Ask

The intended UX shape is `Today + Ask`.

### Today

`Today` is the proactive surface. It should live on or near the Home screen and show personalized nutrition cards.

Each card should:

- be short;
- be specific;
- cite the relevant context;
- recommend one next step;
- avoid pressure or shame;
- stay inside nutrition guidance.

Example cards:

- `You have used 68% of today's calories, but only 39% of your protein target. Your next meal should be protein-centered.`
- `You often skip breakfast and make up calories at night. Today, a small protein-heavy breakfast may help.`
- `Your imported workout increased energy expenditure. Protein still matters more than simply filling the extra calories.`

### Ask

`Ask` is the user-initiated surface. It lets the user ask nutrition questions using their current app context.

Good questions:

- `What should I eat for dinner if I have 520 kcal left?`
- `I am low on protein. How can I finish the day better?`
- `Can I have pizza today and still stay within plan?`
- `Why do I often exceed calories in the evening?`

Ask should not answer broad medical, workout-plan, or mental-health questions beyond safe general redirection.

## 4. Tone And Copy Rules

Tone: calm expert.

Rules:

- be personal, but not intrusive;
- explain the reason behind recommendations;
- prefer one clear next step over long advice;
- avoid guilt, fear, or aggressive coaching;
- avoid medical claims and diagnoses;
- admit uncertainty when data is incomplete;
- tell the user what data influenced the suggestion.

Good:

`You are close to today's calorie target, but protein is still low. For the next meal, chicken, cottage cheese, fish, or Greek yogurt would fit better than a high-fat snack.`

Bad:

`You failed today. Fix your diet immediately.`

## 5. Not MVP

Do not include in `Beta v1`:

- full AI chat;
- LLM dependency for the main logging loop;
- wearable-based personalization;
- automatic target changes;
- long meal plans;
- diagnosis or treatment advice;
- broad health coaching;
- premium-only AI gates.

`Beta v1` should prove the food logging loop before AI becomes a retention layer.

## 6. Near-v1 Foundations

Near `v1`, the app should prepare foundations without shipping a full coach.

Data foundations:

- reliable food log persistence;
- local date boundaries;
- meal timestamps;
- meal type: breakfast, lunch, dinner, snack;
- entry source: photo, manual, edited;
- AI uncertainty / manual fallback status;
- nutrition totals per meal and per day;
- user goal and daily targets;
- edit/delete history if feasible;
- basic repeated patterns, such as low protein, skipped breakfast, late calorie concentration.

Analytics foundations:

- `onboarding_completed`
- `first_meal_logged`
- `meal_logged_photo`
- `meal_logged_manual`
- `photo_analyze_success`
- `photo_analyze_fail`
- `manual_fallback_used`
- `meal_edited`
- `day_2_returned`
- `day_7_returned`

Future coach analytics:

- `coach_card_seen`
- `coach_card_dismissed`
- `coach_card_action_taken`
- `ask_coach_opened`
- `ask_coach_question_sent`
- `coach_suggestion_followed`

## 7. Future Context Sources

Core context:

- food log;
- calorie target;
- macro targets;
- current day progress;
- meal timing;
- user goal;
- repeated eating patterns.

Optional future context:

- routine and preferred meal timing;
- activity calories;
- workouts or exercise sessions;
- steps as low-priority context;
- weight, only with explicit permission;
- sleep, only if it helps explain eating patterns;
- weather, only if it affects routine and meal timing.

Possible integrations:

- Android Health Connect;
- Apple HealthKit;
- Fitbit/Google Health or another activity provider if public APIs and permissions fit the product.

Integration rule:

Use external health data to improve nutrition advice. Do not turn the product into a general fitness or sleep app.

References:

- Android Health Connect data types: https://developer.android.com/health-and-fitness/health-connect/data-types
- Apple HealthKit: https://developer.apple.com/health-fitness/

## 8. Safety And Trust

The coach must be conservative.

Hard rules:

- no medical diagnosis;
- no eating-disorder treatment claims;
- no extreme calorie-deficit suggestions;
- no overconfident food-recognition claims;
- no hidden use of health data;
- no advice based on health integrations before explicit permission;
- no automatic goal changes without user confirmation.

Trust rules:

- show why a recommendation appeared;
- allow dismissing or correcting a suggestion;
- allow disabling personalization;
- keep manual logging usable even when AI is unavailable;
- make fallback states clear.

## 9. Implementation Phases

### Phase 0: Current app

Heuristic Home coach only. No AI nutrition coach.

### Phase 1: Better deterministic coach cards

Use local data to create more useful non-LLM cards:

- low protein;
- few calories left;
- over target;
- empty day;
- yesterday protein gap;
- late-day calorie concentration.

### Phase 2: Context package

Create a structured nutrition context object that can feed either deterministic cards or an LLM later.

It should include:

- user goal;
- day totals;
- remaining calories/macros;
- recent meals;
- simple patterns;
- optional activity summary.

### Phase 3: Today AI cards

Generate or select a small number of personalized cards. Keep them bounded, explainable, and dismissible.

### Phase 4: Ask Coach

Add user-initiated questions with strict nutrition boundaries and clear safety behavior.

### Phase 5: Integrations-enhanced coaching

Use activity calories and workouts to improve nutrition recommendations when the user has connected a trusted source.

## 10. Open Decisions

Decide later, after `Beta v1` data:

- whether Ask Coach is free, premium, or limited;
- how many AI cards should appear per day;
- whether coach memory stores preferences;
- how suggestions are corrected;
- which integration ships first;
- whether coach output is generated on-device, backend-driven, or hybrid;
- how much historical data should be included in each AI context.

## 11. Success Criteria

The coach is useful only if it changes behavior without adding noise.

Possible success metrics:

- coach card action rate;
- Ask repeat usage;
- improved meals logged per active day;
- improved day-2/day-7 retention;
- lower evening calorie overshoot;
- better protein target completion;
- positive qualitative feedback mentioning personalization.

Do not judge the coach by number of generated messages. Judge it by whether users make better nutrition decisions and return.
