# copy_folders_from_csv.sh

A small bash script that copies a list of folders from one directory into
another. The list of folder names to copy comes from a CSV file, so you can
reuse the same script for different batches of folders without editing any
code.

## What it does

- Reads a CSV file containing folder names (one per row).
- For each name, copies `<source>/<name>` to `<destination>/<name>`.
- Uses `rsync` under the hood, so it's safe to run more than once — it will
  skip anything already copied and unchanged, and can pick back up if
  interrupted partway through.
- Only ever **copies**. It never deletes or modifies anything in the source
  folder.

## Requirements

- `bash`
- `rsync`

Both are already installed on most Linux systems, including Unraid.

## Usage

```bash
./copy_folders_from_csv.sh <copy_list.csv> --src <path> --dst <path> [--dry-run]
```

| Argument           | Required? | Description                                             |
|--------------------|-----------|-----------------------------------------------------------|
| `<copy_list.csv>`  | Yes       | Path to the CSV file listing the folders to copy         |
| `--src <path>`     | Yes       | Folder that contains the source folders                  |
| `--dst <path>`     | Yes       | Folder to copy the folders into                           |
| `--dry-run`        | No        | Preview only — shows what would happen, copies nothing    |

Arguments can be given in any order. There are no hardcoded paths in the
script — if you forget `--src` or `--dst`, it will print usage instructions
and exit without doing anything.

### Example

```bash
# Always preview first
./copy_folders_from_csv.sh copy_list.csv --dry-run \
    --src "/path/to/source" \
    --dst "/path/to/destination"

# Then run for real
./copy_folders_from_csv.sh copy_list.csv \
    --src "/path/to/source" \
    --dst "/path/to/destination"
```

## CSV format

- The first line is treated as a header and skipped.
- The first column is the folder name — it must match the folder name under
  `--src` exactly.
- Any other columns are ignored.
- If a folder name contains a comma, wrap it in double quotes.

```csv
Name
Folder One
Folder Two
"Folder, With A Comma"
```

## Output

While running, the script prints progress for each folder:

```
[1/3] Copying: Folder One
[2/3] Copying: Folder Two
[3/3] MISSING SOURCE, skipping: Folder Three
```

At the end it prints a summary:

```
=== Summary ===
Total folders: 3
Missing src:   1
Failed copies: 0
```

Everything printed is also appended to `copy_folders_from_csv.log`, saved in
the same directory as the script, so you have a persistent record even if
you close your terminal.

## Running it in the background

If you're connecting over SSH and want the copy to keep running after you
disconnect, use `nohup`:

```bash
nohup ./copy_folders_from_csv.sh copy_list.csv --src "/path/to/source" --dst "/path/to/destination" &
```

Check progress anytime with:

```bash
tail -f copy_folders_from_csv.log
```

Check if it's still running with:

```bash
ps aux | grep copy_folders_from_csv
```

To stop it, find its process ID from the command above and run:

```bash
kill <PID>
```

## Safety notes

- Always run with `--dry-run` first to confirm the source/destination paths
  and folder list are correct before copying anything for real.
- The script refuses to run if `--src` or `--dst` don't exist as folders —
  double check the path if you see that error.
- Re-running the script is safe — `rsync` will skip folders/files that
  already match at the destination.
