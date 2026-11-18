#!/usr/bin/env bash

# El functions el moshtaraka elli auditor.sh beyesta5demha.

# Betetba3 message 3adeya.
log_info() {
    local message=${1:-}
    printf 'INFO: %s\n' "$message"
}

# Betetba3 error message 3ala stderr.
log_error() {
    local message=${1:-}
    printf 'ERROR: %s\n' "$message" >&2
}

# Betzawed satr fel log feeh el wa2t w el action.
log_action() {
    local action=${1:-unknown action}
    local log_file=${LOG_FILE:-auditor.log}

    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$action" >> "$log_file" || {
        log_error "Could not write to log file: $log_file"
        return 1
    }
}

# Betet2aked en el path mawgood w folder.
require_dir() {
    local directory=${1:-}

    if [[ -z "$directory" || ! -d "$directory" ]]; then
        log_error "Directory does not exist: ${directory:-<not provided>}"
        return 1
    fi

    return 0
}
