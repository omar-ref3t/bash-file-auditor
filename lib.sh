#!/usr/bin/env bash

# Print an informational message for the person running the auditor.
log_info() {
    local message=${1:-}
    printf 'INFO: %s\n' "$message"
}

# Print an error message to standard error.
log_error() {
    local message=${1:-}
    printf 'ERROR: %s\n' "$message" >&2
}

# Append one timestamped record describing a completed or attempted feature.
log_action() {
    local action=${1:-unknown action}
    local log_file=${LOG_FILE:-auditor.log}
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$action" >> "$log_file" || {
        log_error "Could not write to log file: $log_file"
        return 1
    }
}

# Confirm that the requested directory exists before any audit begins.
require_dir() {
    local directory=${1:-}
    if [[ -z "$directory" || ! -d "$directory" ]]; then
        log_error "Directory does not exist: ${directory:-<not provided>}"
        return 1
    fi
    return 0
}
