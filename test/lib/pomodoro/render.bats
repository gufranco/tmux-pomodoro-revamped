#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _POMODORO_REVAMPED_LOADED _POMODORO_REVAMPED_RENDER_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/pomodoro/pomodoro.sh"
  source "${BATS_TEST_DIRNAME}/../../../src/lib/pomodoro/render.sh"
}

teardown() {
  cleanup_test_environment
}

@test "render.sh - _pomo_default_color covers the phases" {
  [[ "$(_pomo_default_color work)" == "#[fg=red]" ]]
  [[ "$(_pomo_default_color break)" == "#[fg=green]" ]]
  [[ "$(_pomo_default_color long_break)" == "#[fg=blue]" ]]
  [[ -z "$(_pomo_default_color other)" ]]
}

@test "render.sh - segment renders time and interval, no icon by default" {
  [[ "$(pomodoro_render_segment work 1400 1 4 0)" == "#[fg=red]23:20 [1/4]#[default]" ]]
}

@test "render.sh - segment shows a configured icon" {
  set_tmux_option @pomodoro_revamped_work_icon "W"
  [[ "$(pomodoro_render_segment work 1400 1 4 0)" == "#[fg=red]W 23:20 [1/4]#[default]" ]]
}

@test "render.sh - segment marks a paused timer" {
  [[ "$(pomodoro_render_segment break 60 2 4 1)" == "#[fg=green]01:00 paused [2/4]#[default]" ]]
}

@test "render.sh - the interval display can be hidden" {
  set_tmux_option @pomodoro_revamped_show_interval "0"
  [[ "$(pomodoro_render_segment work 1400 1 4 0)" == "#[fg=red]23:20#[default]" ]]
}
