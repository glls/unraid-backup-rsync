#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
DEST_DISK="/mnt/disks/ZXA122Z3"
DEST_ROOT="$DEST_DISK/Backup-rsync"
DATE_STAMP=$(date +%Y-%m-%d)
TIME_STAMP=$(date +%H-%M)
KEEP_DAYS=90

# This creates a log folder and a file named by the date
LOG_DIR="$DEST_ROOT/logs"
LOG_FILE="$LOG_DIR/backup_$DATE_STAMP.log"

SOURCES=(
    "/mnt/user/photos"
    "/mnt/user/calibre/Libraries"
    "/mnt/user/projects/comics"
    "/mnt/user/projects/oom"
    "/mnt/user/music"
)

# Create necessary directories
mkdir -p "$LOG_DIR"

# ==============================================================================
# PHASE 1: SAFETY CHECK
# ==============================================================================
if ! mountpoint -q "$DEST_DISK"; then
    /usr/local/emhttp/webGui/scripts/notify -e "Backup Critical" \
    -s "Barracuda Backup Failed" \
    -d "Disk $DEST_DISK is not mounted! Check Unassigned Devices." \
    -i "alert"
    exit 1
fi

ERRORS=0

# START LOGGING BLOCK
{
echo "=========================================================="
echo "BACKUP START TIME: $DATE_STAMP @ $TIME_STAMP"
echo "=========================================================="

# ==============================================================================
# PHASE 2: EXECUTION (RSYNC)
# ==============================================================================
for SRC in "${SOURCES[@]}"; do
    FOLDER_NAME=$(basename "$SRC")
    CURRENT_DEST="$DEST_ROOT/current/$FOLDER_NAME"
    ARCHIVE_DEST="$DEST_ROOT/archive/$DATE_STAMP-$TIME_STAMP/$FOLDER_NAME"

    echo "--- Processing: $FOLDER_NAME ---"
    mkdir -p "$CURRENT_DEST"

    # rsync with --stats for a summary in the log
    rsync -avh --delete --stats \
      --backup --backup-dir="$ARCHIVE_DEST" \
      "$SRC/" "$CURRENT_DEST/"

    if [ $? -ne 0 ]; then
        echo "ERROR: rsync failed for $FOLDER_NAME"
        ERRORS=$((ERRORS + 1))
    fi

    echo "" # Add a newline for readability
done

# ==============================================================================
# PHASE 3: HOUSEKEEPING (CLEANUP)
# ==============================================================================
echo "--- Housekeeping ---"
echo "Cleaning up archives older than $KEEP_DAYS days..."
CUTOFF_DATE=$(date -d "-${KEEP_DAYS} days" +%Y-%m-%d)
if [ -d "$DEST_ROOT/archive/" ]; then
    for DIR in "$DEST_ROOT/archive/"*/; do
        [ -d "$DIR" ] || continue
        DIR_DATE=$(basename "$DIR" | grep -oP '^\d{4}-\d{2}-\d{2}')
        if [ -n "$DIR_DATE" ] && [[ "$DIR_DATE" < "$CUTOFF_DATE" ]]; then
            echo "Removing old archive: $(basename "$DIR")"
            rm -rf "$DIR"
        fi
    done
fi

# Also clean up old logs so they don't pile up forever
echo "Cleaning up logs older than $KEEP_DAYS days..."
for LOG in "$LOG_DIR"/backup_*.log; do
    [ -f "$LOG" ] || continue
    LOG_DATE=$(basename "$LOG" | grep -oP '\d{4}-\d{2}-\d{2}')
    if [ -n "$LOG_DATE" ] && [[ "$LOG_DATE" < "$CUTOFF_DATE" ]]; then
        echo "Removing old log: $(basename "$LOG")"
        rm -f "$LOG"
    fi
done

echo "=========================================================="
echo "BACKUP FINISHED: $(date)"
echo "=========================================================="

} >> "$LOG_FILE" 2>&1

# ==============================================================================
# PHASE 4: NOTIFICATION
# ==============================================================================
if [ $ERRORS -gt 0 ]; then
    /usr/local/emhttp/webGui/scripts/notify -e "Backup Warning" \
    -s "Barracuda Backup Completed with $ERRORS error(s)" \
    -d "Check log: $LOG_FILE" \
    -i "warning"
else
    /usr/local/emhttp/webGui/scripts/notify -e "Backup Complete" \
    -s "Barracuda Backup Successful" \
    -d "Log: $LOG_FILE" \
    -i "normal"
fi
