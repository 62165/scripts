#!/bin/bash
#
# copy_folders_from_csv.sh
#
# Copies a list of folders from a source directory to a destination
# directory. The list of folder names comes from a CSV file.
#
# CSV FORMAT:
#   First line is a header (skipped).
#   First column is the folder name, matching the folder name exactly.
#   For consistency, quote every entry in the CSV. Names containing a comma
#   should also be wrapped in double quotes, e.g.:
#     Name
#     "Folder One"
#     "Folder Two"
#     "Folder, With Comma"
#
# ============================================================================
# HOW TO USE THIS (read this if you're not the original author)
# ============================================================================
# There are NO hardcoded folder paths in this script — --src and --dst are
# both REQUIRED every time you run it. Nothing runs without them.
#
# 1. Build a CSV of the folder names you want copied (see CSV FORMAT above).
#    These must match the exact folder names under your --src path.
#
# 2. ALWAYS do a --dry-run first. It touches nothing — it only shows you
#    what WOULD be copied, so you can confirm the paths and folder list are
#    right before anything actually moves.
#
# 3. Once the dry run looks right, run it for real (same command, drop
#    --dry-run).
#
# EXAMPLE:
#   ./copy_folders_from_csv.sh list.csv --dry-run \
#       --src "/path/to/source" \
#       --dst "/path/to/destination"
#
#   ./copy_folders_from_csv.sh list.csv \
#       --src "/path/to/source" \
#       --dst "/path/to/destination"
#
#   (the csv path, --dry-run, --src, and --dst can be given in any order)
# ============================================================================
#
# Uses rsync so it's safe to re-run (skips files already copied/unchanged)
# and can be resumed if interrupted. It only ever COPIES — it never deletes
# anything from the source folder.
#
# A log of everything done is written to copy_folders_from_csv.log in the
# same directory as this script.

set -uo pipefail

SRC_ROOT=""
DST_ROOT=""
LOG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/copy_folders_from_csv.log"

DRY_RUN=false
CSV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --src)
            SRC_ROOT="$2"
            shift 2
            ;;
        --dst)
            DST_ROOT="$2"
            shift 2
            ;;
        *)
            CSV_FILE="$1"
            shift
            ;;
    esac
done

if [[ -z "$CSV_FILE" || -z "$SRC_ROOT" || -z "$DST_ROOT" ]]; then
    echo "Usage: $0 <list.csv> --src <path> --dst <path> [--dry-run]"
    echo ""
    echo "  <list.csv>    CSV of folder names to copy (see script header)"
    echo "  --src <path>  REQUIRED. Folder containing the source folders"
    echo "  --dst <path>  REQUIRED. Folder to copy the folders into"
    echo "  --dry-run     Optional. Preview only, copies nothing"
    exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
    echo "ERROR: CSV file not found: $CSV_FILE"
    exit 1
fi

echo "Source:      $SRC_ROOT"
echo "Destination: $DST_ROOT"
echo "CSV file:    $CSV_FILE"
echo ""

if [[ ! -d "$SRC_ROOT" ]]; then
    echo "ERROR: source root not found: $SRC_ROOT" | tee -a "$LOG_FILE"
    echo "       Double-check the path passed with --src." | tee -a "$LOG_FILE"
    exit 1
fi
if [[ ! -d "$DST_ROOT" ]]; then
    echo "ERROR: destination root not found: $DST_ROOT" | tee -a "$LOG_FILE"
    echo "       Double-check the path passed with --dst." | tee -a "$LOG_FILE"
    exit 1
fi

# Read the CSV into an array, skipping the header row, and handling a
# quoted first field (so names containing commas work correctly).
# Pure-bash parsing (no awk/gawk dependency, since some systems only have
# mawk which doesn't support the FPAT feature this would otherwise need).
ITEMS=()
first_line=true
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"   # strip trailing CR if the CSV is Windows-saved
    if $first_line; then
        first_line=false
        continue
    fi
    [[ -z "$line" ]] && continue
    if [[ "$line" == \"* ]]; then
        item="${line#\"}"
        item="${item%%\"*}"
    else
        item="${line%%,*}"
    fi
    ITEMS+=("$item")
done < "$CSV_FILE"

if [[ ${#ITEMS[@]} -eq 0 ]]; then
    echo "ERROR: no entries parsed from $CSV_FILE — check the file format."
    exit 1
fi

echo "=== copy_folders_from_csv.sh run started: $(date) ===" | tee -a "$LOG_FILE"
echo "CSV file: $CSV_FILE (${#ITEMS[@]} folders)" | tee -a "$LOG_FILE"

if $DRY_RUN; then
    echo "*** DRY RUN — no files will be copied ***" | tee -a "$LOG_FILE"
fi

total=${#ITEMS[@]}
count=0
missing=0
failed=0

for item in "${ITEMS[@]}"; do
    count=$((count + 1))
    src="${SRC_ROOT}/${item}"
    dst="${DST_ROOT}/${item}"

    if [[ ! -d "$src" ]]; then
        echo "[$count/$total] MISSING SOURCE, skipping: $item" | tee -a "$LOG_FILE"
        missing=$((missing + 1))
        continue
    fi

    echo "[$count/$total] Copying: $item" | tee -a "$LOG_FILE"

    if $DRY_RUN; then
        rsync -avh --dry-run --stats "$src/" "$dst/" | tee -a "$LOG_FILE"
    else
        mkdir -p "$dst"
        if rsync -avh --stats "$src/" "$dst/" | tee -a "$LOG_FILE"; then
            :
        else
            echo "  !! FAILED copying: $item" | tee -a "$LOG_FILE"
            failed=$((failed + 1))
        fi
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "=== Summary ===" | tee -a "$LOG_FILE"
echo "Total folders: $total" | tee -a "$LOG_FILE"
echo "Missing src:   $missing" | tee -a "$LOG_FILE"
echo "Failed copies: $failed" | tee -a "$LOG_FILE"
echo "=== copy_folders_from_csv.sh run finished: $(date) ===" | tee -a "$LOG_FILE"