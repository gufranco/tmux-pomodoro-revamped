#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _POMODORO_REVAMPED_LOADED _POMODORO_REVAMPED_RENDER_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/pomodoro.sh"
  _now() { echo 1100; }
  _notify() { echo "$*" >> "${BATS_TEST_TMPDIR}/notified"; }
}

teardown() {
  cleanup_test_environment
}

@test "pomodoro.sh - functions are defined" {
  function_exists pomodoro_status
  function_exists pomodoro_toggle
  function_exists pomodoro_cancel
  function_exists pomodoro_skip
  function_exists pomodoro_restart
  function_exists pomodoro_menu
  function_exists pomodoro_help
}

@test "pomodoro.sh - status is empty when idle" {
  run main status
  [[ -z "${output}" ]]
}

@test "pomodoro.sh - toggle starts a session from idle" {
  _now() { echo 1000; }
  pomodoro_toggle
  [[ "$(get_tmux_option @pomodoro_revamped_state "")" == "running" ]]
  [[ "$(get_tmux_option @pomodoro_revamped_start "")" == "1000" ]]
}

@test "pomodoro.sh - toggle pauses a running session" {
  set_tmux_option @pomodoro_revamped_state running
  pomodoro_toggle
  [[ "$(get_tmux_option @pomodoro_revamped_state "")" == "paused" ]]
  [[ "$(get_tmux_option @pomodoro_revamped_paused_at "")" == "1100" ]]
}

@test "pomodoro.sh - toggle resumes and accumulates paused time" {
  set_tmux_option @pomodoro_revamped_state paused
  set_tmux_option @pomodoro_revamped_paused_at 1070
  set_tmux_option @pomodoro_revamped_paused_total 0
  pomodoro_toggle
  [[ "$(get_tmux_option @pomodoro_revamped_state "")" == "running" ]]
  [[ "$(get_tmux_option @pomodoro_revamped_paused_total "")" == "30" ]]
  [[ "$(get_tmux_option @pomodoro_revamped_paused_at "")" == "0" ]]
}

@test "pomodoro.sh - cancel clears the state" {
  set_tmux_option @pomodoro_revamped_state running
  pomodoro_cancel
  [[ -z "$(get_tmux_option @pomodoro_revamped_state "")" ]]
}

@test "pomodoro.sh - status renders the work phase countdown" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "${output}" == "#[fg=red]23:20 [1/4]#[default]" ]]
}

@test "pomodoro.sh - skip jumps to the next phase" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_start 1000
  pomodoro_skip
  run main status
  [[ "${output}" == "#[fg=green]"*"[1/4]#[default]" ]]
}

@test "pomodoro.sh - skip is a no-op when idle" {
  run main skip
  [[ -z "$(get_tmux_option @pomodoro_revamped_start "")" ]]
}

@test "pomodoro.sh - restart rewinds the current phase to full" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_start 1000
  pomodoro_restart
  [[ "$(get_tmux_option @pomodoro_revamped_start "")" == "1100" ]]
  run main status
  [[ "${output}" == "#[fg=red]25:00 [1/4]#[default]" ]]
}

@test "pomodoro.sh - restart is a no-op when idle" {
  run main restart
  [[ -z "$(get_tmux_option @pomodoro_revamped_start "")" ]]
}

@test "pomodoro.sh - notification fires once on a phase change" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start -400
  run main status
  [[ -f "${BATS_TEST_TMPDIR}/notified" ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/notified")" == *"break"* ]]
}

@test "pomodoro.sh - notification announces a work transition" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase break
  set_tmux_option @pomodoro_revamped_start 1100
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/notified")" == *"work"* ]]
}

@test "pomodoro.sh - notification announces a long break transition" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start -5800
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/notified")" == *"long break"* ]]
}

@test "pomodoro.sh - a transition runs the configured hook command" {
  _run_hook() { echo "HOOK:$*" >> "${BATS_TEST_TMPDIR}/hook"; }
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_on_break "play-sound"
  set_tmux_option @pomodoro_revamped_start -400
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/hook")" == "HOOK:play-sound" ]]
}

@test "pomodoro.sh - a full cycle runs the cycle hook" {
  _run_hook() { echo "HOOK:$*" >> "${BATS_TEST_TMPDIR}/hook"; }
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_on_cycle "log-cycle"
  set_tmux_option @pomodoro_revamped_start -5800
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/hook")" == *"HOOK:log-cycle"* ]]
}

@test "pomodoro.sh - the hook runs even when notifications are off" {
  _run_hook() { echo "HOOK:$*" >> "${BATS_TEST_TMPDIR}/hook"; }
  set_tmux_option @pomodoro_revamped_notifications 0
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_on_break "play-sound"
  set_tmux_option @pomodoro_revamped_start -400
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/hook")" == "HOOK:play-sound" ]]
  [[ ! -f "${BATS_TEST_TMPDIR}/notified" ]]
}

@test "pomodoro.sh - a phase change records a completed work period" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start -400
  run main status
  # _now 1100 -> epoch day 0 -> index 4
  [[ "$(get_tmux_option @pomodoro_revamped_week_counts "")" == "0,0,0,0,1,0,0" ]]
  [[ "$(get_tmux_option @pomodoro_revamped_week_day "")" == "0" ]]
}

@test "pomodoro.sh - status exports machine-readable sibling tokens" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "$(get_tmux_option @pomodoro_phase "")" == "work" ]]
  [[ "$(get_tmux_option @pomodoro_remaining "")" == "1400" ]]
  [[ "$(get_tmux_option @pomodoro_fraction "")" == "6" ]]
  [[ -n "$(get_tmux_option @pomodoro_week "")" ]]
}

@test "pomodoro.sh - the weekly sparkline reflects recorded counts" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_week_counts "0,0,0,0,4,0,0"
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "$(get_tmux_option @pomodoro_week "")" == "____@__" ]]
}

@test "pomodoro.sh - the end-of-phase warning fires once" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_warn_seconds 60
  set_tmux_option @pomodoro_revamped_start -370
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/notified")" == *"minute"* ]]
  [[ "$(get_tmux_option @pomodoro_revamped_warned "")" == "1" ]]
  rm -f "${BATS_TEST_TMPDIR}/notified"
  run main status
  [[ ! -f "${BATS_TEST_TMPDIR}/notified" ]]
}

@test "pomodoro.sh - the warning is suppressed while paused" {
  set_tmux_option @pomodoro_revamped_state paused
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_paused_at 1100
  set_tmux_option @pomodoro_revamped_warn_seconds 60
  set_tmux_option @pomodoro_revamped_start -370
  run main status
  [[ ! -f "${BATS_TEST_TMPDIR}/notified" ]]
}

@test "pomodoro.sh - the warning runs its own hook" {
  _run_hook() { echo "HOOK:$*" >> "${BATS_TEST_TMPDIR}/hook"; }
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_warn_seconds 60
  set_tmux_option @pomodoro_revamped_on_warn "ping"
  set_tmux_option @pomodoro_revamped_start -370
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/hook")" == *"HOOK:ping"* ]]
}

@test "pomodoro.sh - quiet hours suppress the alert" {
  _fmt_hm() { echo "23:30"; }
  set_tmux_option @pomodoro_revamped_quiet_hours "22:00-07:00"
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start -400
  run main status
  [[ ! -f "${BATS_TEST_TMPDIR}/notified" ]]
}

@test "pomodoro.sh - outside quiet hours the alert fires" {
  _fmt_hm() { echo "12:30"; }
  set_tmux_option @pomodoro_revamped_quiet_hours "22:00-07:00"
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start -400
  run main status
  [[ "$(cat "${BATS_TEST_TMPDIR}/notified")" == *"break"* ]]
}

@test "pomodoro.sh - the bell rings on a transition when enabled" {
  export POMODORO_BELL_SINK="${BATS_TEST_TMPDIR}/bell"
  set_tmux_option @pomodoro_revamped_bell 1
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start -400
  run main status
  [[ -s "${BATS_TEST_TMPDIR}/bell" ]]
}

@test "pomodoro.sh - the finish time appears when enabled" {
  _fmt_hm() { echo "14:32"; }
  set_tmux_option @pomodoro_revamped_show_finish 1
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "${output}" == *"ends 14:32"* ]]
}

@test "pomodoro.sh - the daily goal appears when enabled" {
  set_tmux_option @pomodoro_revamped_show_goal 1
  set_tmux_option @pomodoro_revamped_goal 6
  set_tmux_option @pomodoro_revamped_week_counts "0,0,0,0,2,0,0"
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "${output}" == *"2/6"* ]]
}

@test "pomodoro.sh - status exports the segment for theme integration" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "$(get_tmux_option @pomodoro_status "")" == "${output}" ]]
  [[ -n "$(get_tmux_option @pomodoro_status "")" ]]
}

@test "pomodoro.sh - status export clears when idle" {
  set_tmux_option @pomodoro_status "stale"
  set_tmux_option @pomodoro_phase "work"
  run main status
  [[ -z "$(get_tmux_option @pomodoro_status "")" ]]
  [[ -z "$(get_tmux_option @pomodoro_phase "")" ]]
}

@test "pomodoro.sh - the control menu routes through the tmux seam" {
  _tmux() { echo "$1" >> "${BATS_TEST_TMPDIR}/seam"; }
  run main menu
  [[ "$(cat "${BATS_TEST_TMPDIR}/seam")" == "display-menu" ]]
}

@test "pomodoro.sh - the help popup routes through the tmux seam" {
  _tmux() { echo "$1" >> "${BATS_TEST_TMPDIR}/seam"; }
  run main help
  [[ "$(cat "${BATS_TEST_TMPDIR}/seam")" == "display-popup" ]]
}

@test "pomodoro.sh - main routes toggle, skip, and cancel" {
  _now() { echo 1000; }
  run main toggle
  [[ "$(get_tmux_option @pomodoro_revamped_state "")" == "running" ]]
  run main skip
  run main cancel
  [[ -z "$(get_tmux_option @pomodoro_revamped_state "")" ]]
}

@test "pomodoro.sh - _pomo_phase_len covers every phase" {
  [[ "$(_pomo_phase_len work)" == "1500" ]]
  [[ "$(_pomo_phase_len break)" == "300" ]]
  [[ "$(_pomo_phase_len long_break)" == "900" ]]
  [[ "$(_pomo_phase_len other)" == "0" ]]
}

@test "pomodoro.sh - host-probe seams are callable" {
  run _now
  run _run_hook "true"
  run _tmux display-message hi
  local bin="${BATS_TEST_TMPDIR}/nbin"
  mkdir -p "${bin}"
  printf '#!/bin/sh\nexit 0\n' > "${bin}/osascript"
  printf '#!/bin/sh\nexit 0\n' > "${bin}/notify-send"
  chmod +x "${bin}/osascript" "${bin}/notify-send"
  PATH="${bin}" run _notify "Title" "Message"
  rm "${bin}/osascript"
  PATH="${bin}" run _notify "Title" "Message"
  true
}

@test "pomodoro.sh - the clock-format seam returns HH:MM" {
  run _fmt_hm 1000000
  [[ "${output}" =~ ^[0-9]{2}:[0-9]{2}$ ]]
}

@test "pomodoro.sh - the bell seam writes to its sink" {
  POMODORO_BELL_SINK="${BATS_TEST_TMPDIR}/bell" _bell
  [[ -s "${BATS_TEST_TMPDIR}/bell" ]]
}

@test "pomodoro.sh - junk minute and interval options fall back to defaults" {
  set_tmux_option @pomodoro_revamped_work "abc"
  set_tmux_option @pomodoro_revamped_break ""
  set_tmux_option @pomodoro_revamped_long_break "x"
  set_tmux_option @pomodoro_revamped_intervals "0"
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_last_phase work
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "${output}" == "#[fg=red]23:20 [1/4]#[default]" ]]
}

@test "pomodoro.sh - unknown subcommand produces no output" {
  run main bogus
  [[ -z "${output}" ]]
}
