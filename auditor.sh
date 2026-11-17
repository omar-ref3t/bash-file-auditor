#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib.sh"
LOG_FILE="$SCRIPT_DIR/auditor.log"

# List every item under the audited directory and count files and folders.
scan_directory() {
    local directory=$1
    local item
    local files=0
    local folders=0

    require_dir "$directory" || return 1
    while IFS= read -r -d '' item; do
        if [[ -d "$item" ]]; then
            printf '[dir ] %s\n' "${item#"$directory"/}"
            ((folders += 1))
        elif [[ -f "$item" ]]; then
            printf '[file] %s\n' "${item#"$directory"/}"
            ((files += 1))
        else
            printf '[other] %s\n' "${item#"$directory"/}"
        fi
    done < <(find "$directory" -mindepth 1 -maxdepth 1 -print0 | sort -z)

    printf 'Files: %d Folders: %d\n' "$files" "$folders"
    log_action "Scanned directory $directory"
}

# Report the current user's read, write, and execute access for every file.
permission_audit() {
    local directory=$1
    local item
    local flags
    local unreadable=0
    local executable=0

    require_dir "$directory" || return 1
    while IFS= read -r -d '' item; do
        [[ -f "$item" ]] || continue
        flags='---'
        [[ -r "$item" ]] && flags="r${flags:1}"
        [[ -w "$item" ]] && flags="${flags:0:1}w${flags:2}"
        [[ -x "$item" ]] && flags="${flags:0:2}x"
        printf '%s %s\n' "$flags" "${item#"$directory"/}"
        [[ -r "$item" ]] || ((unreadable += 1))
        if [[ -x "$item" ]]; then
            ((executable += 1))
        fi
    done < <(find "$directory" -maxdepth 1 -type f -print0 | sort -z)

    printf 'Unreadable files: %d Executable files: %d\n' "$unreadable" "$executable"
    log_action "Audited permissions in $directory"
}

# Count files by extension using a Bash associative array.
extension_report() {
    local directory=$1
    local item
    local name
    local extension
    declare -A counts=()

    require_dir "$directory" || return 1
    while IFS= read -r -d '' item; do
        name=${item##*/}
        if [[ "$name" == *.* && "$name" != .* ]]; then
            extension=${name##*.}
        else
            extension=other
        fi
        case "$extension" in
            txt|log|sh|jpg) ;;
            *) extension=other ;;
        esac
        ((counts["$extension"] += 1))
    done < <(find "$directory" -maxdepth 1 -type f -print0 | sort -z)

    for extension in jpg log other sh txt; do
        printf '%s : %d\n' "$extension" "${counts[$extension]:-0}"
    done
    log_action "Reported file extensions in $directory"
}

# Search file names recursively for text entered by the user.
search_file() {
    local directory=$1
    local query
    local item
    local found=0

    require_dir "$directory" || return 1
    read -r -p 'Enter text to search for in file names: ' query
    if [[ -z "$query" ]]; then
        log_error 'Search text cannot be empty.'
        log_action "Searched file names in $directory"
        return 1
    fi
    while IFS= read -r -d '' item; do
        if [[ "${item##*/}" == *"$query"* ]]; then
            printf '%s\n' "${item#"$directory"/}"
            found=1
        fi
    done < <(find "$directory" -maxdepth 1 -type f -print0 | sort -z)
    if ((found == 0)); then
        printf 'No files found containing: %s\n' "$query"
    fi
    log_action "Searched file names in $directory for $query"
}

# Back up each readable file into a timestamped .bak file without replacing a backup.
backup_all() {
    local directory=$1
    local backup_dir="$directory/backups"
    local item
    local base
    local stamp
    local destination
    local suffix
    local saved=0
    local skipped=0

    require_dir "$directory" || return 1
    if ! mkdir -p -- "$backup_dir"; then
        log_error "Could not create backup folder: $backup_dir"
        log_action "Backup attempted for $directory"
        return 1
    fi
    while IFS= read -r -d '' item; do
        [[ "$item" == "$backup_dir"/* ]] && continue
        if [[ ! -r "$item" ]]; then
            log_error "Skipping unreadable file: $item"
            ((skipped += 1))
            continue
        fi
        base=${item##*/}
        stamp=$(date '+%Y%m%d_%H%M%S')
        destination="$backup_dir/${base}_${stamp}.bak"
        suffix=1
        while [[ -e "$destination" ]]; do
            destination="$backup_dir/${base}_${stamp}_${suffix}.bak"
            ((suffix += 1))
        done
        if cp -- "$item" "$destination"; then
            ((saved += 1))
        else
            log_error "Could not back up file: $item"
            ((skipped += 1))
        fi
    done < <(find "$directory" -maxdepth 1 -type f -print0 | sort -z)

    printf 'Files saved: %d Files skipped: %d\n' "$saved" "$skipped"
    log_action "Backed up files in $directory (saved: $saved, skipped: $skipped)"
}

# Show saved backups, or explain that none exist yet.
list_backups() {
    local directory=$1
    local backup_dir="$directory/backups"
    local backup
    local found=0

    require_dir "$directory" || return 1
    if [[ -d "$backup_dir" ]]; then
        while IFS= read -r -d '' backup; do
            printf '%s\n' "${backup##*/}"
            found=1
        done < <(find "$backup_dir" -maxdepth 1 -type f -name '*.bak' -print0 | sort -z)
    fi
    if ((found == 0)); then
        printf '(no backups yet)\n'
    fi
    log_action "Listed backups in $directory"
}

# Restore one chosen backup with a restored_ prefix while preserving originals.
restore_backup() {
    local directory=$1
    local backup_dir="$directory/backups"
    local chosen=${2:-}
    local source_file
    local original_name
    local destination

    require_dir "$directory" || return 1
    if [[ -z "$chosen" ]]; then
        read -r -p 'Enter a backup file name: ' chosen
    fi
    if [[ "$chosen" == */* || "$chosen" == '.' || "$chosen" == '..' ]]; then
        log_error 'Enter only a backup file name from the backups folder.'
        log_action "Restore attempted in $directory"
        return 1
    fi
    source_file="$backup_dir/$chosen"
    if [[ ! -f "$source_file" || "$chosen" != *.bak ]]; then
        log_error "Backup does not exist: $chosen"
        log_action "Restore attempted in $directory for $chosen"
        return 1
    fi
    original_name=${chosen%.bak}
    if [[ "$original_name" =~ ^(.*)_[0-9]{8}_[0-9]{6}(_[0-9]+)?$ ]]; then
        original_name=${BASH_REMATCH[1]}
    fi
    destination="$directory/restored_$original_name"
    if [[ -e "$destination" ]]; then
        log_error "Restore would overwrite an existing file: $destination"
        log_action "Restore attempted in $directory for $chosen"
        return 1
    fi
    if ! cp -- "$source_file" "$destination"; then
        log_error "Could not restore backup: $chosen"
        log_action "Restore attempted in $directory for $chosen"
        return 1
    fi
    printf 'Restored as %s\n' "${destination##*/}"
    log_action "Restored $chosen in $directory"
}

# Display the menu repeatedly until the user chooses Exit.
show_menu() {
    local directory=$1
    local choice

    while true; do
        printf '\nFile Auditor & Backup Tool\n'
        printf '1) Scan directory\n2) Permission audit\n3) Extension report\n4) Search file\n'
        printf '5) Back up all files\n6) List backups\n7) Restore backup\n8) Exit\n'
        read -r -p 'Choose an option: ' choice
        if [[ "$choice" == 1 ]]; then
            scan_directory "$directory"
        elif [[ "$choice" == 2 ]]; then
            permission_audit "$directory"
        elif [[ "$choice" == 3 ]]; then
            extension_report "$directory"
        elif [[ "$choice" == 4 ]]; then
            search_file "$directory"
        elif [[ "$choice" == 5 ]]; then
            backup_all "$directory"
        elif [[ "$choice" == 6 ]]; then
            list_backups "$directory"
        elif [[ "$choice" == 7 ]]; then
            restore_backup "$directory"
        elif [[ "$choice" == 8 ]]; then
            break
        else
            log_error 'Invalid choice. Please select 1 through 8.'
        fi
    done
}

# Validate arguments and dispatch the requested command or interactive menu.
main() {
    local directory=${1:-.}
    local action=${2:-}

    require_dir "$directory" || return 1
    if [[ -z "$action" ]]; then
        show_menu "$directory"
    elif [[ "$action" == scan ]]; then
        scan_directory "$directory"
    elif [[ "$action" == perms ]]; then
        permission_audit "$directory"
    elif [[ "$action" == ext ]]; then
        extension_report "$directory"
    elif [[ "$action" == backup ]]; then
        backup_all "$directory"
    else
        log_error "Unknown action: $action"
        log_info 'Use one of: scan, perms, ext, backup; omit the action for the menu.'
        return 2
    fi
}

main "$@"
