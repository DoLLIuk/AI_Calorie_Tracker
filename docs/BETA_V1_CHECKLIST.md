# Beta v1 Checklist

Status: approved product criteria; release gates remain to be completed.

Last updated: 2026-07-09

## 1. Beta Goal

Validate the core habit loop on iOS and Android:

`complete onboarding -> log meals -> understand daily progress -> return the next day`

This beta is not a public launch, monetization test, AI nutrition coach, health integration, account, or sync release.

## 2. Beta Format

- Platforms: iOS and Android.
- Distribution: closed beta through TestFlight and Google Play Closed Testing.
- Initial cohort: 20-50 testers.
- Duration: 7-14 days.
- Feedback channel: a dedicated support email is required before invitations are sent. The final address is intentionally pending.

The closed cohort comes before any broader public discovery. It gives the team a controlled way to find critical issues and collect useful feedback before the app is promoted more widely.

## 3. Definition Of Success

### Per-user activation

A tester is activated when they:

- complete onboarding;
- log at least 3 meals;
- log those meals in at least 2 separate meal sessions.

The app currently defines a separate session using its existing sessionization rules, including a 15-minute gap between adjacent entries.

### Early return

A tester has demonstrated early return when they log at least one additional meal on the next calendar day after activation.

This is deliberately separate from activation: multiple sessions in one day do not by themselves prove that the user returned.

### Learning outcome

At the end of the beta, review:

- how many invited testers installed and opened the app;
- how many completed onboarding;
- how many activated;
- how many returned the next calendar day;
- where photo logging fails or is abandoned;
- how often manual fallback is used;
- the five most repeated feedback themes.

No cohort-wide percentage threshold is set yet. The first closed beta establishes the baseline; its outcome is a decision to fix the core loop, iterate the beta, or proceed to broader testing.

## 4. Release Gates Before Inviting Testers

All items in this section must be true before the first invitation.

### Product and UX

- [ ] A new user can complete onboarding without author assistance.
- [ ] A user can add a first meal manually.
- [ ] A user can add a meal from camera and gallery when the backend is available.
- [ ] A clear manual fallback is available if photo analysis fails or is uncertain.
- [ ] The Home screen shows calories, macros, and the current day's logged meals clearly.
- [ ] A user can edit and delete a saved meal without confusing results.
- [ ] Empty states explain what to do next.

### Reliability

- [ ] Saved onboarding and meals survive a normal app restart on both platforms.
- [ ] The build is usable without network after onboarding when viewing already saved local data.
- [ ] API configuration is present in the beta build; testers do not need hidden setup.
- [ ] Photo API errors and timeouts show understandable copy and a manual fallback.
- [ ] Android and iOS smoke tests both pass on physical devices.

### Measurement and feedback

- [ ] The beta build records, at minimum: onboarding completion, first meal logged, photo success, photo failure, manual fallback, meal edit, meal delete, and meals per active day.
- [ ] The data can identify activation and next-calendar-day return without collecting unnecessary personal data.
- [ ] A feedback email address and a short tester instruction are ready before invitations are sent.
- [ ] Testers know how to report a bug, attach a screenshot, and describe what they expected.

### Distribution and operations

- [ ] An iOS TestFlight build is uploaded and installable by an external tester.
- [ ] An Android closed-testing build is uploaded and installable by an external tester.
- [ ] The tester list, invite copy, feedback address, and support owner are prepared.
- [ ] Privacy policy and medical/nutrition disclaimer are ready for the beta distribution surfaces that require them.

## 5. Immediate No-Go Conditions

Do not invite or pause the beta if any of the following occurs:

- onboarding cannot be completed;
- a meal cannot be added manually;
- photo failure leaves the user without a workable manual path;
- a saved meal or onboarding result is lost after a normal restart;
- Home does not reflect a saved meal correctly;
- the app requires testers to enter hidden API values or perform developer setup;
- the beta build cannot be installed or launched on either target platform.

## 6. Manual Acceptance Script

Run this script on both iOS and Android before each beta candidate:

1. Start with no local app data and complete onboarding.
2. Add one meal manually; edit it; delete it; add it again.
3. Add a meal from the camera or gallery with a successful response.
4. Exercise the clarification and portion-confirmation paths when available.
5. Simulate a photo/API failure and confirm the manual fallback is clear and usable.
6. Close and relaunch the app; confirm onboarding, targets, and meals remain.
7. Confirm Home totals, session history, and the latest meal agree.
8. Verify that the required beta events and feedback path are available.

## 7. Tester Instruction: Required Content

The invitation or welcome message must explain:

- this is a 7-14 day closed beta for iOS and Android;
- the target task: log at least 3 meals across 2 sessions, then return the next day;
- photo logging may be imperfect and manual entry is always acceptable;
- how to send feedback, screenshots, device model, app version, and steps to reproduce;
- that nutrition estimates are informational and not medical advice.

## 8. Go / No-Go Decision

### Go

Start the closed beta only when every release gate in section 4 is checked and no immediate no-go condition exists.

### Pause or iterate

Pause invitations, fix the issue, and rerun the acceptance script when a no-go condition occurs or the feedback path/measurement is missing.

### End-of-beta review

After 7-14 days, summarize activation, early return, photo/manual behavior, failures, and repeated feedback. Use those results to choose the next product or architecture task; do not add a larger feature solely because it was already on the roadmap.
