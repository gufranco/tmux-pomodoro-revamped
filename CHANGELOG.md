# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
