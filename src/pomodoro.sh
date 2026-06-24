#!/usr/bin/env bash
#
# pomodoro.sh: command dispatcher for tmux-pomodoro-revamped.
#
# Usage: pomodoro.sh status | toggle | cancel | skip
#
# All timer state lives in tmux server options: the start epoch, accumulated pause
# time, and the running/paused flag. The current phase is computed from elapsed
# time on demand, so there is no background process and no temp file.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/pomodoro/pomodoro.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/pomodoro/render.sh"

# Host-probe seams. Tests override these.
_now() { date +%s 2>/dev/null || echo 0; }
_notify() {
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${2}\" with title \"${1}\"" >/dev/null 2>&1
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "${1}" "${2}" >/dev/null 2>&1
  fi
}
# _run_hook CMD -> run a user transition command in the background, managed by
# tmux so the status render never waits on it.
_run_hook() { tmux run-shell -b -- "${1}" 2>/dev/null; }

_pomo_minutes() {
  local m
  m=$(get_tmux_option "${1}" "${2}")
  [[ "${m}" =~ ^[0-9]+$ ]] || m="${2}"
  echo $(( m * 60 ))
}
_work_secs() { _pomo_minutes "@pomodoro_revamped_work" "25"; }
_break_secs() { _pomo_minutes "@pomodoro_revamped_break" "5"; }
_long_secs() { _pomo_minutes "@pomodoro_revamped_long_break" "15"; }
_intervals() {
  local n
  n=$(get_tmux_option "@pomodoro_revamped_intervals" "4")
  { [[ "${n}" =~ ^[0-9]+$ ]] && (( n > 0 )); } || n=4
  echo "${n}"
}

# _pomo_current -> "PHASE REMAINING INDEX STATE", or non-zero when idle.
_pomo_current() {
  local state start ptotal pat now elapsed
  state=$(get_tmux_option "@pomodoro_revamped_state" "")
  [[ -z "${state}" ]] && return 1
  start=$(get_tmux_option "@pomodoro_revamped_start" "0")
  ptotal=$(get_tmux_option "@pomodoro_revamped_paused_total" "0")
  pat=$(get_tmux_option "@pomodoro_revamped_paused_at" "0")
  [[ "${state}" == "paused" ]] || pat=0
  now=$(_now)
  elapsed=$(pomodoro_elapsed "${now}" "${start}" "${ptotal}" "${pat}")
  local phase remaining index
  read -r phase remaining index < <(pomodoro_phase_at "${elapsed}" "$(_work_secs)" "$(_break_secs)" "$(_long_secs)" "$(_intervals)")
  echo "${phase} ${remaining} ${index} ${state}"
}

# _pomo_run_hook PHASE -> run the configured transition command for PHASE, if any.
_pomo_run_hook() {
  local cmd
  cmd=$(get_tmux_option "@pomodoro_revamped_on_${1}" "")
  [[ -n "${cmd}" ]] && _run_hook "${cmd}"
}

# _pomo_maybe_notify PHASE -> on a phase change, run the transition hook and fire
# a notification. The hook runs whether or not notifications are enabled; only the
# desktop notification is gated.
_pomo_maybe_notify() {
  local last
  last=$(get_tmux_option "@pomodoro_revamped_last_phase" "")
  [[ "${last}" == "${1}" ]] && return 0
  set_tmux_option "@pomodoro_revamped_last_phase" "${1}"
  [[ -z "${last}" ]] && return 0
  _pomo_run_hook "${1}"
  [[ "$(get_tmux_option "@pomodoro_revamped_notifications" "1")" == "1" ]] || return 0
  case "${1}" in
    work)       _notify "Pomodoro" "Back to work" ;;
    break)      _notify "Pomodoro" "Take a short break" ;;
    long_break) _notify "Pomodoro" "Take a long break" ;;
  esac
}

pomodoro_status() {
  local cur
  cur="$(_pomo_current)" || { set_tmux_option "@pomodoro_status" ""; return 0; }
  local phase remaining index state
  read -r phase remaining index state <<< "${cur}"
  _pomo_maybe_notify "${phase}"
  local paused=0
  [[ "${state}" == "paused" ]] && paused=1
  local segment
  segment="$(pomodoro_render_segment "${phase}" "${remaining}" "${index}" "$(_intervals)" "${paused}")"
  # Export the rendered segment so a theme can read it via #{@pomodoro_status}.
  set_tmux_option "@pomodoro_status" "${segment}"
  printf '%s\n' "${segment}"
}

pomodoro_toggle() {
  local state now
  state=$(get_tmux_option "@pomodoro_revamped_state" "")
  now=$(_now)
  case "${state}" in
    "")
      set_tmux_option "@pomodoro_revamped_state" "running"
      set_tmux_option "@pomodoro_revamped_start" "${now}"
      set_tmux_option "@pomodoro_revamped_paused_total" "0"
      set_tmux_option "@pomodoro_revamped_paused_at" "0"
      set_tmux_option "@pomodoro_revamped_last_phase" ""
      ;;
    running)
      set_tmux_option "@pomodoro_revamped_state" "paused"
      set_tmux_option "@pomodoro_revamped_paused_at" "${now}"
      ;;
    paused)
      local pat ptotal
      pat=$(get_tmux_option "@pomodoro_revamped_paused_at" "0")
      ptotal=$(get_tmux_option "@pomodoro_revamped_paused_total" "0")
      set_tmux_option "@pomodoro_revamped_paused_total" "$(( ptotal + (now - pat) ))"
      set_tmux_option "@pomodoro_revamped_paused_at" "0"
      set_tmux_option "@pomodoro_revamped_state" "running"
      ;;
  esac
}

pomodoro_cancel() {
  set_tmux_option "@pomodoro_revamped_state" ""
  set_tmux_option "@pomodoro_revamped_last_phase" ""
}

pomodoro_skip() {
  local cur
  cur="$(_pomo_current)" || return 0
  local phase remaining index state start
  read -r phase remaining index state <<< "${cur}"
  start=$(get_tmux_option "@pomodoro_revamped_start" "0")
  set_tmux_option "@pomodoro_revamped_start" "$(( start - remaining ))"
}

main() {
  case "${1:-}" in
    status) pomodoro_status ;;
    toggle) pomodoro_toggle ;;
    cancel) pomodoro_cancel ;;
    skip)   pomodoro_skip ;;
    *)      return 0 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
