# Personal WHOOP app backlog

This is the product backlog for the simpler, local-first WHOOP 4 app.  It is
not a promise that an unsupported strap signal exists: an item marked
**research** must produce real captures and pass its stated gate before it can
become a user-facing metric.

## First usable build

- [ ] Fork `OpenStrap/edge` into the user's GitHub account and make it the
      project remote; keep upstream configured for future updates.
- [ ] Replace the current information-dense Today view with a simple dashboard:
      Recovery, Sleep, Strain, Battery, current HR, HRV, respiratory rate and
      clear personal normal/watch states.
- [ ] Add current WHOOP HR with a selectable 15-minute / 1-hour / 1-day chart.
      The live card now has the controls and a 15-minute foreground buffer;
      persistent 1-hour/1-day history still requires a documented stored-series
      source before it can be labelled as such.
- [ ] Make Sync an explicit, inspectable flow: connect, authenticate, clock,
      history range, records received, safely stored, acknowledged, derived,
      complete or actionable error.
- [x] Make band state obvious: connected/disconnected, on-wrist/off-wrist,
      battery, charging state and a low-battery/charge reminder.
- [ ] Provide one coherent Profile and calibration screen: age, mass, height,
      sex/formula eligibility, resting-HR override, goals, HR zones and data
      source preferences.

## Activity and fitness

- [ ] Surface phone steps as the default all-day step source, with source and
      coverage clearly labelled. Do not claim WHOOP-4 all-day steps.
- [x] Add the guided **WHOOP Fitness Test — Rockport 1-mile walk** UI:
      active-session-only location permission, GPS/track option, live WHOOP
      HR, one-mile completion, finish-HR capture and result history.
- [x] Implement the pure Rockport equation and protocol/refusal gates in
      `lib/fitness/rockport.dart`.
- [x] Show Rockport results as `VO2 max estimate · WHOOP HR + GPS`, never as a
      directly measured WHOOP value; require two acceptable tests and use their
      median as the initial baseline.
- [ ] Consider an optional Cooper 12-minute run only after Rockport works; it
      needs stronger health/safety guidance and remains a field estimate.

## Sleep, temperature and oxygen

- [x] Make existing sleep stages and hypnogram discoverable from Today; label
      them as local estimates, not Apple Health sleep-stage samples.
- [ ] Build skin-temperature baseline calibration: stable overnight windows,
      7-night preliminary / 14-night mature baseline, and changes relative to
      that baseline only. Never show it as core temperature or a fever claim.
      The policy helper and calibration metadata are now in place; the
      remaining work is wiring stable-night selection and the mature gate into
      derivation/UI (the existing relative z gate remains intentionally
      conservative at three nights).
- [ ] **Research:** add an Optical Lab capture session for known WHOOP-4 live
      optical streaming. Save raw packets, timestamps, motion/contact quality,
      known command responses and capture diagnostics locally.
- [ ] **Research gate:** determine whether this particular WHOOP-4 firmware
      emits time-aligned, separately identifiable red and IR waveforms with
      usable metadata. Do not send unknown BLE commands.
- [ ] If the research gate passes, display only an experimental optical trend
      and signal-quality state at first. Do not display an absolute SpO2 %
      without a validated calibration and reference comparison.

## Reliability, privacy and release

- [ ] Preserve raw packets until safely stored; make interrupted sync resume
      visibly and never hide an unrecoverable sync issue behind a spinner.
- [x] Add a small diagnostics/export bundle for a user-approved debugging
      session; health data stays local by default. Sync Details now copies a
      compact local bundle without uploading health data.
- [ ] Run the Flutter/iOS suite and device-test on a legitimate Mac/Xcode
      environment; Windows remains suitable for the pure Dart logic and web
      prototype work.
- [ ] Configure iOS signing and TestFlight only after the app is usable; public
      TestFlight distribution requires an Apple Developer Program membership.

## Explicit non-goals until evidence changes

- [ ] No invented WHOOP-4 all-day step total from its 1 Hz history.
- [ ] No direct core-body-temperature or fever estimate from wrist temperature.
- [ ] No WHOOP-4 BLE SpO2 percentage based on the current 1 Hz red/IR fields.
- [ ] No medical diagnosis, alert or clinical claim from the app's estimates.
