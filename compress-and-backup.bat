@echo off
setlocal EnableDelayedExpansion

:: ============================================
:: Compress and Backup Script
:: Compresses a folder with 7z (store mode, encrypted)
:: Then syncs it to backup location via FreeFileSync
:: ============================================

:: Initialize error tracking
set "SCRIPT_ERROR=0"
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%config.txt"
set "SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe"
set "FFS_PATH=C:\Program Files\FreeFileSync\FreeFileSync.exe"
set "LOG_FILE=%SCRIPT_DIR%backup_%DATE:~-4%%DATE:~-10,2%%DATE:~-7,2%.log"

:: Initialize log file
echo ============================================ > "%LOG_FILE%" 2>nul
echo Backup started: %DATE% %TIME% >> "%LOG_FILE%" 2>nul
echo ============================================ >> "%LOG_FILE%" 2>nul

:: Check if script directory is writable
echo. > "%SCRIPT_DIR%write_test.tmp" 2>nul
if not exist "%SCRIPT_DIR%write_test.tmp" (
    echo [ERROR] Cannot write to script directory: %SCRIPT_DIR%
    echo [ERROR] Please check permissions or run as administrator.
    pause
    exit /b 1
)
del "%SCRIPT_DIR%write_test.tmp" 2>nul

:: Check if 7z exists
if not exist "%SEVENZIP_PATH%" (
    echo [ERROR] 7-Zip not found at: %SEVENZIP_PATH%
    echo [INFO] Please install 7-Zip from https://7-zip.org/
    call :LOG_ERROR "7-Zip not found at: %SEVENZIP_PATH%"
    pause
    exit /b 1
)

:: Verify 7-Zip is executable
"%SEVENZIP_PATH%" >nul 2>&1
if %ERRORLEVEL% GTR 1 (
    echo [ERROR] 7-Zip found but cannot execute. May be corrupted.
    call :LOG_ERROR "7-Zip cannot execute"
    pause
    exit /b 1
)

:: Check if config exists
if not exist "%CONFIG_FILE%" (
    echo [ERROR] Config file not found at: %CONFIG_FILE%
    echo [INFO] Run config-editor.bat to create a configuration.
    call :LOG_ERROR "Config file not found"
    pause
    exit /b 1
)

:: Check config file is readable
type "%CONFIG_FILE%" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Cannot read config file: %CONFIG_FILE%
    echo [INFO] The file may be locked or corrupted.
    call :LOG_ERROR "Cannot read config file"
    pause
    exit /b 1
)

:: Read configuration
echo [INFO] Reading configuration...
set "SOURCE_COUNT=0"
set "CONFIG_ERRORS=0"
for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
    set "line=%%a"
    :: Skip comments and empty lines
    if not "!line:~0,1!"=="#" (
        if not "%%a"=="" (
            :: Validate key name (should not contain special characters)
            set "KEY_CHECK=%%a"
            echo !KEY_CHECK! | findstr /r "[<>|&^!]" >nul 2>&1
            if !ERRORLEVEL! EQU 0 (
                echo [WARNING] Skipping config line with invalid characters: %%a
                set /a "CONFIG_ERRORS+=1"
            ) else (
                set "%%a=%%b"
                :: Count source entries (SOURCE_1, SOURCE_2, etc.)
                set "KEY_NAME=%%a"
                if "!KEY_NAME:~0,7!"=="SOURCE_" (
                    set /a "SOURCE_COUNT+=1"
                )
            )
        )
    )
)

if !CONFIG_ERRORS! GTR 0 (
    echo [WARNING] Skipped !CONFIG_ERRORS! malformed config lines.
)

:: Validate required settings
set "USE_PASSWORD=1"
if not defined PASSWORD (
    echo [ERROR] PASSWORD not set in config
    echo [INFO] Set PASSWORD=NONE for no password, or set a password.
    call :LOG_ERROR "PASSWORD not set in config"
    pause
    exit /b 1
)

:: Check if user wants no password
if /i "!PASSWORD!"=="NONE" (
    set "USE_PASSWORD=0"
    echo [INFO] No password protection - archive will be unencrypted.
    call :LOG_INFO "No password mode selected"
) else (
    :: Validate password is not the default placeholder
    if "!PASSWORD!"=="CHANGE-THIS-PASSWORD" (
        echo [ERROR] Please change the default password in config.txt
        echo [INFO] Run config-editor.bat to set a secure password.
        echo [INFO] Or set PASSWORD=NONE for no password protection.
        call :LOG_ERROR "Default password not changed"
        pause
        exit /b 1
    )

    :: Validate password length (minimum 8 characters recommended)
    set "PASS_LEN=0"
    set "TEMP_PASS=!PASSWORD!"
    :COUNT_PASS_LEN
    if defined TEMP_PASS (
        set "TEMP_PASS=!TEMP_PASS:~1!"
        set /a "PASS_LEN+=1"
        goto COUNT_PASS_LEN
    )
    if !PASS_LEN! LSS 8 (
        echo [WARNING] Password is less than 8 characters. Consider using a stronger password.
    )
)

if %SOURCE_COUNT% equ 0 (
    echo [ERROR] No source folders defined in config (use SOURCE_1=..., SOURCE_2=..., etc.)
    call :LOG_ERROR "No source folders defined"
    pause
    exit /b 1
)
if not defined COMPRESSION_LEVEL set "COMPRESSION_LEVEL=0"

:: Validate compression level is valid (0-9)
echo !COMPRESSION_LEVEL! | findstr /r "^[0-9]$" >nul
if !ERRORLEVEL! NEQ 0 (
    echo [WARNING] Invalid COMPRESSION_LEVEL: !COMPRESSION_LEVEL!. Using default (0).
    set "COMPRESSION_LEVEL=0"
)

if not defined ARCHIVE_OUTPUT_DIR (
    echo [ERROR] ARCHIVE_OUTPUT_DIR not set in config
    call :LOG_ERROR "ARCHIVE_OUTPUT_DIR not set"
    pause
    exit /b 1
)
if not defined BACKUP_DESTINATION (
    echo [ERROR] BACKUP_DESTINATION not set in config
    call :LOG_ERROR "BACKUP_DESTINATION not set"
    pause
    exit /b 1
)

:: Validate all source folders exist
echo [INFO] Found %SOURCE_COUNT% source(s) to backup
set "SOURCE_ERRORS=0"
for /L %%i in (1,1,%SOURCE_COUNT%) do (
    if not exist "!SOURCE_%%i!" (
        echo [ERROR] Source folder not found: !SOURCE_%%i!
        call :LOG_ERROR "Source not found: !SOURCE_%%i!"
        set /a "SOURCE_ERRORS+=1"
    ) else (
        echo        [%%i] !SOURCE_%%i!
        :: Check if source is accessible (not just exists)
        dir "!SOURCE_%%i!" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo [WARNING] Source exists but may not be accessible: !SOURCE_%%i!
        )
    )
)

if !SOURCE_ERRORS! GTR 0 (
    echo [ERROR] !SOURCE_ERRORS! source(s) not found. Please fix config.txt
    pause
    exit /b 1
)

:: Create output directory if it doesn't exist
if not exist "%ARCHIVE_OUTPUT_DIR%" (
    echo [INFO] Creating archive output directory...
    mkdir "%ARCHIVE_OUTPUT_DIR%" 2>nul
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to create output directory: %ARCHIVE_OUTPUT_DIR%
        echo [INFO] Check if you have write permissions.
        call :LOG_ERROR "Failed to create output directory"
        pause
        exit /b 1
    )
)

:: Check if output directory is writable
echo. > "%ARCHIVE_OUTPUT_DIR%\write_test.tmp" 2>nul
if not exist "%ARCHIVE_OUTPUT_DIR%\write_test.tmp" (
    echo [ERROR] Cannot write to archive output directory: %ARCHIVE_OUTPUT_DIR%
    echo [INFO] Please check permissions.
    call :LOG_ERROR "Output directory not writable"
    pause
    exit /b 1
)
del "%ARCHIVE_OUTPUT_DIR%\write_test.tmp" 2>nul

:: Check backup destination accessibility (if local path)
set "DEST_CHECK=%BACKUP_DESTINATION%"
if "!DEST_CHECK:~0,2!"=="\\" (
    echo [INFO] Backup destination is a network path: %BACKUP_DESTINATION%
    :: Try to access network path
    dir "%BACKUP_DESTINATION%" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo [WARNING] Network backup destination may not be accessible.
        echo [INFO] Sync may fail if the network location is unavailable.
    )
) else if "!DEST_CHECK:~1,1!"==":" (
    if not exist "%BACKUP_DESTINATION%" (
        echo [INFO] Creating backup destination directory...
        mkdir "%BACKUP_DESTINATION%" 2>nul
        if !ERRORLEVEL! NEQ 0 (
            echo [WARNING] Could not create backup destination: %BACKUP_DESTINATION%
        )
    )
)

:: Set archive name based on date/time for multi-source backup
:: Handle different date formats by extracting only digits
set "TODAY_DATE="
for /f "tokens=*" %%d in ('wmic os get LocalDateTime ^| findstr /r "[0-9]"') do (
    set "DATETIME=%%d"
    set "TODAY_DATE=!DATETIME:~0,8!"
)

:: Fallback if wmic fails
if not defined TODAY_DATE (
    set "ARCHIVE_NAME=backup_%DATE:~-4%%DATE:~-10,2%%DATE:~-7,2%"
    set "ARCHIVE_NAME=!ARCHIVE_NAME: =0!"
    echo [WARNING] Could not determine date format reliably. Using fallback.
) else (
    set "ARCHIVE_NAME=backup_!TODAY_DATE!"
)

:: Validate archive name doesn't contain invalid characters
echo !ARCHIVE_NAME! | findstr /r "[\\/:*?\"<>|]" >nul
if !ERRORLEVEL! EQU 0 (
    echo [WARNING] Archive name contains invalid characters. Using safe name.
    set "ARCHIVE_NAME=backup_!RANDOM!"
)

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
    del "%ARCHIVE_PATH%" 2>nul
    if exist "%ARCHIVE_PATH%" (
        echo [ERROR] Could not delete existing archive: %ARCHIVE_PATH%
        echo [INFO] The file may be in use or locked.
        call :LOG_ERROR "Could not delete existing archive"
        pause
        exit /b 1
    )
)

:: Estimate required disk space (rough check)
echo [INFO] Checking available disk space...
for %%D in ("%ARCHIVE_OUTPUT_DIR%") do set "DRIVE_LETTER=%%~dD"
for /f "tokens=2" %%a in ('wmic logicaldisk where "DeviceID='!DRIVE_LETTER!'" get FreeSpace /format:value 2^>nul ^| find "="') do set "FREE_SPACE=%%a"
if defined FREE_SPACE (
    :: Check if at least 1GB free (basic sanity check)
    set /a "FREE_GB=!FREE_SPACE:~0,-9!" 2>nul
    if !FREE_GB! LSS 1 (
        echo [WARNING] Low disk space on !DRIVE_LETTER! - less than 1GB free.
        echo [INFO] Compression may fail if there is not enough space.
    )
) else (
    echo [INFO] Could not determine free disk space. Proceeding anyway.
)

:: Build source list for 7z command
set "SOURCE_LIST="
for /L %%i in (1,1,%SOURCE_COUNT%) do (
    set "SOURCE_LIST=!SOURCE_LIST! "!SOURCE_%%i!""
)

echo [INFO] Starting compression...
call :LOG_INFO "Starting compression of !SOURCE_COUNT! source(s)"

:: Build 7z command based on password setting
if !USE_PASSWORD! EQU 1 (
    echo [INFO] Creating password-protected archive with encrypted headers...
    "%SEVENZIP_PATH%" a -t7z -mx%COMPRESSION_LEVEL% -mhe=on -p"%PASSWORD%" "%ARCHIVE_PATH%" !SOURCE_LIST!
) else (
    echo [INFO] Creating archive without password protection...
    "%SEVENZIP_PATH%" a -t7z -mx%COMPRESSION_LEVEL% "%ARCHIVE_PATH%" !SOURCE_LIST!
)
set "SEVENZIP_RESULT=!ERRORLEVEL!"

:: Interpret 7-Zip exit codes
if !SEVENZIP_RESULT! EQU 0 (
    echo.
    echo [SUCCESS] Compression complete: %ARCHIVE_PATH%
    call :LOG_INFO "Compression successful"
) else if !SEVENZIP_RESULT! EQU 1 (
    echo.
    echo [WARNING] 7-Zip completed with warnings (non-fatal errors)
    echo [INFO] Some files may have been skipped. Check the output above.
    call :LOG_WARNING "7-Zip completed with warnings"
) else if !SEVENZIP_RESULT! EQU 2 (
    echo.
    echo [ERROR] 7-Zip fatal error occurred!
    call :LOG_ERROR "7-Zip fatal error"
    pause
    exit /b 2
) else if !SEVENZIP_RESULT! EQU 7 (
    echo.
    echo [ERROR] 7-Zip command line error. Invalid parameters.
    call :LOG_ERROR "7-Zip command line error"
    pause
    exit /b 7
) else if !SEVENZIP_RESULT! EQU 8 (
    echo.
    echo [ERROR] 7-Zip: Not enough memory to complete operation.
    call :LOG_ERROR "7-Zip out of memory"
    pause
    exit /b 8
) else if !SEVENZIP_RESULT! EQU 255 (
    echo.
    echo [ERROR] 7-Zip: User cancelled the operation.
    call :LOG_ERROR "7-Zip cancelled by user"
    pause
    exit /b 255
) else (
    echo.
    echo [ERROR] 7-Zip compression failed with error code: !SEVENZIP_RESULT!
    call :LOG_ERROR "7-Zip failed with code !SEVENZIP_RESULT!"
    pause
    exit /b !SEVENZIP_RESULT!
)

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
) > "%FFS_BATCH%" 2>nul

:: Verify FFS batch file was created successfully
if not exist "%FFS_BATCH%" (
    echo [ERROR] Failed to create FreeFileSync batch file: %FFS_BATCH%
    echo [INFO] Check write permissions in script directory.
    call :LOG_ERROR "Failed to create FFS batch file"
    pause
    exit /b 1
)

:: Verify the batch file has content
for %%A in ("%FFS_BATCH%") do set "FFS_SIZE=%%~zA"
if !FFS_SIZE! LSS 100 (
    echo [ERROR] FreeFileSync batch file appears to be corrupted (too small).
    call :LOG_ERROR "FFS batch file corrupted"
    pause
    exit /b 1
)

echo [SUCCESS] FreeFileSync batch created: %FFS_BATCH%
call :LOG_INFO "FFS batch file created"
echo.

:: Verify archive exists before syncing
echo [DEBUG] Checking archive exists...
if exist "%ARCHIVE_PATH%" (
    echo [DEBUG] Archive found: %ARCHIVE_PATH%
    for %%A in ("%ARCHIVE_PATH%") do (
        set "ARCHIVE_SIZE=%%~zA"
        echo [DEBUG] Archive size: !ARCHIVE_SIZE! bytes
        
        :: Verify archive is not empty or corrupted (at least 100 bytes for valid 7z)
        if !ARCHIVE_SIZE! LSS 100 (
            echo [ERROR] Archive appears to be corrupted (too small: !ARCHIVE_SIZE! bytes)
            call :LOG_ERROR "Archive corrupted - too small"
            pause
            exit /b 1
        )
    )
    
    :: Verify archive integrity using 7-Zip test command
    echo [INFO] Verifying archive integrity...
    if !USE_PASSWORD! EQU 1 (
        "%SEVENZIP_PATH%" t "%ARCHIVE_PATH%" -p"%PASSWORD%" >nul 2>&1
    ) else (
        "%SEVENZIP_PATH%" t "%ARCHIVE_PATH%" >nul 2>&1
    )
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Archive integrity check failed!
        echo [INFO] The archive may be corrupted. Please try again.
        call :LOG_ERROR "Archive integrity check failed"
        pause
        exit /b 1
    )
    echo [DEBUG] Archive integrity verified.
) else (
    echo [ERROR] Archive NOT found at: %ARCHIVE_PATH%
    call :LOG_ERROR "Archive not found after compression"
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
    :: Check if FreeFileSync is a valid executable
    "%FFS_PATH%" --help >nul 2>&1
    
    echo [INFO] Starting FreeFileSync...
    call :LOG_INFO "Starting FreeFileSync sync"
    
    "%FFS_PATH%" "%FFS_BATCH%"
    set "FFS_RESULT=!ERRORLEVEL!"
    
    if !FFS_RESULT! EQU 0 (
        echo.
        echo [SUCCESS] Backup sync complete!
        call :LOG_INFO "Backup sync completed successfully"
    ) else if !FFS_RESULT! EQU 1 (
        echo.
        echo [WARNING] FreeFileSync completed with warnings.
        call :LOG_WARNING "FreeFileSync completed with warnings"
    ) else if !FFS_RESULT! EQU 2 (
        echo.
        echo [ERROR] FreeFileSync encountered an error during sync.
        call :LOG_ERROR "FreeFileSync sync error"
    ) else if !FFS_RESULT! EQU 3 (
        echo.
        echo [ERROR] FreeFileSync sync was aborted.
        call :LOG_ERROR "FreeFileSync sync aborted"
    ) else (
        echo.
        echo [WARNING] FreeFileSync returned code: !FFS_RESULT!
        call :LOG_WARNING "FreeFileSync returned code: !FFS_RESULT!"
    )
) else (
    echo [WARNING] FreeFileSync not found at: %FFS_PATH%
    echo [INFO] You can run the batch file manually: %FFS_BATCH%
    call :LOG_WARNING "FreeFileSync not found - manual sync required"
)

echo.
echo ============================================
echo   All operations completed!
echo ============================================
echo   Log file: %LOG_FILE%
echo ============================================
echo.

call :LOG_INFO "All operations completed"
pause
goto :EOF

:: ============================================
:: LOGGING FUNCTIONS
:: ============================================

:LOG_INFO
echo [%DATE% %TIME%] [INFO] %~1 >> "%LOG_FILE%" 2>nul
goto :EOF

:LOG_WARNING
echo [%DATE% %TIME%] [WARNING] %~1 >> "%LOG_FILE%" 2>nul
goto :EOF

:LOG_ERROR
echo [%DATE% %TIME%] [ERROR] %~1 >> "%LOG_FILE%" 2>nul
goto :EOF
