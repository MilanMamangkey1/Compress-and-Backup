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
set "SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe"
set "FFS_PATH=C:\Program Files\FreeFileSync\FreeFileSync.exe"
set "ACTIVE_JOB_FILE=%SCRIPT_DIR%active-job.txt"

:: ============================================
:: JOB SELECTION
:: ============================================
:: Check for command-line job argument
set "JOB_NAME="
set "CONFIG_FILE="

if not "%~1"=="" (
    set "JOB_NAME=%~1"
    :: Check for special --list flag
    if /i "!JOB_NAME!"=="--list" goto :LIST_JOBS_EXIT
    if /i "!JOB_NAME!"=="-l" goto :LIST_JOBS_EXIT
    :: Try exact config file first (config-JobName.txt)
    if exist "%SCRIPT_DIR%config-!JOB_NAME!.txt" (
        set "CONFIG_FILE=%SCRIPT_DIR%config-!JOB_NAME!.txt"
    ) else if exist "%SCRIPT_DIR%config.txt" if /i "!JOB_NAME!"=="default" (
        set "CONFIG_FILE=%SCRIPT_DIR%config.txt"
        set "JOB_NAME=default"
    ) else (
        echo [ERROR] Job not found: !JOB_NAME!
        echo [INFO] Available jobs:
        call :LIST_JOBS
        pause
        exit /b 1
    )
    goto :JOB_SELECTED
)

:: No argument - check for active job file
if exist "!ACTIVE_JOB_FILE!" (
    for /f "usebackq delims=" %%J in ("!ACTIVE_JOB_FILE!") do set "JOB_NAME=%%J"
    if defined JOB_NAME (
        if /i "!JOB_NAME!"=="default" (
            if exist "%SCRIPT_DIR%config.txt" (
                set "CONFIG_FILE=%SCRIPT_DIR%config.txt"
                goto :JOB_SELECTED
            )
        ) else if exist "%SCRIPT_DIR%config-!JOB_NAME!.txt" (
            set "CONFIG_FILE=%SCRIPT_DIR%config-!JOB_NAME!.txt"
            goto :JOB_SELECTED
        )
    )
)

:: Count available jobs
set "JOB_COUNT=0"
for %%F in ("%SCRIPT_DIR%config*.txt") do (
    set "FNAME=%%~nxF"
    :: Skip backup files
    echo !FNAME! | findstr /i "\.bak\>" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo !FNAME! | findstr /i "backup" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            set /a "JOB_COUNT+=1"
        )
    )
)

:: If only one job exists, use it automatically
if !JOB_COUNT! EQU 1 (
    for %%F in ("%SCRIPT_DIR%config*.txt") do (
        set "FNAME=%%~nxF"
        echo !FNAME! | findstr /i "\.bak\>" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo !FNAME! | findstr /i "backup" >nul 2>&1
            if !ERRORLEVEL! NEQ 0 (
                set "CONFIG_FILE=%%F"
                if "!FNAME!"=="config.txt" (
                    set "JOB_NAME=default"
                ) else (
                    set "JOB_NAME=!FNAME:config-=!"
                    set "JOB_NAME=!JOB_NAME:.txt=!"
                )
            )
        )
    )
    goto :JOB_SELECTED
)

:: Multiple jobs - show selection menu
if !JOB_COUNT! GTR 1 (
    goto :JOB_MENU
)

:: No jobs found
echo [ERROR] No configuration files found!
echo [INFO] Run config-editor.bat to create a job configuration.
pause
exit /b 1

:JOB_MENU
cls
echo.
echo ============================================
echo   SELECT BACKUP JOB
echo ============================================
echo.
set "JOB_IDX=0"
for %%F in ("%SCRIPT_DIR%config*.txt") do (
    set "FNAME=%%~nxF"
    :: Skip backup files
    echo !FNAME! | findstr /i "\.bak\>" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo !FNAME! | findstr /i "backup" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            set /a "JOB_IDX+=1"
            set "JOB_FILE_!JOB_IDX!=%%F"
            if "!FNAME!"=="config.txt" (
                set "JOB_DISPLAY_!JOB_IDX!=default"
                echo   [!JOB_IDX!] default ^(config.txt^)
            ) else (
                set "DISPLAY_NAME=!FNAME:config-=!"
                set "DISPLAY_NAME=!DISPLAY_NAME:.txt=!"
                set "JOB_DISPLAY_!JOB_IDX!=!DISPLAY_NAME!"
                echo   [!JOB_IDX!] !DISPLAY_NAME!
            )
        )
    )
)
echo.
echo   [0] Exit
echo.
echo ============================================
set /p "JOB_CHOICE=  Select job (1-%JOB_IDX%): "

if "!JOB_CHOICE!"=="0" exit /b 0
if "!JOB_CHOICE!"=="" goto :JOB_MENU

:: Validate choice
set /a "CHECK_CHOICE=!JOB_CHOICE!" 2>nul
if !CHECK_CHOICE! GEQ 1 if !CHECK_CHOICE! LEQ !JOB_IDX! (
    set "CONFIG_FILE=!JOB_FILE_%JOB_CHOICE%!"
    set "JOB_NAME=!JOB_DISPLAY_%JOB_CHOICE%!"
    goto :JOB_SELECTED
)

echo [ERROR] Invalid choice. Please try again.
timeout /t 2 >nul
goto :JOB_MENU

:LIST_JOBS
set "LIST_IDX=0"
for %%F in ("%SCRIPT_DIR%config*.txt") do (
    set "FNAME=%%~nxF"
    echo !FNAME! | findstr /i "\.bak\>" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo !FNAME! | findstr /i "backup" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            set /a "LIST_IDX+=1"
            if "!FNAME!"=="config.txt" (
                echo        - default
            ) else (
                set "DISPLAY_NAME=!FNAME:config-=!"
                set "DISPLAY_NAME=!DISPLAY_NAME:.txt=!"
                echo        - !DISPLAY_NAME!
            )
        )
    )
)
goto :EOF

:LIST_JOBS_EXIT
echo.
echo Available backup jobs:
call :LIST_JOBS
echo.
exit /b 0

:JOB_SELECTED
echo.
echo [INFO] Running job: !JOB_NAME!
echo [INFO] Config file: !CONFIG_FILE!
echo.

:: Set log file with job name
set "LOG_FILE=%SCRIPT_DIR%backup_!JOB_NAME!_%DATE:~-4%%DATE:~-10,2%%DATE:~-7,2%.log"

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
    pause
    exit /b 1
)

:: Check if config exists
if not exist "%CONFIG_FILE%" (
    echo [ERROR] Config file not found at: %CONFIG_FILE%
    echo [INFO] Run config-editor.bat to create a configuration.
    pause
    exit /b 1
)

:: Read configuration
echo [INFO] Reading configuration...
set "SOURCE_COUNT=0"
for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
    set "line=%%a"
    :: Skip comments and empty lines
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
set "USE_PASSWORD=1"
if not defined PASSWORD (
    echo [ERROR] PASSWORD not set in config
    echo [INFO] Set PASSWORD=NONE for no password, or set a password.
    pause
    exit /b 1
)

:: Check if user wants no password
if /i "!PASSWORD!"=="NONE" (
    set "USE_PASSWORD=0"
    echo [INFO] No password protection - archive will be unencrypted.
    goto :PASSWORD_CHECK_DONE
)

:: Validate password is not the default placeholder
if "!PASSWORD!"=="CHANGE-THIS-PASSWORD" (
    echo [ERROR] Please change the default password in config.txt
    echo [INFO] Run config-editor.bat to set a secure password.
    echo [INFO] Or set PASSWORD=NONE for no password protection.
    pause
    exit /b 1
)

:PASSWORD_CHECK_DONE

if %SOURCE_COUNT% equ 0 (
    echo [ERROR] No source folders defined in config ^(use SOURCE_1=..., SOURCE_2=..., etc.^)
    pause
    exit /b 1
)
if not defined COMPRESSION_LEVEL set "COMPRESSION_LEVEL=0"

if not defined ARCHIVE_OUTPUT_DIR (
    echo [ERROR] ARCHIVE_OUTPUT_DIR not set in config
    pause
    exit /b 1
)

:: Validate all source folders exist
echo [INFO] Found %SOURCE_COUNT% source(s) to backup
set "SOURCE_ERRORS=0"
for /L %%i in (1,1,%SOURCE_COUNT%) do (
    if not exist "!SOURCE_%%i!" (
        echo [ERROR] Source folder not found: !SOURCE_%%i!
        set /a "SOURCE_ERRORS+=1"
    ) else (
        echo        [%%i] !SOURCE_%%i!
    )
)

if !SOURCE_ERRORS! GTR 0 (
    echo [ERROR] !SOURCE_ERRORS! source^(s^) not found. Please fix config.txt
    pause
    exit /b 1
)

:: Create output directory if it doesn't exist
if not exist "%ARCHIVE_OUTPUT_DIR%" (
    echo [INFO] Creating archive output directory...
    mkdir "%ARCHIVE_OUTPUT_DIR%" 2>nul
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
if defined FFS_BATCH_FILE (
    echo   Sync Batch File:   %FFS_BATCH_FILE%
) else (
    echo   Sync Batch File:   [Not configured]
)
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
    goto :SEVENZIP_DONE
)
if !SEVENZIP_RESULT! EQU 1 (
    echo.
    echo [WARNING] 7-Zip completed with warnings ^(non-fatal errors^)
    echo [INFO] Some files may have been skipped. Check the output above.
    goto :SEVENZIP_DONE
)
if !SEVENZIP_RESULT! EQU 2 (
    echo.
    echo [ERROR] 7-Zip fatal error occurred!
    pause
    exit /b 2
)
if !SEVENZIP_RESULT! EQU 7 (
    echo.
    echo [ERROR] 7-Zip command line error. Invalid parameters.
    pause
    exit /b 7
)
if !SEVENZIP_RESULT! EQU 8 (
    echo.
    echo [ERROR] 7-Zip: Not enough memory to complete operation.
    pause
    exit /b 8
)
if !SEVENZIP_RESULT! EQU 255 (
    echo.
    echo [ERROR] 7-Zip: User cancelled the operation.
    pause
    exit /b 255
)
:: Unknown error
echo.
echo [ERROR] 7-Zip compression failed with error code: !SEVENZIP_RESULT!
pause
exit /b !SEVENZIP_RESULT!

:SEVENZIP_DONE
echo.

:: ============================================
:: FFS BATCH FILE RESOLUTION
:: ============================================
:: Resolve FFS_BATCH_FILE path (support relative paths from script directory)
set "FFS_BATCH="
if defined FFS_BATCH_FILE (
    :: Check if it's an absolute path (second char is colon like C:\)
    set "PATH_CHECK=!FFS_BATCH_FILE!"
    if "!PATH_CHECK:~1,1!"==":" (
        set "FFS_BATCH=!FFS_BATCH_FILE!"
    ) else (
        :: Relative path - resolve from script directory
        set "FFS_BATCH=%SCRIPT_DIR%!FFS_BATCH_FILE!"
    )
)

:: ============================================
:: STEP 2: VERIFY ARCHIVE AND RUN FREFILESYNC
:: ============================================
:: Verify archive exists before syncing
if not exist "%ARCHIVE_PATH%" (
    echo [ERROR] Archive NOT found at: %ARCHIVE_PATH%
    pause
    exit /b 1
)

:: Verify archive integrity using 7-Zip test command
echo [STEP 2] Verifying archive integrity...
set "TEST_RESULT=0"
if !USE_PASSWORD! EQU 1 (
    "%SEVENZIP_PATH%" t "%ARCHIVE_PATH%" -p"%PASSWORD%" >nul 2>&1
    set "TEST_RESULT=!ERRORLEVEL!"
) else (
    "%SEVENZIP_PATH%" t "%ARCHIVE_PATH%" >nul 2>&1
    set "TEST_RESULT=!ERRORLEVEL!"
)
if !TEST_RESULT! NEQ 0 (
    echo [ERROR] Archive integrity check failed ^(code: !TEST_RESULT!^)
    pause
    exit /b 1
)
echo [SUCCESS] Archive integrity verified.
echo.

:: Step 3: Run FreeFileSync sync (if configured)
if not defined FFS_BATCH (
    echo [STEP 3] FreeFileSync sync skipped.
    echo [WARNING] No FFS_BATCH_FILE configured in config.
    echo [INFO] To enable sync, set FFS_BATCH_FILE in your config to point to a .ffs_batch file.
    goto :FFS_DONE
)

if not exist "!FFS_BATCH!" (
    echo [STEP 3] FreeFileSync sync skipped.
    echo [WARNING] FFS batch file not found: !FFS_BATCH!
    echo [INFO] Create a .ffs_batch file in FreeFileSync and set FFS_BATCH_FILE in config.
    goto :FFS_DONE
)

echo [STEP 3] Running FreeFileSync backup...
echo [INFO] Using batch file: !FFS_BATCH!

if not exist "%FFS_PATH%" (
    echo [WARNING] FreeFileSync not found at: %FFS_PATH%
    echo [INFO] You can run the batch file manually: !FFS_BATCH!
    goto :FFS_DONE
)

echo [INFO] Starting FreeFileSync...
"%FFS_PATH%" "!FFS_BATCH!"
set "FFS_RESULT=!ERRORLEVEL!"

if !FFS_RESULT! EQU 0 (
    echo.
    echo [SUCCESS] Backup sync complete!
)
if !FFS_RESULT! EQU 1 (
    echo.
    echo [WARNING] FreeFileSync completed with warnings.
)
if !FFS_RESULT! GEQ 2 (
    echo.
    echo [WARNING] FreeFileSync returned code: !FFS_RESULT!
)

:FFS_DONE

echo.
echo ============================================
echo   All operations completed!
echo ============================================
echo   Log file: %LOG_FILE%
echo ============================================
echo.

call :LOG_INFO "All operations completed"
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

:CHECK_PASS_LENGTH
set "PASS_LEN=0"
set "TEMP_PASS=!PASSWORD!"
:COUNT_PASS_LOOP
if defined TEMP_PASS (
    set "TEMP_PASS=!TEMP_PASS:~1!"
    set /a "PASS_LEN+=1"
    goto :COUNT_PASS_LOOP
)
goto :EOF
