# Compress and Backup

Compresses folders/files using 7-Zip with password protection and encrypted headers, then backs up to another location using FreeFileSync.

## Files

| File | Purpose |
|------|---------|
| `compress-and-backup.bat` | Main script (no user interaction, can be scheduled) |
| `config-editor.bat` | Interactive configuration editor |
| `config.txt` | Configuration (paths, password, settings) |
| `sync-*.ffs_batch` | Auto-generated FreeFileSync batch (created on run) |

## Quick Start

1. Run `config-editor.bat` to configure your settings, or edit `config.txt` directly
2. Run `compress-and-backup.bat`

## Configuration Options

| Setting | Description |
|---------|-------------|
| `PASSWORD` | Password for the 7z archive |
| `COMPRESSION_LEVEL` | 0=Store, 1=Fastest, 3=Fast, 5=Normal, 7=Maximum, 9=Ultra |
| `SOURCE_1`, `SOURCE_2`, ... | Folders/files to compress (add as many as needed) |
| `ARCHIVE_OUTPUT_DIR` | Where to save the .7z file |
| `BACKUP_DESTINATION` | Where FreeFileSync copies the archive |

## Example Config

```ini
PASSWORD=MySecretPassword123
COMPRESSION_LEVEL=0
SOURCE_1=C:\Users\John\Documents
SOURCE_2=C:\Users\John\Pictures\Important
SOURCE_3=D:\Projects\ClientWork
ARCHIVE_OUTPUT_DIR=C:\Backups
BACKUP_DESTINATION=G:\CloudSync\Backups
```

This would:
- Compress all 3 sources into a single archive at `C:\Backups\backup_20260102.7z`
- Sync it to `G:\CloudSync\Backups\`

> **Note:** With a single source, the archive is named after the folder (e.g., `Documents.7z`). With multiple sources, it uses a date-based name.

## Config Editor Features

Run `config-editor.bat` for an interactive menu:

- View current configuration with path validation
- Edit settings (password, compression, paths)
- Generate secure passwords (passphrase or random)
- Test all paths before running
- Dry-run preview
- Multiple config profiles
- Automatic config backup

## What the Script Does

1. **Compresses** all source folders/files into a single `.7z` archive:
   - Configurable compression level (store to ultra)
   - Password protects the archive
   - Encrypts file names (`-mhe=on`) for extra security

2. **Generates** a FreeFileSync batch file

3. **Syncs** the archive to the backup destination (Update mode - only copies if changed)

## Requirements

- [7-Zip](https://7-zip.org/) installed at `C:\Program Files\7-Zip\7z.exe`
- [FreeFileSync](https://freefilesync.org/) installed at `C:\Program Files\FreeFileSync\FreeFileSync.exe`

## Security Note

⚠️ The `config.txt` file contains your password in plain text. Keep this file secure and don't share it.
