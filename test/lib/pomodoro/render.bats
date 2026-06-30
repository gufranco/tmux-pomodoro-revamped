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

@test "render.sh - a progress bar is prepended when enabled" {
  set_tmux_option @pomodoro_revamped_show_progress "1"
  set_tmux_option @pomodoro_revamped_progress_width "4"
  run pomodoro_render_segment work 750 1 4 0 1500
  [[ "${output}" == "#[fg=red]##-- 12:30 [1/4]#[default]" ]]
}

@test "render.sh - the progress bar honors custom glyphs" {
  set_tmux_option @pomodoro_revamped_show_progress "1"
  set_tmux_option @pomodoro_revamped_progress_width "4"
  set_tmux_option @pomodoro_revamped_bar_filled "="
  set_tmux_option @pomodoro_revamped_bar_empty "."
  run pomodoro_render_segment work 0 1 4 0 1500
  [[ "${output}" == "#[fg=red]==== 00:00 [1/4]#[default]" ]]
}

@test "render.sh - the progress bar stays off without a phase length" {
  set_tmux_option @pomodoro_revamped_show_progress "1"
  run pomodoro_render_segment work 750 1 4 0 0
  [[ "${output}" == "#[fg=red]12:30 [1/4]#[default]" ]]
}

@test "render.sh - the finish time appends when enabled" {
  set_tmux_option @pomodoro_revamped_show_finish "1"
  run pomodoro_render_segment work 1400 1 4 0 1500 "14:32"
  [[ "${output}" == "#[fg=red]23:20 [1/4] ends 14:32#[default]" ]]
}

@test "render.sh - the finish time is skipped when empty" {
  set_tmux_option @pomodoro_revamped_show_finish "1"
  run pomodoro_render_segment work 1400 1 4 0 1500 ""
  [[ "${output}" == "#[fg=red]23:20 [1/4]#[default]" ]]
}

@test "render.sh - the daily goal counter appends when enabled" {
  set_tmux_option @pomodoro_revamped_show_goal "1"
  run pomodoro_render_segment work 1400 1 4 0 1500 "" 3 6
  [[ "${output}" == "#[fg=red]23:20 [1/4] 3/6#[default]" ]]
}

@test "render.sh - the goal counter is skipped without a goal" {
  set_tmux_option @pomodoro_revamped_show_goal "1"
  run pomodoro_render_segment work 1400 1 4 0 1500 "" 3 ""
  [[ "${output}" == "#[fg=red]23:20 [1/4]#[default]" ]]
}
