#!/usr/bin/env bash
#
# render.sh: format a pomodoro phase into a status segment.

[[ -n "${_POMODORO_REVAMPED_RENDER_LOADED:-}" ]] && return 0
_POMODORO_REVAMPED_RENDER_LOADED=1

_POMO_RENDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_POMO_RENDER_DIR}/../tmux/tmux-ops.sh"

_POMO_RESET="#[default]"

# Built-in per-phase colors. Icons default empty, so no Nerd Font is required.
_pomo_default_color() {
  case "${1}" in
    work)       echo "#[fg=red]" ;;
    break)      echo "#[fg=green]" ;;
    long_break) echo "#[fg=blue]" ;;
    *)          echo "" ;;
  esac
}

# pomodoro_render_segment PHASE REMAINING INDEX TOTAL PAUSED -> the styled segment.
pomodoro_render_segment() {
  local phase="${1}" remaining="${2}" index="${3}" total="${4}" paused="${5}"
  local color icon out
  color=$(get_tmux_option "@pomodoro_revamped_${phase}_color" "$(_pomo_default_color "${phase}")")
  icon=$(get_tmux_option "@pomodoro_revamped_${phase}_icon" "")
  out="$(pomodoro_format "${remaining}")"
  [[ "${paused}" == "1" ]] && out="${out}$(get_tmux_option "@pomodoro_revamped_pause_text" " paused")"
  if [[ "$(get_tmux_option "@pomodoro_revamped_show_interval" "1")" == "1" ]]; then
    out="${out} [${index}/${total}]"
  fi
  if [[ -n "${icon}" ]]; then
    echo "${color}${icon} ${out}${_POMO_RESET}"
  else
    echo "${color}${out}${_POMO_RESET}"
  fi
}

export -f _pomo_default_color
export -f pomodoro_render_segment
