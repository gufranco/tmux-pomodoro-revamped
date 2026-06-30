#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _POMODORO_REVAMPED_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/pomodoro/pomodoro.sh"
}

teardown() {
  cleanup_test_environment
}

@test "pomodoro_format renders MM:SS and clamps negatives" {
  [[ "$(pomodoro_format 0)" == "00:00" ]]
  [[ "$(pomodoro_format 65)" == "01:05" ]]
  [[ "$(pomodoro_format 1500)" == "25:00" ]]
  [[ "$(pomodoro_format -5)" == "00:00" ]]
  [[ "$(pomodoro_format junk)" == "00:00" ]]
}

@test "pomodoro_phase_at walks work then break periods" {
  [[ "$(pomodoro_phase_at 0 1500 300 900 4)" == "work 1500 1" ]]
  [[ "$(pomodoro_phase_at 100 1500 300 900 4)" == "work 1400 1" ]]
  [[ "$(pomodoro_phase_at 1500 1500 300 900 4)" == "break 300 1" ]]
  [[ "$(pomodoro_phase_at 1800 1500 300 900 4)" == "work 1500 2" ]]
}

@test "pomodoro_phase_at reaches the long break after the last work and wraps" {
  [[ "$(pomodoro_phase_at 0 100 20 50 2)" == "work 100 1" ]]
  [[ "$(pomodoro_phase_at 100 100 20 50 2)" == "break 20 1" ]]
  [[ "$(pomodoro_phase_at 120 100 20 50 2)" == "work 100 2" ]]
  [[ "$(pomodoro_phase_at 220 100 20 50 2)" == "long_break 50 2" ]]
  [[ "$(pomodoro_phase_at 270 100 20 50 2)" == "work 100 1" ]]
}

@test "pomodoro_phase_at survives a zero-length round" {
  [[ "$(pomodoro_phase_at 5 0 0 0 1)" == "work 0 1" ]]
}

@test "pomodoro_elapsed excludes accumulated and current pause time" {
  [[ "$(pomodoro_elapsed 1000 900 0 0)" == "100" ]]
  [[ "$(pomodoro_elapsed 1000 900 30 0)" == "70" ]]
  [[ "$(pomodoro_elapsed 1000 900 0 950)" == "50" ]]
  [[ "$(pomodoro_elapsed 1000 1200 0 0)" == "0" ]]
}

@test "pomodoro_percent reports elapsed fraction and guards the edges" {
  [[ "$(pomodoro_percent 100 100)" == "0" ]]
  [[ "$(pomodoro_percent 100 75)" == "25" ]]
  [[ "$(pomodoro_percent 100 0)" == "100" ]]
  [[ "$(pomodoro_percent 0 50)" == "0" ]]
  [[ "$(pomodoro_percent 100 -5)" == "100" ]]
  [[ "$(pomodoro_percent junk bad)" == "0" ]]
}

@test "pomodoro_bar fills proportionally with ASCII glyphs" {
  [[ "$(pomodoro_bar 0 4)" == "----" ]]
  [[ "$(pomodoro_bar 50 4)" == "##--" ]]
  [[ "$(pomodoro_bar 100 4)" == "####" ]]
  [[ "$(pomodoro_bar 150 4)" == "####" ]]
  [[ "$(pomodoro_bar 50 4 = .)" == "==.." ]]
  [[ -z "$(pomodoro_bar 50 0)" ]]
  [[ "$(pomodoro_bar junk junk)" == "--------" ]]
}

@test "pomodoro_sparkline scales counts against the maximum" {
  [[ "$(pomodoro_sparkline 0 0 0)" == "___" ]]
  [[ "$(pomodoro_sparkline 0 4 8)" == "_=@" ]]
  [[ "$(pomodoro_sparkline 8 8 8)" == "@@@" ]]
  [[ "$(pomodoro_sparkline 0 x 2)" == "__@" ]]
}

@test "pomodoro_hm_to_min converts and tolerates leading zeros" {
  [[ "$(pomodoro_hm_to_min 00:00)" == "0" ]]
  [[ "$(pomodoro_hm_to_min 01:30)" == "90" ]]
  [[ "$(pomodoro_hm_to_min 08:09)" == "489" ]]
  [[ "$(pomodoro_hm_to_min 23:59)" == "1439" ]]
}

@test "pomodoro_in_quiet matches same-day and wrapping windows" {
  run pomodoro_in_quiet "23:00" "22:00-07:00"
  [[ "${status}" -eq 0 ]]
  run pomodoro_in_quiet "05:00" "22:00-07:00"
  [[ "${status}" -eq 0 ]]
  run pomodoro_in_quiet "12:00" "22:00-07:00"
  [[ "${status}" -ne 0 ]]
  run pomodoro_in_quiet "13:00" "09:00-17:00"
  [[ "${status}" -eq 0 ]]
  run pomodoro_in_quiet "18:00" "09:00-17:00"
  [[ "${status}" -ne 0 ]]
}

@test "pomodoro_in_quiet rejects malformed input" {
  run pomodoro_in_quiet "nope" "22:00-07:00"
  [[ "${status}" -ne 0 ]]
  run pomodoro_in_quiet "23:00" "noseparator"
  [[ "${status}" -ne 0 ]]
  run pomodoro_in_quiet "23:00" "bad-07:00"
  [[ "${status}" -ne 0 ]]
  run pomodoro_in_quiet "23:00" "22:00-bad"
  [[ "${status}" -ne 0 ]]
}

@test "pomodoro_week_index maps epoch days to Sunday-zero indices" {
  [[ "$(pomodoro_week_index 0)" == "4" ]]
  [[ "$(pomodoro_week_index 3)" == "0" ]]
  [[ "$(pomodoro_week_index 4)" == "1" ]]
  [[ "$(pomodoro_week_index junk)" == "4" ]]
}

@test "pomodoro_week_today reads a slot and defaults to zero" {
  [[ "$(pomodoro_week_today "1,2,3,4,5,6,7" 0)" == "1" ]]
  [[ "$(pomodoro_week_today "1,2,3,4,5,6,7" 6)" == "7" ]]
  [[ "$(pomodoro_week_today "1,2" 5)" == "0" ]]
  [[ "$(pomodoro_week_today "x,2" 0)" == "0" ]]
  [[ "$(pomodoro_week_today "1,2,3,4,5,6,7" junk)" == "1" ]]
}

@test "pomodoro_week_record increments today on the same day" {
  # epoch day 3 maps to index 0 (Sunday)
  [[ "$(pomodoro_week_record "0,0,0,0,0,0,0" 3 3)" == "1,0,0,0,0,0,0 3" ]]
  [[ "$(pomodoro_week_record "1,0,0,0,0,0,0" 3 3)" == "2,0,0,0,0,0,0 3" ]]
}

@test "pomodoro_week_record zeroes the slot when the day advances" {
  # day 3 (idx 0) -> day 4 (idx 1): only the new day's slot is fresh
  [[ "$(pomodoro_week_record "5,9,0,0,0,0,0" 3 4)" == "5,1,0,0,0,0,0 4" ]]
}

@test "pomodoro_week_record clears the whole ring after a week gap" {
  [[ "$(pomodoro_week_record "5,5,5,5,5,5,5" 3 20)" == "0,0,0,1,0,0,0 20" ]]
}

@test "pomodoro_week_record resets on a backward clock and seeds a fresh ring" {
  [[ "$(pomodoro_week_record "5,5,5,5,5,5,5" 10 3)" == "1,0,0,0,0,0,0 3" ]]
  [[ "$(pomodoro_week_record "0,0,0,0,0,0,0" "" 3)" == "1,0,0,0,0,0,0 3" ]]
  [[ "$(pomodoro_week_record "0,0,0,0,0,0,0" "" junk)" == "0,0,0,0,1,0,0 0" ]]
}
