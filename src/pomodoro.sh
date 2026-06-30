#!/usr/bin/env bash
#
# pomodoro.sh: command dispatcher for tmux-pomodoro-revamped.
#
# Usage: pomodoro.sh status | toggle | cancel | skip | restart | menu | help
#
# All timer state lives in tmux server options: the start epoch, accumulated pause
# time, and the running/paused flag. The current phase is computed from elapsed
# time on demand, so there is no background process and no temp file.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POMO_SELF="${BASH_SOURCE[0]}"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/pomodoro/pomodoro.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/pomodoro/render.sh"

# Host-probe seams. Tests override these so no real notification, bell, popup, or
# clock call is ever made during the suite.
_now() { date +%s 2>/dev/null || echo 0; }
_notify() {
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${2}\" with title \"${1}\"" >/dev/null 2>&1
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "${1}" "${2}" >/dev/null 2>&1
  fi
}
# _fmt_hm EPOCH -> "HH:MM" in local time. BSD date uses -r, GNU date uses -d.
_fmt_hm() { date -r "${1}" +%H:%M 2>/dev/null || date -d "@${1}" +%H:%M 2>/dev/null || echo "??:??"; }
# _bell -> ring the terminal bell, an SSH-friendly fallback when no desktop
# notifier exists. The sink is a real tty in production and a file under test.
_bell() { printf '\a' >> "${POMODORO_BELL_SINK:-/dev/tty}" 2>/dev/null || true; }
# _tmux -> the single seam every interactive tmux call routes through (display-menu,
# display-popup). Tests mock it so a real menu or popup is never launched.
_tmux() { tmux "$@"; }
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

# _pomo_phase_len PHASE -> the configured length in seconds for PHASE.
_pomo_phase_len() {
  case "${1}" in
    work)       _work_secs ;;
    break)      _break_secs ;;
    long_break) _long_secs ;;
    *)          echo 0 ;;
  esac
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
# PHASE also covers the synthetic "cycle" and "warn" hook names.
_pomo_run_hook() {
  local cmd
  cmd=$(get_tmux_option "@pomodoro_revamped_on_${1}" "")
  [[ -n "${cmd}" ]] && _run_hook "${cmd}"
  return 0
}

# _pomo_in_quiet -> 0 when the current local time falls inside the configured
# quiet-hours window. Timing keeps running; only alerts are suppressed.
_pomo_in_quiet() {
  local win
  win=$(get_tmux_option "@pomodoro_revamped_quiet_hours" "")
  [[ -z "${win}" ]] && return 1
  pomodoro_in_quiet "$(_fmt_hm "$(_now)")" "${win}"
}

# _pomo_alert PHASE -> fire the desktop notification and optional bell for a phase
# change, both suppressed during quiet hours.
_pomo_alert() {
  _pomo_in_quiet && return 0
  [[ "$(get_tmux_option "@pomodoro_revamped_bell" "0")" == "1" ]] && _bell
  [[ "$(get_tmux_option "@pomodoro_revamped_notifications" "1")" == "1" ]] || return 0
  case "${1}" in
    work)       _notify "Pomodoro" "Back to work" ;;
    break)      _notify "Pomodoro" "Take a short break" ;;
    long_break) _notify "Pomodoro" "Take a long break" ;;
  esac
}

# _pomo_record_week -> add one completed work period to the rolling weekly ring.
_pomo_record_week() {
  local counts last cur res
  counts=$(get_tmux_option "@pomodoro_revamped_week_counts" "0,0,0,0,0,0,0")
  last=$(get_tmux_option "@pomodoro_revamped_week_day" "")
  cur=$(( $(_now) / 86400 ))
  res=$(pomodoro_week_record "${counts}" "${last}" "${cur}")
  set_tmux_option "@pomodoro_revamped_week_counts" "${res% *}"
  set_tmux_option "@pomodoro_revamped_week_day" "${res##* }"
}

# _pomo_today_count -> completed work periods recorded for the current day.
_pomo_today_count() {
  local counts idx
  counts=$(get_tmux_option "@pomodoro_revamped_week_counts" "0,0,0,0,0,0,0")
  idx=$(pomodoro_week_index "$(( $(_now) / 86400 ))")
  pomodoro_week_today "${counts}" "${idx}"
}

# _pomo_maybe_notify PHASE -> on a phase change, record the finished work period,
# run the transition and cycle hooks, and fire the alert. The warning flag resets
# on every change so the next phase can warn once.
_pomo_maybe_notify() {
  local last
  last=$(get_tmux_option "@pomodoro_revamped_last_phase" "")
  [[ "${last}" == "${1}" ]] && return 0
  set_tmux_option "@pomodoro_revamped_last_phase" "${1}"
  set_tmux_option "@pomodoro_revamped_warned" ""
  [[ -z "${last}" ]] && return 0
  [[ "${last}" == "work" ]] && _pomo_record_week
  _pomo_run_hook "${1}"
  [[ "${1}" == "long_break" ]] && _pomo_run_hook "cycle"
  _pomo_alert "${1}"
}

# _pomo_warn PHASE REMAINING STATE -> once per phase, alert when less than the
# configured number of seconds remain. Disabled by default (warn_seconds 0).
_pomo_warn() {
  local phase="${1}" remaining="${2}" state="${3}" w
  [[ "${state}" == "paused" ]] && return 0
  w=$(get_tmux_option "@pomodoro_revamped_warn_seconds" "0")
  [[ "${w}" =~ ^[0-9]+$ ]] || w=0
  (( w <= 0 )) && return 0
  (( remaining <= 0 || remaining > w )) && return 0
  [[ "$(get_tmux_option "@pomodoro_revamped_warned" "")" == "1" ]] && return 0
  set_tmux_option "@pomodoro_revamped_warned" "1"
  _pomo_run_hook "warn"
  _pomo_in_quiet && return 0
  [[ "$(get_tmux_option "@pomodoro_revamped_notifications" "1")" == "1" ]] || return 0
  _notify "Pomodoro" "Less than a minute left"
}

# _pomo_export_tokens PHASE REMAINING LEN -> publish machine-readable options that
# sibling plugins and themes can read without invoking the script.
_pomo_export_tokens() {
  local phase="${1}" remaining="${2}" len="${3}" counts spark
  set_tmux_option "@pomodoro_phase" "${phase}"
  set_tmux_option "@pomodoro_remaining" "${remaining}"
  set_tmux_option "@pomodoro_fraction" "$(pomodoro_percent "${len}" "${remaining}")"
  counts=$(get_tmux_option "@pomodoro_revamped_week_counts" "0,0,0,0,0,0,0")
  # shellcheck disable=SC2046
  spark=$(pomodoro_sparkline $(echo "${counts}" | tr ',' ' '))
  set_tmux_option "@pomodoro_week" "${spark}"
  set_tmux_option "@pomodoro_today" "$(_pomo_today_count)"
}

# _pomo_clear_tokens -> wipe every exported option when the timer is idle.
_pomo_clear_tokens() {
  set_tmux_option "@pomodoro_status" ""
  set_tmux_option "@pomodoro_phase" ""
  set_tmux_option "@pomodoro_remaining" ""
  set_tmux_option "@pomodoro_fraction" ""
}

pomodoro_status() {
  local cur
  cur="$(_pomo_current)" || { _pomo_clear_tokens; return 0; }
  local phase remaining index state
  read -r phase remaining index state <<< "${cur}"
  _pomo_maybe_notify "${phase}"
  _pomo_warn "${phase}" "${remaining}" "${state}"
  local paused=0
  [[ "${state}" == "paused" ]] && paused=1
  local len finish="" done="" goal=""
  len=$(_pomo_phase_len "${phase}")
  if [[ "$(get_tmux_option "@pomodoro_revamped_show_finish" "0")" == "1" ]]; then
    finish=$(_fmt_hm "$(( $(_now) + remaining ))")
  fi
  if [[ "$(get_tmux_option "@pomodoro_revamped_show_goal" "0")" == "1" ]]; then
    done=$(_pomo_today_count)
    goal=$(get_tmux_option "@pomodoro_revamped_goal" "6")
  fi
  local segment
  segment="$(pomodoro_render_segment "${phase}" "${remaining}" "${index}" "$(_intervals)" "${paused}" "${len}" "${finish}" "${done}" "${goal}")"
  # Export the rendered segment so a theme can read it via #{@pomodoro_status}.
  set_tmux_option "@pomodoro_status" "${segment}"
  _pomo_export_tokens "${phase}" "${remaining}" "${len}"
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
      set_tmux_option "@pomodoro_revamped_warned" ""
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

# pomodoro_restart -> rewind the current phase to its beginning by advancing the
# start epoch past the time already spent in this phase.
pomodoro_restart() {
  local cur
  cur="$(_pomo_current)" || return 0
  local phase remaining index state start len
  read -r phase remaining index state <<< "${cur}"
  start=$(get_tmux_option "@pomodoro_revamped_start" "0")
  len=$(_pomo_phase_len "${phase}")
  set_tmux_option "@pomodoro_revamped_start" "$(( start + (len - remaining) ))"
  set_tmux_option "@pomodoro_revamped_warned" ""
}

# pomodoro_menu -> a control menu of the timer actions, via the _tmux seam.
pomodoro_menu() {
  _tmux display-menu -T "Pomodoro" \
    "Start / Pause" "" "run-shell \"${POMO_SELF} toggle\"" \
    "Skip phase" "" "run-shell \"${POMO_SELF} skip\"" \
    "Restart phase" "" "run-shell \"${POMO_SELF} restart\"" \
    "Cancel" "" "run-shell \"${POMO_SELF} cancel\""
}

# pomodoro_help -> a help popup listing the keys and tokens, via the _tmux seam.
pomodoro_help() {
  _tmux display-popup -E "printf '%s\\n' 'tmux-pomodoro-revamped' 'toggle, cancel, skip, restart, menu, help' 'tokens: #{@pomodoro_status} #{@pomodoro_week}'; read -r"
}

main() {
  case "${1:-}" in
    status)  pomodoro_status ;;
    toggle)  pomodoro_toggle ;;
    cancel)  pomodoro_cancel ;;
    skip)    pomodoro_skip ;;
    restart) pomodoro_restart ;;
    menu)    pomodoro_menu ;;
    help)    pomodoro_help ;;
    *)       return 0 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
