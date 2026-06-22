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
