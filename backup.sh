#!/bin/sh

MAX_FILES=3
RCLONE_CONFIG="${HOME}/.config/rclone/rclone.conf"
TEMP_DIR="${TMPDIR:-/tmp}"

log_message() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] %s\n' "$timestamp" "$1"
}

log_error() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] Error: %s\n' "$timestamp" "$1" >&2
}

print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <src> <dest>

Backup directory using tar and rclone.

Options:
  --help                Show this help message
  --max-files=N         Maximum number of backup files to keep (default: 3, 0 for unlimited)
  --rclone-config=PATH  Specify rclone config file path

Arguments:
  src                   Source directory to backup
  dest                  Destination path (rclone remote)

Example:
  $(basename "$0") /path/to/backup remote:backup/
  $(basename "$0") --max-files=5 /path/to/backup remote:backup/
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            print_usage
            exit 0
            ;;
        --max-files=*)
            MAX_FILES="${1#*=}"
            ;;
        --rclone-config=*)
            RCLONE_CONFIG="${1#*=}"
            ;;
        -*)
            log_error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$SRC" ]; then
                SRC="$1"
            elif [ -z "$DEST" ]; then
                DEST="$1"
            else
                log_error "Too many arguments"
                exit 1
            fi
            ;;
    esac
    shift
done

# Check required parameters
if [ -z "$SRC" ] || [ -z "$DEST" ]; then
    log_error "Source and destination must be specified"
    print_usage
    exit 1
fi

# Check if source directory exists
if [ ! -d "$SRC" ]; then
    log_error "Source directory does not exist: $SRC"
    exit 1
fi
log_message "Using source directory: $SRC"

# Check if rclone config file exists
if [ ! -f "$RCLONE_CONFIG" ]; then
    log_error "rclone config file not found: $RCLONE_CONFIG"
    exit 1
fi
log_message "Using rclone config: $RCLONE_CONFIG"

# Create backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}.tar.gz"
TEMP_BACKUP="${TEMP_DIR}/${BACKUP_NAME}"

# Create backup archive
log_message "Creating backup archive..."
if ! tar -czf "$TEMP_BACKUP" -C "$(dirname "$SRC")" "$(basename "$SRC")"; then
    log_error "Failed to create backup archive"
    rm -f "$TEMP_BACKUP"
    exit 1
fi

# Upload backup file
# Important: `--s3-no-check-bucket` is required for cloudflare r2
log_message "Uploading backup to remote destination..."
if ! rclone --config "$RCLONE_CONFIG" copy "$TEMP_BACKUP" "$DEST" --s3-no-check-bucket; then
    log_error "Failed to upload backup"
    rm -f "$TEMP_BACKUP"
    exit 1
fi

# Clean up temporary file
rm -f "$TEMP_BACKUP"

# Check and remove old backups if max files limit is set
if [ "$MAX_FILES" -gt 0 ]; then
    log_message "Checking backup count..."
    # Get remote file list and sort by name
    BACKUP_LIST=$(rclone --config "$RCLONE_CONFIG" lsf "$DEST" | grep '\.tar\.gz$' | sort)
    BACKUP_COUNT=$(echo "$BACKUP_LIST" | wc -l)
    
    if [ "$BACKUP_COUNT" -gt "$MAX_FILES" ]; then
        # Calculate number of files to delete
        DELETE_COUNT=$((BACKUP_COUNT - MAX_FILES))
        # Get list of files to delete
        FILES_TO_DELETE=$(echo "$BACKUP_LIST" | head -n "$DELETE_COUNT")
        
        log_message "Removing old backups..."
        echo "$FILES_TO_DELETE" | while read -r file; do
            if [ -n "$file" ]; then
                log_message "Deleting: $file"
                rclone --config "$RCLONE_CONFIG" delete "$DEST/$file"
            fi
        done
    fi
fi

log_message "Backup completed successfully"
