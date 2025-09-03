#!/usr/bin/env bash
# Tests for linux_update helpers and orchestrator
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB_BASH_DISABLE_SELF_UPDATE=1
# Route tools to mocks before loading the lib
export APT_GET_BIN="${SCRIPT_DIR}/mocks/apt-get"
export DPKG_BIN="${SCRIPT_DIR}/mocks/dpkg"
export APT_MARK_BIN="${SCRIPT_DIR}/mocks/apt-mark"
export SYSTEMD_TMPFILES_BIN="${SCRIPT_DIR}/mocks/systemd-tmpfiles"
hash -r
source "${SCRIPT_DIR}/../lib_bash.sh"

# Override root check for tests
is_root() { return 0; }

run_tests() {
  local tmpdir mocklog phased
  tmpdir="$(mktemp -d)"; trap '[[ -n ${tmpdir-} ]] && rm -rf "${tmpdir}"' EXIT
  mocklog="$tmpdir/mock.log"; touch "$mocklog"
  phased="$tmpdir/phased.txt"
  export MOCK_LOG="$mocklog"
  export PHASED_FILE="$phased"
  printf 'foo\nbar\n' >"$phased"

  # 1) save shell state
  assert_pass "_lib_bash_save_shell_state"
  assert_contains "echo \"$LIB_BASH_SHELL_STATE\"" "set -o"

  # 2) apt update/configure
  : >"$mocklog"
  assert_pass "_lib_bash_apt_update"
  assert_contains "cat \"$mocklog\"" "apt-get update"
  assert_contains "cat \"$mocklog\"" "dpkg --configure -a"

  # 3) fix broken
  : >"$mocklog"
  assert_pass "_lib_bash_apt_fix"
  assert_contains "cat \"$mocklog\"" "apt-get --fix-broken install"

  # 4) upgrade
  : >"$mocklog"
  assert_pass "_lib_bash_apt_upgrade"
  assert_contains "cat \"$mocklog\"" "apt-get upgrade"

  # 5) dist-upgrade
  : >"$mocklog"
  assert_pass "_lib_bash_apt_dist_upgrade"
  assert_contains "cat \"$mocklog\"" "apt-get dist-upgrade"

  # 6) cleanup
  : >"$mocklog"
  assert_pass "_lib_bash_apt_cleanup"
  assert_contains "cat \"$mocklog\"" "apt-get autoclean"
  assert_contains "cat \"$mocklog\"" "apt-get autoremove --purge"
  assert_contains "cat \"$mocklog\"" "systemd-tmpfiles --create"

  # 7) force phased updates iterates packages
  printf 'foo\nbar\n' >"$phased"
  : >"$mocklog"
  assert_pass "_lib_bash_force_phased_updates"
  # expect reinstall called for foo then bar
  assert_contains "cat \"$mocklog\"" "apt-get install --reinstall"
  # phased file should now be empty
  assert_equal "wc -l < \"$phased\" | tr -d ' '" "0"

  # 8) restore state
  assert_pass "_lib_bash_restore_shell_state"

  # 9) orchestrator end-to-end with phased
  printf 'foo\nbar\n' >"$phased"
  : >"$mocklog"
  assert_pass "linux_update --force-phased-updates"
  assert_contains "cat \"$mocklog\"" "apt-get update"
  assert_contains "cat \"$mocklog\"" "dpkg --configure -a"
  assert_contains "cat \"$mocklog\"" "apt-get --fix-broken install"
  assert_contains "cat \"$mocklog\"" "apt-get upgrade"
  assert_contains "cat \"$mocklog\"" "apt-get dist-upgrade"
  assert_contains "cat \"$mocklog\"" "apt-get autoclean"
  assert_contains "cat \"$mocklog\"" "apt-get autoremove --purge"
  assert_contains "cat \"$mocklog\"" "systemd-tmpfiles --create"
}

run_tests
