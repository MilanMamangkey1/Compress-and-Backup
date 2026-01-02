# Compress and Backup Script

Compresses a folder using 7-Zip in **store mode** (no compression, fast) with password protection, then backs it up to another location using FreeFileSync.

## Files

| File | Purpose |
|------|---------|
| `compress-and-backup.bat` | Main script |
| `config.txt` | Configuration (paths, password) |
| `sync-*.ffs_batch` | Auto-generated FreeFileSync batch (created on first run) |

## Setup

1. Edit `config.txt` with your settings:
   - `PASSWORD` - Password for the 7z archive
   - `SOURCE_FOLDER` - Folder you want to compress
   - `ARCHIVE_OUTPUT_DIR` - Where to save the .7z file
   - `BACKUP_DESTINATION` - Where FreeFileSync copies the archive

2. Run `compress-and-backup.bat`

## What It Does

1. **Compresses** the source folder into a `.7z` archive:
   - Uses store mode (`-mx0`) for speed
   - Password protects the archive
   - Encrypts file names (`-mhe=on`) for extra security

2. **Creates** a FreeFileSync batch file (if not exists)

3. **Syncs** the archive to the backup destination using FreeFileSync (Update mode)

## Example Config

```ini
PASSWORD=MySecretPassword123
SOURCE_FOLDER=C:\Users\John\Documents\ImportantFiles
ARCHIVE_OUTPUT_DIR=C:\Users\John\Archives
BACKUP_DESTINATION=G:\CloudSync\Backups
```

This would:
- Create `C:\Users\John\Archives\ImportantFiles.7z`
- Sync it to `G:\CloudSync\Backups\ImportantFiles.7z`

## Requirements

- 7-Zip installed at `C:\Program Files\7-Zip\7z.exe`
- FreeFileSync installed at `C:\Program Files\FreeFileSync\FreeFileSync.exe`

## Security Note

⚠️ The `config.txt` file contains your password in plain text. Keep this file secure and don't share it.
