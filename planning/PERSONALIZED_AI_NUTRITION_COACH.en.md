# Personalized AI Nutrition Coach

Updated: 2026-07-06

This document describes a future personalized AI nutrition coach inside AI Calorie Tracker. This is not MVP scope, and it is not an attempt to compete with Fitbit/Google Health as a broad health coach. The inspiration is the quality of personalization: messages feel useful not because they are "AI", but because they understand the user's real context.

## 1. Positioning

AI Calorie Tracker should remain a nutrition-first product.

The future AI nutrition coach:

- helps users make better nutrition decisions today;
- explains what to do next based on meals, calories, macros, goals, and habits;
- does not try to become a full fitness trainer, medical service, or wearable dashboard;
- may use external activity data when it improves nutrition advice;
- should not turn the product into an overly horizontal health app.

Analogy:

- Fitbit / Google Health coach: a personal trainer and health coach built around wearable data.
- AI Calorie Tracker coach: a personal nutritionist built around food, goals, daily progress, and eating patterns.

## 2. Product Shape: Today + Ask

The intended shape is `Today + Ask`.

### Today

`Today` is the main surface in Home where AI shows proactive personalized cards.

Example cards:

- "You have used 68% of today's calories, but only 39% of your protein target. Your next meal should probably be protein-centered."
- "After yesterday's late heavy dinner, a lighter lunch today would leave more room for the evening."
- "You often skip breakfast and make up calories at night. Today, try a small protein-heavy breakfast."
- "After the workout imported from Apple Health, you have more calorie room. Protein still matters more than simply filling calories."

Cards should be:

- short;
- specific;
- tied to data;
- low-pressure;
- focused on one clear next step.

### Ask

`Ask` is where the user can ask the AI nutrition coach a question.

Example questions:

- "What should I eat for dinner if I have 520 kcal left?"
- "I am low on protein. How can I finish the day better?"
- "Why do I often overeat in the evening?"
- "Can I have pizza today and still stay within plan?"
- "How can I change breakfast to get more protein?"

Ask should not become a general-purpose chat. It should answer within the boundaries of nutrition, goals, and the current food diary.

## 3. Tone

Tone: calm expert.

Principles:

- personal, but not intrusive;
- concrete, but not aggressive;
- explains the reason instead of just giving commands;
- avoids medical conclusions;
- does not diagnose;
- does not shame users for going over calories or missing logs.

Good style:

`You are close to today's calorie target, but protein is still low. For the next meal, something like chicken, cottage cheese, fish, or Greek yogurt would fit better.`

Bad style:

`You failed today. Fix your diet immediately.`

## 4. Not MVP

The AI nutrition coach should not be required for `Beta v1`.

Do not build for MVP:

- full AI chat;
- complex long-term meal plans;
- medical advice;
- diagnoses;
- personalized recommendations based on wearable data;
- automatic target changes without user confirmation;
- core loop dependency on an LLM.

MVP should prove that users want and can regularly log food.

## 5. Near v1 Foundations

Around `v1`, the app should prepare foundations so the AI nutrition coach can be added later without rewriting the product.

### Data

Store data in a way that can later support personalization safely:

- user goal: lose, maintain, gain;
- daily calorie and macro targets;
- food log;
- meal times;
- entry source: photo, manual, edited;
- AI uncertainty / manual fallback status;
- edit history;
- selected date / local day boundaries;
- meal type: breakfast, lunch, dinner, snack;
- simple patterns: skipped breakfast, evening overeating, frequent low protein.

### Analytics

The coach will be stronger if these events can exist later:

- `coach_card_seen`
- `coach_card_dismissed`
- `coach_card_action_taken`
- `ask_coach_opened`
- `ask_coach_question_sent`
- `coach_suggestion_followed`

These events do not have to be implemented immediately, but the product should leave clear places for them.

### Integrations

Around `v1`, future integrations should be designed, even if not all are implemented immediately.

Priority:

1. Android Health Connect
2. Apple HealthKit
3. Fitbit/Google Health or another activity provider if public APIs and permissions fit the product

Useful data types:

- active calories / active energy burned;
- total calories burned, if the source is reliable;
- workouts / exercise sessions;
- steps as low-priority context;
- weight, if the user explicitly allows it;
- sleep only when it helps explain eating patterns, not as a central feature.

References:

- Android Health Connect data types: https://developer.android.com/health-and-fitness/health-connect/data-types
- Apple HealthKit: https://developer.apple.com/health-fitness/

## 6. Post-v1 / Differentiation

After v1, the AI nutrition coach can become the product's main differentiator.

### Core capability

The coach should be able to:

- read the current nutrition day;
- compare it to the user's goal;
- notice recurring patterns;
- suggest one next best step;
- explain recommendations in plain language;
- account for activity when the user has connected an integration;
- stay inside nutrition advice boundaries.

### Future scenarios

Morning:

`Yesterday ended close to your calorie target, but protein was 28 g below plan. Today, try to get 30-40 g of protein before lunch.`

After a workout:

`Your workout increased energy expenditure, but it is better not to fill all of that with sweets. For the next meal, aim for protein plus moderate carbs.`

Evening:

`You have 430 kcal and 35 g protein left. A good dinner today would be light and protein-heavy, without too much fat.`

After several days:

`It looks like you are more likely to exceed calories on days when your first meal is after 1 PM. A small breakfast or earlier lunch may help.`

### Product moat

The differentiator is not simply having a chat.

The differentiator:

- the food diary creates context;
- AI explains that context;
- the user gets a personalized next step;
- external integrations improve advice, but do not replace the nutrition core.

## 7. Safety And Trust

The coach must be careful.

Rules:

- do not provide medical diagnoses;
- do not overpromise AI food-recognition accuracy;
- do not recommend extreme calorie deficits;
- do not pressure the user;
- show what data the advice is based on;
- allow the user to disable personalization or integrations;
- request explicit permissions for health data.

## 8. Open Questions

Decide later:

- whether Ask is free or premium;
- how many AI messages should appear per day;
- whether the coach should remember user preferences;
- how users can correct a bad suggestion;
- which integrations are most practical in Flutter first;
- which data should be stored locally and which should not be stored.

## 9. Main Principle

The AI nutrition coach should appear only after the food diary works.

Formula:

`good food log + goals + history + optional activity -> personalized nutrition advice`

Do not build a general health assistant. Build the best personal layer on top of nutrition.
