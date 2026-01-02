@echo off
setlocal EnableDelayedExpansion

:: ============================================
:: Compress and Backup Script
:: Compresses a folder with 7z (store mode, encrypted)
:: Then syncs it to backup location via FreeFileSync
:: ============================================

set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%config.txt"
set "SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe"
set "FFS_PATH=C:\Program Files\FreeFileSync\FreeFileSync.exe"

:: Check if 7z exists
if not exist "%SEVENZIP_PATH%" (
    echo [ERROR] 7-Zip not found at: %SEVENZIP_PATH%
    pause
    exit /b 1
)

:: Check if config exists
if not exist "%CONFIG_FILE%" (
    echo [ERROR] Config file not found at: %CONFIG_FILE%
    pause
    exit /b 1
)

:: Read configuration
echo [INFO] Reading configuration...
set "SOURCE_COUNT=0"
for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
    set "line=%%a"
    if not "!line:~0,1!"=="#" (
        if not "%%a"=="" (
            set "%%a=%%b"
            :: Count source entries (SOURCE_1, SOURCE_2, etc.)
            set "KEY_NAME=%%a"
            if "!KEY_NAME:~0,7!"=="SOURCE_" (
                set /a "SOURCE_COUNT+=1"
            )
        )
    )
)

:: Validate required settings
if not defined PASSWORD (
    echo [ERROR] PASSWORD not set in config
    pause
    exit /b 1
)
if %SOURCE_COUNT% equ 0 (
    echo [ERROR] No source folders defined in config (use SOURCE_1=..., SOURCE_2=..., etc.)
    pause
    exit /b 1
)
if not defined COMPRESSION_LEVEL set "COMPRESSION_LEVEL=0"
if not defined ARCHIVE_OUTPUT_DIR (
    echo [ERROR] ARCHIVE_OUTPUT_DIR not set in config
    pause
    exit /b 1
)
if not defined BACKUP_DESTINATION (
    echo [ERROR] BACKUP_DESTINATION not set in config
    pause
    exit /b 1
)

:: Validate all source folders exist
echo [INFO] Found %SOURCE_COUNT% source(s) to backup
for /L %%i in (1,1,%SOURCE_COUNT%) do (
    if not exist "!SOURCE_%%i!" (
        echo [ERROR] Source folder not found: !SOURCE_%%i!
        pause
        exit /b 1
    )
    echo        [%%i] !SOURCE_%%i!
)

:: Create output directory if it doesn't exist
if not exist "%ARCHIVE_OUTPUT_DIR%" (
    echo [INFO] Creating archive output directory...
    mkdir "%ARCHIVE_OUTPUT_DIR%"
)

:: Set archive name based on date/time for multi-source backup
set "ARCHIVE_NAME=backup_%DATE:~-4%%DATE:~-10,2%%DATE:~-7,2%"
set "ARCHIVE_NAME=!ARCHIVE_NAME: =0!"

:: If single source, use folder name instead
if %SOURCE_COUNT% equ 1 (
    for %%F in ("!SOURCE_1!") do set "ARCHIVE_NAME=%%~nxF"
)

:: Set archive path
set "ARCHIVE_PATH=%ARCHIVE_OUTPUT_DIR%\%ARCHIVE_NAME%.7z"

echo.
echo ============================================
echo   Compress and Backup Script
echo ============================================
echo.
echo   Sources:           %SOURCE_COUNT% item(s)
for /L %%i in (1,1,%SOURCE_COUNT%) do (
    echo                      [%%i] !SOURCE_%%i!
)
echo   Archive Output:    %ARCHIVE_PATH%
echo   Backup Destination:%BACKUP_DESTINATION%
echo.
echo ============================================
echo.

:: Step 1: Compress with 7z (store mode, password protected, encrypted headers)
echo [STEP 1] Compressing %SOURCE_COUNT% source(s) with 7-Zip (store mode)...
echo.

:: Delete existing archive if it exists (to ensure fresh compression)
if exist "%ARCHIVE_PATH%" (
    echo [INFO] Removing existing archive...
    del "%ARCHIVE_PATH%"
)

:: Build source list for 7z command
set "SOURCE_LIST="
for /L %%i in (1,1,%SOURCE_COUNT%) do (
    set "SOURCE_LIST=!SOURCE_LIST! "!SOURCE_%%i!""
)

"%SEVENZIP_PATH%" a -t7z -mx%COMPRESSION_LEVEL% -mhe=on -p"%PASSWORD%" "%ARCHIVE_PATH%" !SOURCE_LIST!

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] 7-Zip compression failed with error code: %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Compression complete: %ARCHIVE_PATH%
echo.

:: Generate FFS batch file path
set "FFS_BATCH=%SCRIPT_DIR%sync-%ARCHIVE_NAME%.ffs_batch"

:: Step 2: Generate FreeFileSync batch file
echo [STEP 2] Generating FreeFileSync batch file...

:: Create FFS batch XML (format matches FreeFileSync v13+)
(
echo ^<?xml version="1.0" encoding="utf-8"?^>
echo ^<FreeFileSync XmlType="BATCH" XmlFormat="23"^>
echo     ^<Notes/^>
echo     ^<Compare^>
echo         ^<Variant^>TimeAndSize^</Variant^>
echo         ^<Symlinks^>Follow^</Symlinks^>
echo         ^<IgnoreTimeShift/^>
echo     ^</Compare^>
echo     ^<Synchronize^>
echo         ^<Changes^>
echo             ^<Left Create="right" Update="right" Delete="none"/^>
echo             ^<Right Create="none" Update="none" Delete="none"/^>
echo         ^</Changes^>
echo         ^<DeletionPolicy^>RecycleBin^</DeletionPolicy^>
echo         ^<VersioningFolder Style="Replace"/^>
echo     ^</Synchronize^>
echo     ^<Filter^>
echo         ^<Include^>
echo             ^<Item^>\%ARCHIVE_NAME%.7z^</Item^>
echo         ^</Include^>
echo         ^<Exclude^>
echo             ^<Item^>\System Volume Information\^</Item^>
echo             ^<Item^>\$Recycle.Bin\^</Item^>
echo             ^<Item^>*\thumbs.db^</Item^>
echo         ^</Exclude^>
echo         ^<SizeMin Unit="None"^>0^</SizeMin^>
echo         ^<SizeMax Unit="None"^>0^</SizeMax^>
echo         ^<TimeSpan Type="None"^>0^</TimeSpan^>
echo     ^</Filter^>
echo     ^<FolderPairs^>
echo         ^<Pair^>
echo             ^<Left^>%ARCHIVE_OUTPUT_DIR%^</Left^>
echo             ^<Right^>%BACKUP_DESTINATION%^</Right^>
echo         ^</Pair^>
echo     ^</FolderPairs^>
echo     ^<Errors Ignore="false" Retry="1" Delay="5"/^>
echo     ^<PostSyncCommand Condition="Completion"/^>
echo     ^<LogFolder/^>
echo     ^<EmailNotification Condition="Always"/^>
echo     ^<GridViewType^>Action^</GridViewType^>
echo     ^<Batch^>
echo         ^<ProgressDialog Minimized="false" AutoClose="true"/^>
echo         ^<ErrorDialog^>Show^</ErrorDialog^>
echo         ^<PostSyncAction^>None^</PostSyncAction^>
echo     ^</Batch^>
echo ^</FreeFileSync^>
) > "%FFS_BATCH%"

echo [SUCCESS] FreeFileSync batch created: %FFS_BATCH%
echo.

:: Verify archive exists before syncing
echo [DEBUG] Checking archive exists...
if exist "%ARCHIVE_PATH%" (
    echo [DEBUG] Archive found: %ARCHIVE_PATH%
    for %%A in ("%ARCHIVE_PATH%") do echo [DEBUG] Archive size: %%~zA bytes
) else (
    echo [ERROR] Archive NOT found at: %ARCHIVE_PATH%
    pause
    exit /b 1
)
echo.

:: Step 3: Run FreeFileSync sync
echo [STEP 3] Running FreeFileSync backup...
echo [DEBUG] FFS Batch: %FFS_BATCH%
echo [DEBUG] Syncing: %ARCHIVE_OUTPUT_DIR% --^> %BACKUP_DESTINATION%
echo.

if exist "%FFS_PATH%" (
    "%FFS_PATH%" "%FFS_BATCH%"
    
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo [WARNING] FreeFileSync returned code: %ERRORLEVEL%
    ) else (
        echo.
        echo [SUCCESS] Backup sync complete!
    )
) else (
    echo [WARNING] FreeFileSync not found at: %FFS_PATH%
    echo [INFO] You can run the batch file manually: %FFS_BATCH%
)

echo.
echo ============================================
echo   All operations completed!
echo ============================================
echo.
pause
