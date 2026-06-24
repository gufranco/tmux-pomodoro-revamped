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

@test "pomodoro.sh - notification fires once on a phase change" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_start 1000
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

@test "pomodoro.sh - status exports the segment for theme integration" {
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "$(get_tmux_option @pomodoro_status "")" == "${output}" ]]
  [[ -n "$(get_tmux_option @pomodoro_status "")" ]]
}

@test "pomodoro.sh - status export clears when idle" {
  set_tmux_option @pomodoro_status "stale"
  run main status
  [[ -z "$(get_tmux_option @pomodoro_status "")" ]]
}

@test "pomodoro.sh - main routes toggle, skip, and cancel" {
  _now() { echo 1000; }
  run main toggle
  [[ "$(get_tmux_option @pomodoro_revamped_state "")" == "running" ]]
  run main skip
  run main cancel
  [[ -z "$(get_tmux_option @pomodoro_revamped_state "")" ]]
}

@test "pomodoro.sh - host-probe seams are callable" {
  run _now
  run _run_hook "true"
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

@test "pomodoro.sh - junk minute and interval options fall back to defaults" {
  set_tmux_option @pomodoro_revamped_work "abc"
  set_tmux_option @pomodoro_revamped_break ""
  set_tmux_option @pomodoro_revamped_long_break "x"
  set_tmux_option @pomodoro_revamped_intervals "0"
  set_tmux_option @pomodoro_revamped_state running
  set_tmux_option @pomodoro_revamped_start 1000
  run main status
  [[ "${output}" == "#[fg=red]23:20 [1/4]#[default]" ]]
}

@test "pomodoro.sh - unknown subcommand produces no output" {
  run main bogus
  [[ -z "${output}" ]]
}
