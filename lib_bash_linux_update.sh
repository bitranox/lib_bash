# lib_bash_linux_update.sh — linux_update orchestrator + helpers
#
# Purpose:
# - Provide the linux_update orchestrator and small, testable helpers for APT-based
#   maintenance flows (update, fix, upgrade, dist-upgrade, cleanup, phased updates).
#
# How it is used:
# - This file is sourced by lib_bash.sh in _source_submodules(). Do not execute directly.
# - External callers should invoke linux_update [--force-phased-updates].
#
# Dependencies (provided by lib_bash.sh):
# - Logging: log, log_ok, log_warn, log_err, logc
# - Root check: _exit_if_not_is_root
# - Wrappers: _apt, _dpkg, _apt_mark, _systemd_tmpfiles (env-overridable in tests)
# - Misc: is_root(), etc.  Note: reinstall_packages() intentionally remains
#   in lib_bash.sh (public helper) and is invoked by the phased-updates loop.
#
# Conventions:
# - Internal helpers are prefixed with an underscore and may change without notice.
# - linux_update orchestrates the sequence and restores the caller shell state.
# - The phased updates loop is guarded to avoid infinite runs when _apt is missing.
#
############################################
# Linux update helpers (split for testability)
############################################

# internal: keeps last saved shell/trap state
LIB_BASH_SHELL_STATE=""
LIB_BASH_TRAP_STATE=""

_lib_bash_save_shell_state() {
    # Save shell options and ERR trap, then relax strict mode for apt flows
    # Stores in LIB_BASH_SHELL_STATE / LIB_BASH_TRAP_STATE
    # shellcheck disable=SC2034
    LIB_BASH_SHELL_STATE=$(set +o)
    # shellcheck disable=SC2034
    LIB_BASH_TRAP_STATE=$(trap -p ERR)
    set +eEuo pipefail
    trap - ERR
}

_lib_bash_apt_update() {
    log "apt-get update"
    logc _apt update
    log "dpkg --configure -a"
    logc _dpkg --configure -a
}

_lib_bash_apt_fix() {
    log "apt-get --fix-broken install -y -o Dpkg::Options::=\"--force-confold\""
    logc _apt --fix-broken install -y -o Dpkg::Options::="--force-confold"
}

_lib_bash_apt_upgrade() {
    log "apt-get upgrade -y -o Dpkg::Options::=\"--force-confold\""
    logc _apt upgrade -y -o Dpkg::Options::="--force-confold"
}

_lib_bash_apt_dist_upgrade() {
    log "apt-get dist-upgrade -y -o Dpkg::Options::=\"--force-confold\""
    logc _apt dist-upgrade -y -o Dpkg::Options::="--force-confold"
}

_lib_bash_apt_cleanup() {
    log "apt-get autoclean -y"
    logc _apt autoclean -y
    log "apt-get autoremove --purge -y"
    logc _apt autoremove --purge -y
    # recreate temporary files which might get deleted after some update
    _systemd_tmpfiles --create > /dev/null 2>&1 || true
}

_lib_bash_force_phased_updates() {
    # Guard: if _apt cannot be resolved (127), avoid infinite loop
    if ! command -v _apt >/dev/null 2>&1; then
        log_warn "_apt not available; skipping phased updates"
        return 0
    fi
    # Attempt to force phased/kept-back updates by reinstalling packages individually
    while true; do
        # shellcheck disable=SC2016
        first_package_to_update=$(LANG=C _apt -s upgrade | awk '/deferred due to phasing:|have been kept back:/ {while(1){getline; if(/^[0-9]/) break; for(i=1;i<=NF;i++) print $i}}' | sort -u | head -n1)
        if [[ -z "$first_package_to_update" ]]; then
            break
        fi
        reinstall_packages "${first_package_to_update}"
    done
}

_lib_bash_restore_shell_state() {
    # Restore shell options and ERR trap captured by _lib_bash_save_shell_state
    if [[ -n "${LIB_BASH_SHELL_STATE}" ]]; then
        eval "${LIB_BASH_SHELL_STATE}"
    fi
    if [[ -n "${LIB_BASH_TRAP_STATE}" ]]; then
        eval "${LIB_BASH_TRAP_STATE}"
    fi
}

linux_update() {
    # pass "--force-phased-updates" as parameter if You want to do that
    local force_phased_updates="${1:-}"
    _exit_if_not_is_root
    _lib_bash_save_shell_state
    _lib_bash_apt_update
    _lib_bash_apt_fix
    _lib_bash_apt_upgrade
    _lib_bash_apt_dist_upgrade
    _lib_bash_apt_cleanup
    log "Force update of phased (kept back) updates"
    if [[ "${force_phased_updates}" == "--force-phased-updates" ]]; then
        _lib_bash_force_phased_updates
    fi
    _lib_bash_apt_cleanup
    _lib_bash_restore_shell_state
    log_ok "Update Finished"
}
