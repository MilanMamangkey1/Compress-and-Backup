# Compress and Backup

Compresses folders/files using 7-Zip with password protection and encrypted headers, then optionally syncs to another location using a user-provided FreeFileSync batch file.

## Files

| File | Purpose |
|------|---------|
| `compress-and-backup.bat` | Main script (supports multiple jobs) |
| `run-hidden.vbs` | Run backup silently (hidden terminal window) |
| `config-editor.bat` | Interactive configuration editor |
| `config.txt` | Default job configuration |
| `config-*.txt` | Additional job configurations (e.g., `config-Work.txt`) |
| `active-job.txt` | Stores the default job name (auto-generated) |
| `sync-*.ffs_batch` | User-provided FreeFileSync batch files (you create these) |
## Quick Start

1. Run `config-editor.bat` to configure your settings, or edit `config.txt` directly
2. Run `compress-and-backup.bat`

## Multiple Jobs

You can create multiple backup jobs, each with its own sources, destinations, and settings.

### Creating Jobs

1. Run `config-editor.bat`
2. Go to **[8] Switch/Create Job**
3. Press **[N]** to create a new job
4. Enter a name (e.g., `Work`, `Personal`, `Projects`)

This creates `config-Work.txt`, `config-Personal.txt`, etc.

### Running Jobs

**Interactive mode** (shows menu if multiple jobs exist):
```batch
compress-and-backup.bat
```

**Run specific job by name**:
```batch
compress-and-backup.bat Work
compress-and-backup.bat Personal
compress-and-backup.bat default
```

**List available jobs**:
```batch
compress-and-backup.bat --list
```

### Setting a Default Job

To skip the selection menu and always run a specific job:

1. Run `config-editor.bat`
2. Go to **[8] Switch/Create Job**
3. Press **[D]** to set default
4. Select the job to use as default

The default job runs automatically when `compress-and-backup.bat` is executed without arguments.

## Silent / Background Running

To run backups without a visible terminal window, use `run-hidden.vbs`:

```batch
:: Double-click or run directly
run-hidden.vbs

:: Run specific job
wscript run-hidden.vbs "Work"
```

FreeFileSync will also minimize to the notification area (system tray) instead of showing a progress window.

### Task Scheduler Setup (Fully Silent)

For completely silent scheduled backups:

1. Open **Task Scheduler** → Create Task
2. **General tab**: Name it, check "Run whether user is logged on or not"
3. **Triggers tab**: Set your schedule (daily, weekly, etc.)
4. **Actions tab**:
   - Program: `wscript.exe`
   - Arguments: `"E:\path\to\run-hidden.vbs" "JobName"`
   - Start in: `E:\path\to\` (script directory)
5. **Settings tab**: Uncheck "Stop if running longer than"

This runs completely in the background with no windows.

### Scheduling Multiple Jobs

Use Windows Task Scheduler to run different jobs at different times:

```batch
:: Daily personal backup at 6 PM
wscript run-hidden.vbs "Personal"

:: Weekly work backup on Fridays
wscript run-hidden.vbs "Work"
```

## Configuration Options

| Setting | Description |
|---------|-------------|
| `PASSWORD` | Password for the 7z archive (set to `NONE` for no password) |
| `COMPRESSION_LEVEL` | 0=Store, 1=Fastest, 3=Fast, 5=Normal, 7=Maximum, 9=Ultra |
| `SOURCE_1`, `SOURCE_2`, ... | Folders/files to compress (add as many as needed) |
| `ARCHIVE_OUTPUT_DIR` | Where to save the .7z file |
| `FFS_BATCH_FILE` | Path to your FreeFileSync batch file (leave empty to skip sync) |

## Example Config

```ini
PASSWORD=MySecretPassword123
COMPRESSION_LEVEL=0
SOURCE_1=C:\Users\John\Documents
SOURCE_2=C:\Users\John\Pictures\Important
SOURCE_3=D:\Projects\ClientWork
ARCHIVE_OUTPUT_DIR=C:\Backups
FFS_BATCH_FILE=sync-backup.ffs_batch
```

To create an archive without password protection:
```ini
PASSWORD=NONE
```

To skip the sync step entirely:
```ini
FFS_BATCH_FILE=
```

This would:
- Compress all 3 sources into a single archive at `C:\Backups\backup_20260102.7z`
- Sync using the FreeFileSync batch file `sync-backup.ffs_batch` (if configured)

> **Note:** With a single source, the archive is named after the folder (e.g., `Documents.7z`). With multiple sources, it uses a date-based name.

## Config Editor Features

Run `config-editor.bat` for an interactive menu:

- View current configuration with path validation
- Edit settings (password, compression, paths)
- Manage source folders/files
- Generate secure passwords (passphrase or random)
- Test all paths before running
- Dry-run preview
- **Multiple job configurations**
- **Set default job for automated runs**
- Automatic config backup

## What the Script Does

1. **Compresses** all source folders/files into a single `.7z` archive:
   - Configurable compression level (store to ultra)
   - Password protects the archive
   - Encrypts file names (`-mhe=on`) for extra security

2. **Verifies** archive integrity using 7-Zip test command

3. **Syncs** using your FreeFileSync batch file (if configured):
   - If `FFS_BATCH_FILE` is set and the file exists, runs the sync
   - If not configured or file not found, skips sync with a warning

## Creating a FreeFileSync Batch File

Since the script uses your own `.ffs_batch` file, you need to create one in FreeFileSync:

1. Open **FreeFileSync**
2. Set up your sync:
   - **Left side**: Your archive output directory (e.g., `C:\Backups`)
   - **Right side**: Your backup destination (e.g., `G:\CloudSync\Backups` or cloud path)
3. Configure sync options (Update, Mirror, etc.)
4. Go to **File → Save as Batch Job**
5. Save as `sync-backup.ffs_batch` (or any name) in the script directory
6. Set `FFS_BATCH_FILE=sync-backup.ffs_batch` in your config

### Tips for Batch Files

- Use **Update** mode to only copy changed files
- Enable **Minimized to tray** for silent operation
- Set **Auto-close** if you want no user interaction

## Use Cases

- **Scheduled backups** — Run via Task Scheduler for automatic daily/weekly encrypted backups
- **Cloud sync preparation** — Compress sensitive files before syncing to Dropbox, Google Drive, or OneDrive
- **External drive backups** — Keep an encrypted archive copy on a USB or external HDD
- **Project archiving** — Bundle multiple project folders into a single password-protected archive
- **Sensitive document storage** — Encrypt personal documents, tax records, or financial files with hidden filenames

## Requirements

- [7-Zip](https://7-zip.org/) installed at `C:\Program Files\7-Zip\7z.exe`
- [FreeFileSync](https://freefilesync.org/) installed at `C:\Program Files\FreeFileSync\FreeFileSync.exe`

## Cloud Storage Setup

If your backup destination is a cloud service (Google Drive, SFTP, etc.), you must authenticate it in FreeFileSync first:

1. Open **FreeFileSync** (not this script)
2. Click the **cloud icon** next to the folder path field
3. Select your cloud provider and sign in
4. Once authenticated, use the cloud path as the **Right side** when creating your `.ffs_batch` file

> **Note:** FreeFileSync stores cloud credentials securely. You only need to authenticate once per cloud account.

## Security Note

⚠️ The `config.txt` file contains your password in plain text. Keep this file secure and don't share it.
