<div align="center">

<h1>tmux-pomodoro-revamped</h1>

**A Pomodoro timer in your tmux status bar, with zero temp files: all state lives in tmux options.**

[![Tests](https://github.com/tmux-revamped/tmux-pomodoro-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-pomodoro-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](CHANGELOG.md)

</div>

**work + breaks** · **no temp files** · **tmux 1.9 to 3.5** · **94** tests · **95%+** coverage

A Pomodoro timer that counts down work and break intervals in the status bar. The whole timeline is computed from a single start epoch, so there is **no temp file** anywhere (the original keeps seven in `/tmp`), nothing to clean up, and no `/tmp` collision between users. State lives entirely in tmux server options, and the phase is computed on demand, so the render never spawns a background process.

Built from [tmux-plugin-template](https://github.com/tmux-revamped/tmux-plugin-template).

<table>
<tr>
<td><strong>No temp files</strong><br>The timeline is pure math over a start epoch. State is in tmux options, nothing on disk.</td>
<td><strong>Full cycle</strong><br>Work, short breaks, and a long break after every N intervals, then it repeats.</td>
</tr>
<tr>
<td><strong>Pause and resume</strong><br>Paused time is tracked exactly, so the countdown is correct after any number of pauses.</td>
<td><strong>Notifications</strong><br>A desktop notification on each phase change, via osascript on macOS or notify-send on Linux.</td>
</tr>
</table>

## Status placeholder

Put `#{pomodoro_status}` in your status line:

```tmux
set -g status-right '#{pomodoro_status} | %H:%M'
```

It renders the phase color, the `MM:SS` countdown, and `[interval/total]`, for example `23:20 [1/4]`. It is empty when no timer is running.

Each render also writes the same segment to the `@pomodoro_status` tmux option, so a theme or another plugin can read the current value with `#{@pomodoro_status}` without invoking the script.

Each render also publishes machine-readable options for sibling plugins and themes: `@pomodoro_phase` (work, break, or long_break), `@pomodoro_remaining` (seconds left), `@pomodoro_fraction` (percent elapsed), `@pomodoro_week` (a glyph-free weekly focus sparkline), and `@pomodoro_today` (work periods completed today). The weekly tally is a bounded 7-slot ring kept in tmux options, so there is still no temp file.

## Controls

| Key | Action |
|-----|--------|
| `prefix + p` | start, or pause/resume a running timer |
| `prefix + P` | cancel the timer |
| `prefix + _` | skip to the next phase |
| `prefix + R` | restart the current phase |
| `prefix + o` | open the control menu |
| `prefix + ?` | open the help popup |

All keys are configurable.

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add to `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-revamped/tmux-pomodoro-revamped'
```

Then press `prefix + I`, and add `#{pomodoro_status}` to your status line.

## Configuration

| Option | Default | Meaning |
|--------|---------|---------|
| `@pomodoro_revamped_work` | `25` | work minutes |
| `@pomodoro_revamped_break` | `5` | short break minutes |
| `@pomodoro_revamped_long_break` | `15` | long break minutes |
| `@pomodoro_revamped_intervals` | `4` | work periods before a long break |
| `@pomodoro_revamped_show_interval` | `1` | set to `0` to hide the `[n/N]` counter |
| `@pomodoro_revamped_notifications` | `1` | set to `0` to disable desktop notifications |
| `@pomodoro_revamped_on_work` | unset | shell command run when a work phase begins |
| `@pomodoro_revamped_on_break` | unset | shell command run when a short break begins |
| `@pomodoro_revamped_on_long_break` | unset | shell command run when a long break begins |
| `@pomodoro_revamped_show_progress` | `0` | set to `1` to prepend an ASCII progress bar |
| `@pomodoro_revamped_progress_width` | `8` | progress bar width in cells |
| `@pomodoro_revamped_bar_filled` | `#` | filled progress-bar glyph |
| `@pomodoro_revamped_bar_empty` | `-` | empty progress-bar glyph |
| `@pomodoro_revamped_show_finish` | `0` | set to `1` to append `ends HH:MM` |
| `@pomodoro_revamped_show_goal` | `0` | set to `1` to append the daily `done/goal` counter |
| `@pomodoro_revamped_goal` | `6` | daily focus-session goal |
| `@pomodoro_revamped_warn_seconds` | `0` | seconds before a phase ends to warn once; `0` disables |
| `@pomodoro_revamped_quiet_hours` | unset | window like `22:00-07:00` that suppresses alerts |
| `@pomodoro_revamped_bell` | `0` | set to `1` to ring the terminal bell on a phase change |
| `@pomodoro_revamped_on_cycle` | unset | shell command run when a long break (cycle) begins |
| `@pomodoro_revamped_on_warn` | unset | shell command run at the end-of-phase warning |
| `@pomodoro_revamped_restart_key` | `R` | restart-phase key |
| `@pomodoro_revamped_menu_key` | `o` | control-menu key |
| `@pomodoro_revamped_help_key` | `?` | help-popup key |
| `@pomodoro_revamped_toggle_key` | `p` | start / pause / resume key |
| `@pomodoro_revamped_cancel_key` | `P` | cancel key |
| `@pomodoro_revamped_skip_key` | `_` | skip-phase key |
| `@pomodoro_revamped_{work,break,long_break}_color` | red, green, blue | per-phase color |
| `@pomodoro_revamped_{work,break,long_break}_icon` | empty | per-phase glyph, for example a Nerd Font tomato or coffee cup |
| `@pomodoro_revamped_pause_text` | ` paused` | text appended while paused |

## Compatibility

Works on every tmux version TPM supports, 1.9 and up, on Linux (x86_64 and arm64) and macOS (Intel and Apple Silicon). Notifications use `osascript` on macOS and `notify-send` on Linux when present; the timer itself needs neither.

## Development

```bash
make test    # bats suite
make lint    # shellcheck
make coverage  # kcov line coverage on Linux
```

The timer math lives in [`src/lib/pomodoro/pomodoro.sh`](src/lib/pomodoro/pomodoro.sh) as pure functions, the full work/break/long-break timeline as arithmetic over the elapsed seconds, validated with fixtures and no real clock.

## License

[MIT](LICENSE), copyright Gustavo Franco.
