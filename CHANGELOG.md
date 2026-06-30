# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-06-30

### Added

- Finish-time in the segment: `@pomodoro_revamped_show_finish` appends `ends HH:MM`
  so a meeting can be planned without mental math.
- Inline progress bar: `@pomodoro_revamped_show_progress` prepends an ASCII bar,
  width and glyphs configurable via `@pomodoro_revamped_progress_width`,
  `@pomodoro_revamped_bar_filled`, and `@pomodoro_revamped_bar_empty`.
- Weekly focus tally exported to `@pomodoro_week` as a glyph-free sparkline and
  `@pomodoro_today` as the count for the current day. The data is a bounded
  7-slot ring kept in tmux options, with no temp file.
- Daily completed count and session goal: `@pomodoro_revamped_show_goal` appends
  `done/goal` using `@pomodoro_revamped_goal`.
- Restart the current phase with `prefix + R` or `pomodoro.sh restart`, rewinding
  the running phase to its full duration.
- End-of-phase warning: `@pomodoro_revamped_warn_seconds` fires one alert and the
  optional `@pomodoro_revamped_on_warn` hook shortly before a phase ends.
- Quiet-hours window `@pomodoro_revamped_quiet_hours` keeps the timer running but
  suppresses notifications and the bell during the window.
- Cycle-complete hook `@pomodoro_revamped_on_cycle` runs when a long break begins.
- Bell fallback `@pomodoro_revamped_bell` rings the terminal bell on a phase
  change, an SSH-friendly path when no desktop notifier is present.
- Control menu (`prefix + o`) and help popup (`prefix + ?`), both routed through a
  single tmux seam.
- Machine-readable sibling tokens `@pomodoro_phase`, `@pomodoro_remaining`, and
  `@pomodoro_fraction` exported on every render.

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
