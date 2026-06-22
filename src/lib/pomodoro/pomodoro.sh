#!/usr/bin/env bash
#
# pomodoro.sh: pure timer math for tmux-pomodoro-revamped.
#
# The whole timeline is a pure function of the elapsed seconds and the work, break,
# and long-break durations, so there is no per-tick state to mutate and nothing to
# store in a temp file. The running state lives in tmux server options; this file
# only does arithmetic and is fully fixture-testable.

[[ -n "${_POMODORO_REVAMPED_LOADED:-}" ]] && return 0
_POMODORO_REVAMPED_LOADED=1

# pomodoro_format SECONDS -> MM:SS, clamped at zero.
pomodoro_format() {
  local s="${1}"
  [[ "${s}" =~ ^-?[0-9]+$ ]] || s=0
  (( s < 0 )) && s=0
  printf '%02d:%02d' "$(( s / 60 ))" "$(( s % 60 ))"
}

# pomodoro_phase_at ELAPSED WORK BREAK LONG INTERVALS -> "PHASE REMAINING INDEX".
# PHASE is work, break, or long_break. REMAINING is seconds left in the phase.
# INDEX is the work-period number, 1..INTERVALS. One round is INTERVALS work
# periods separated by short breaks and closed by a long break, then it repeats.
pomodoro_phase_at() {
  local e="${1}" w="${2}" b="${3}" l="${4}" n="${5}"
  (( e < 0 )) && e=0
  local round=$(( n * w + (n - 1) * b + l ))
  (( round <= 0 )) && { echo "work ${w} 1"; return 0; }
  local pos=$(( e % round )) i=0
  while (( i < n )); do
    i=$(( i + 1 ))
    if (( pos < w )); then echo "work $(( w - pos )) ${i}"; return 0; fi
    pos=$(( pos - w ))
    if (( i == n )); then echo "long_break $(( l - pos )) ${i}"; return 0; fi
    if (( pos < b )); then echo "break $(( b - pos )) ${i}"; return 0; fi
    pos=$(( pos - b ))
  done
  echo "work ${w} 1"
}

# pomodoro_elapsed NOW START PAUSED_TOTAL PAUSED_AT -> active seconds since START,
# excluding paused time. PAUSED_AT is 0 when running, else the pause epoch.
pomodoro_elapsed() {
  local now="${1}" start="${2}" paused_total="${3}" paused_at="${4}"
  local e=$(( now - start - paused_total ))
  (( paused_at > 0 )) && e=$(( e - (now - paused_at) ))
  (( e < 0 )) && e=0
  echo "${e}"
}

export -f pomodoro_format
export -f pomodoro_phase_at
export -f pomodoro_elapsed
