#!/bin/bash
# Dieses Skript dient als "Launcher" für lib_bash
echo "DEPRECATED - just import /usr/local/lib_bash/lib_bash.sh"

# Holen des absoluten Pfads des Skripts selbst (funktioniert bei Sourcing und Execution)
LIB_BASH_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
LIB_BASH_DIR="$(dirname "${LIB_BASH_SELF}")"
LIB_BASH_MAIN="${LIB_BASH_DIR}/lib_bash.sh"

# Unterschiedliches Verhalten je nach Kontext
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    # --- Falls gesourced wird ---
    # Lade lib_bash Bibliothek
    if [[ ! -f "${LIB_BASH_MAIN}" ]]; then
        echo "FEHLER: lib_bash nicht gefunden in ${LIB_BASH_DIR}" >&2
        return 1 2>/dev/null || exit 1
    fi
    source "${LIB_BASH_MAIN}"

else
    # --- Falls ausgeführt wird ---
    # Führe lib_bash mit allen Parametern in sauberem Kontext aus
    exec "${BASH}" --noprofile --norc -c \
        "source '${LIB_BASH_MAIN}' && LIB_BASH_MAIN \"\$@\"" \
        _ "$@"
fi
