# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-23

### Added

- Transition command hooks: `@pomodoro_revamped_on_work`,
  `@pomodoro_revamped_on_break`, and `@pomodoro_revamped_on_long_break` run a
  shell command when each phase begins. The hook fires whether or not desktop
  notifications are enabled (upstream tmux-pomodoro-plus #38, PR #52).
- Each status render exports the rendered segment to the `@pomodoro_status` tmux
  option for theme integration via `#{@pomodoro_status}` (upstream PR #55).

### Changed

- Reviewed upstream tmux-pomodoro-plus #46. The number of work periods before a
  long break is already configurable through `@pomodoro_revamped_intervals`.

## [1.0.0] - 2026-06-22

### Added

- A Pomodoro timer in the status bar via #{pomodoro_status}: work, short breaks,
  and a long break after every N intervals, with phase color and a MM:SS
  countdown.
- Temp-file-free: the whole timeline is computed from a single start epoch, with
  all state in tmux server options. No /tmp files, nothing to clean up.
- Pause and resume with exact paused-time accounting; toggle, cancel, and skip
  bindings, all configurable.
- Desktop notifications on phase changes via osascript (macOS) or notify-send
  (Linux), and configurable per-phase colors and icons.
