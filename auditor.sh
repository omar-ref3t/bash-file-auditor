#!/usr/bin/env bash

# El option da bey5alli el glob yeshof el files el hidden w yet3ada el folder el fady.
shopt -s dotglob nullglob

# Ben7added makan el project 3ashan ne3raf ne7amel lib.sh w nekteb el log gamb el files.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
LOG_FILE="$SCRIPT_DIR/auditor.log"

# El function di bet3ared el files wel folders w bet7seb 3adadhom.
scan_directory() {
    local directory=$1
    local item
    local files=0
    local folders=0

    require_dir "$directory" || return 1

    for item in "$directory"/*; do
        if [[ -d "$item" ]]; then
            printf '[dir ] %s\n' "${item#"$directory"/}"
            ((folders += 1))
        elif [[ -f "$item" ]]; then
            printf '[file] %s\n' "${item#"$directory"/}"
            ((files += 1))
        else
            printf '[other] %s\n' "${item#"$directory"/}"
        fi
    done

    printf 'Files: %d Folders: %d\n' "$files" "$folders"
    log_action "Scanned directory $directory"
}

# El function di bet3ared read/write/execute le kol file, w bet7seb el mesh ma2ro2 wel executable.
permission_audit() {
    local directory=$1
    local item
    local read_flag
    local write_flag
    local exec_flag
    local unreadable=0
    local executable=0

    require_dir "$directory" || return 1

    for item in "$directory"/*; do
        [[ -f "$item" ]] || continue

        read_flag='-'
        write_flag='-'
        exec_flag='-'

        [[ -r "$item" ]] && read_flag='r'
        [[ -w "$item" ]] && write_flag='w'
        [[ -x "$item" ]] && exec_flag='x'

        printf '%s%s%s %s\n' "$read_flag" "$write_flag" "$exec_flag" "${item#"$directory"/}"

        if [[ ! -r "$item" ]]; then
            ((unreadable += 1))
        fi
        if [[ -x "$item" ]]; then
            ((executable += 1))
        fi
    done

    printf 'Unreadable files: %d Executable files: %d\n' "$unreadable" "$executable"
    log_action "Audited permissions in $directory"
}

# El function di bet3od el files 7asab el extension: txt/log/sh/jpg, wel ba2y other.
extension_report() {
    local directory=$1
    local item
    local name
    local extension
    local txt=0
    local log=0
    local sh=0
    local jpg=0
    local other=0

    require_dir "$directory" || return 1

    for item in "$directory"/*; do
        [[ -f "$item" ]] || continue
        name="${item##*/}"

        if [[ "$name" == *.* ]]; then
            extension="${name##*.}"
        else
            extension='other'
        fi

        case "$extension" in
            txt) ((txt += 1)) ;;
            log) ((log += 1)) ;;
            sh) ((sh += 1)) ;;
            jpg) ((jpg += 1)) ;;
            *) ((other += 1)) ;;
        esac
    done

    printf 'jpg : %d\n' "$jpg"
    printf 'log : %d\n' "$log"
    printf 'other : %d\n' "$other"
    printf 'sh : %d\n' "$sh"
    printf 'txt : %d\n' "$txt"
    log_action "Reported file extensions in $directory"
}

# El function di betdawar 3ala kelma gowwa asamy el files.
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

    for item in "$directory"/*; do
        [[ -f "$item" ]] || continue
        if [[ "${item##*/}" == *"$query"* ]]; then
            printf '%s\n' "${item#"$directory"/}"
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        printf 'No files found containing: %s\n' "$query"
    fi
    log_action "Searched file names in $directory for $query"
}

# El function di betnse5 kol file ma2ro2 gowwa backups be esm feeh wa2t el copy.
backup_all() {
    local directory=$1
    local backup_dir="$directory/backups"
    local item
    local name
    local stamp
    local destination
    local suffix
    local saved=0
    local skipped=0

    require_dir "$directory" || return 1

    if ! mkdir -p "$backup_dir"; then
        log_error "Could not create backup folder: $backup_dir"
        log_action "Backup attempted for $directory"
        return 1
    fi

    for item in "$directory"/*; do
        [[ -f "$item" ]] || continue

        if [[ ! -r "$item" ]]; then
            log_error "Skipping unreadable file: $item"
            ((skipped += 1))
            continue
        fi

        name="${item##*/}"
        stamp="$(date '+%Y%m%d_%H%M%S')"
        destination="$backup_dir/${stamp}-${name}.bak"
        suffix=1

        while [[ -e "$destination" ]]; do
            destination="$backup_dir/${stamp}_${suffix}-${name}.bak"
            ((suffix += 1))
        done

        if cp "$item" "$destination"; then
            ((saved += 1))
        else
            log_error "Could not back up file: $item"
            ((skipped += 1))
        fi
    done

    printf 'Files saved: %d Files skipped: %d\n' "$saved" "$skipped"
    log_action "Backed up files in $directory (saved: $saved, skipped: $skipped)"
}

# El function di bet3ared kol backup et3emel abl keda.
list_backups() {
    local directory=$1
    local backup_dir="$directory/backups"
    local backup
    local found=0

    require_dir "$directory" || return 1

    if [[ -d "$backup_dir" ]]; then
        for backup in "$backup_dir"/*.bak; do
            [[ -f "$backup" ]] || continue
            printf '%s\n' "${backup##*/}"
            found=1
        done
    fi

    if [[ $found -eq 0 ]]; then
        printf '(no backups yet)\n'
    fi
    log_action "Listed backups in $directory"
}

# El function di beteraga3 backup be esm yabda2 b restored_ 3ashan matktebsh fo2 el original.
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

    original_name="${chosen#*-}"
    original_name="${original_name%.bak}"
    destination="$directory/restored_$original_name"
    if [[ -e "$destination" ]]; then
        log_error "Restore would overwrite an existing file: $destination"
        log_action "Restore attempted in $directory for $chosen"
        return 1
    fi

    if ! cp "$source_file" "$destination"; then
        log_error "Could not restore backup: $chosen"
        log_action "Restore attempted in $directory for $chosen"
        return 1
    fi

    printf 'Restored as %s\n' "${destination##*/}"
    log_action "Restored $chosen in $directory"
}

# El menu beyefdal shaghal le7ad ma te5tar 8 3ashan te5rog.
show_menu() {
    local directory=$1
    local choice

    while true; do
        printf '\nFile Auditor & Backup Tool\n'
        printf '1) Scan directory\n2) Permission audit\n3) Extension report\n4) Search file\n'
        printf '5) Back up all files\n6) List backups\n7) Restore backup\n8) Exit\n'
        read -r -p 'Choose an option: ' choice

        case "$choice" in
            1) scan_directory "$directory" ;;
            2) permission_audit "$directory" ;;
            3) extension_report "$directory" ;;
            4) search_file "$directory" ;;
            5) backup_all "$directory" ;;
            6) list_backups "$directory" ;;
            7) restore_backup "$directory" ;;
            8) break ;;
            *) log_error 'Invalid choice. Please select 1 through 8.' ;;
        esac
    done
}

# El function di betshof el action el matloob w betsaghal el function el monasba.
main() {
    local directory=${1:-.}
    local action=${2:-}

    require_dir "$directory" || return 1

    case "$action" in
        '') show_menu "$directory" ;;
        scan) scan_directory "$directory" ;;
        perms) permission_audit "$directory" ;;
        ext) extension_report "$directory" ;;
        backup) backup_all "$directory" ;;
        *)
            log_error "Unknown action: $action"
            log_info 'Use: scan, perms, ext, backup; or leave action empty for the menu.'
            return 2
            ;;
    esac
}

# "$@" beyeb3at kol arguments zay ma el user katabhom.
main "$@"
