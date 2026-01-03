@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: Config Editor for Compress-and-Backup
:: ============================================================================
:: A full-featured configuration manager with validation, profiles, and more.
:: ============================================================================

title Config Editor - Compress and Backup

:: Set paths
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%config.txt"
set "DEFAULT_PROFILE=config.txt"

:: Colors (using ANSI escape codes for Windows 10+)
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "CYAN=%ESC%[96m"
set "GRAY=%ESC%[90m"
set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"

:: Password masking setting
set "MASK_PASSWORD=1"

:MAIN_MENU
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                    COMPRESS AND BACKUP - CONFIG EDITOR                    %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

:: Load and display current profile
call :GET_CURRENT_PROFILE
echo   Current Job: %YELLOW%!CURRENT_PROFILE!%RESET%
echo.

echo   %BOLD%--- View ^& Edit ---%RESET%
echo   %CYAN%[1]%RESET% View Current Configuration
echo   %CYAN%[2]%RESET% Edit Settings (Interactive Menu)
echo   %CYAN%[3]%RESET% Open Config in Notepad
echo.
echo   %BOLD%--- Validation ---%RESET%
echo   %CYAN%[4]%RESET% Test All Paths
echo   %CYAN%[5]%RESET% Dry-Run Preview
echo.
echo   %BOLD%--- Security ---%RESET%
echo   %CYAN%[6]%RESET% Generate New Password
echo   %CYAN%[7]%RESET% Toggle Password Masking (Currently: %YELLOW%!MASK_PASSWORD!%RESET%)
echo.
echo   %BOLD%--- Jobs ^& Backup ---%RESET%
echo   %CYAN%[8]%RESET% Switch/Create Job
echo   %CYAN%[9]%RESET% Backup Current Config
echo   %CYAN%[10]%RESET% Reset to Defaults
echo.
echo   %CYAN%[0]%RESET% Exit
echo.
echo %CYAN%============================================================================%RESET%

set /p "CHOICE=  Enter choice: "

if "%CHOICE%"=="1" goto VIEW_CONFIG
if "%CHOICE%"=="2" goto EDIT_MENU
if "%CHOICE%"=="3" goto OPEN_NOTEPAD
if "%CHOICE%"=="4" goto TEST_PATHS
if "%CHOICE%"=="5" goto DRY_RUN
if "%CHOICE%"=="6" goto GENERATE_PASSWORD
if "%CHOICE%"=="7" goto TOGGLE_MASK
if "%CHOICE%"=="8" goto PROFILE_MENU
if "%CHOICE%"=="9" goto BACKUP_CONFIG
if "%CHOICE%"=="10" goto RESET_DEFAULTS
if "%CHOICE%"=="0" goto EXIT

echo %RED%  Invalid choice. Press any key...%RESET%
pause >nul
goto MAIN_MENU

:: ============================================================================
:: VIEW CONFIGURATION
:: ============================================================================
:VIEW_CONFIG
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                         CURRENT CONFIGURATION                             %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

call :LOAD_CONFIG

echo   %BOLD%Password:%RESET%
if "!MASK_PASSWORD!"=="1" (
    echo     %GRAY%[Hidden - Press 8 in menu to reveal]%RESET%
) else (
    echo     %YELLOW%!CFG_PASSWORD!%RESET%
)
echo.
echo   %BOLD%Source Folders/Files:%RESET% (!CFG_SOURCE_COUNT! configured)
if !CFG_SOURCE_COUNT! equ 0 (
    echo     %RED%[None configured]%RESET%
) else (
    for /L %%i in (1,1,!CFG_SOURCE_COUNT!) do (
        echo     [%%i] %YELLOW%!CFG_SOURCE_%%i!%RESET%
        if exist "!CFG_SOURCE_%%i!" (
            echo         %GREEN%[EXISTS]%RESET%
        ) else (
            echo         %RED%[NOT FOUND]%RESET%
        )
    )
)
echo.
echo   %BOLD%Archive Output Directory:%RESET%
echo     %YELLOW%!CFG_ARCHIVE_OUTPUT_DIR!%RESET%
if exist "!CFG_ARCHIVE_OUTPUT_DIR!" (
    echo     %GREEN%[EXISTS]%RESET%
) else (
    echo     %RED%[NOT FOUND]%RESET%
)
echo.
echo   %BOLD%FreeFileSync Batch File:%RESET%
if defined CFG_FFS_BATCH_FILE (
    echo     %YELLOW%!CFG_FFS_BATCH_FILE!%RESET%
    :: Resolve path for checking
    set "FFS_CHECK_PATH=!CFG_FFS_BATCH_FILE!"
    if "!FFS_CHECK_PATH:~1,1!"==":" (
        :: Absolute path
        if exist "!CFG_FFS_BATCH_FILE!" (
            echo     %GREEN%[EXISTS]%RESET%
        ) else (
            echo     %RED%[NOT FOUND]%RESET%
        )
    ) else (
        :: Relative path - check from script directory
        if exist "%SCRIPT_DIR%!CFG_FFS_BATCH_FILE!" (
            echo     %GREEN%[EXISTS]%RESET% ^(relative to script dir^)
        ) else (
            echo     %RED%[NOT FOUND]%RESET%
        )
    )
) else (
    echo     %GRAY%[Not configured - sync will be skipped]%RESET%
)

echo.
echo %CYAN%============================================================================%RESET%
echo.
pause
goto MAIN_MENU

:: ============================================================================
:: EDIT MENU
:: ============================================================================
:EDIT_MENU
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                            EDIT SETTINGS                                  %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

call :LOAD_CONFIG

echo   %CYAN%[1]%RESET% Edit Password
echo       Current: %GRAY%!CFG_PASSWORD:~0,10!...%RESET%
echo.
echo   %CYAN%[2]%RESET% Edit Compression Level
if "!CFG_COMPRESSION_LEVEL!"=="0" echo       Current: %YELLOW%0 - Store (no compression)%RESET%
if "!CFG_COMPRESSION_LEVEL!"=="1" echo       Current: %YELLOW%1 - Fastest%RESET%
if "!CFG_COMPRESSION_LEVEL!"=="3" echo       Current: %YELLOW%3 - Fast%RESET%
if "!CFG_COMPRESSION_LEVEL!"=="5" echo       Current: %YELLOW%5 - Normal%RESET%
if "!CFG_COMPRESSION_LEVEL!"=="7" echo       Current: %YELLOW%7 - Maximum%RESET%
if "!CFG_COMPRESSION_LEVEL!"=="9" echo       Current: %YELLOW%9 - Ultra%RESET%
echo.
echo   %CYAN%[3]%RESET% Edit Archive Output Directory
echo       Current: %YELLOW%!CFG_ARCHIVE_OUTPUT_DIR!%RESET%
echo.
echo   %CYAN%[4]%RESET% Edit FFS Batch File Path
if defined CFG_FFS_BATCH_FILE (
    echo       Current: %YELLOW%!CFG_FFS_BATCH_FILE!%RESET%
) else (
    echo       Current: %GRAY%[Not configured]%RESET%
)
echo.
echo   %CYAN%[5]%RESET% Manage Source Folders/Files
echo       Currently: %YELLOW%!CFG_SOURCE_COUNT! source(s) configured%RESET%
echo.
echo   %CYAN%[0]%RESET% Back to Main Menu
echo.
echo %CYAN%============================================================================%RESET%

set /p "EDIT_CHOICE=  Enter choice: "

if "%EDIT_CHOICE%"=="1" goto EDIT_PASSWORD
if "%EDIT_CHOICE%"=="2" goto EDIT_COMPRESSION
if "%EDIT_CHOICE%"=="3" goto EDIT_ARCHIVE_DIR
if "%EDIT_CHOICE%"=="4" goto EDIT_FFS_BATCH
if "%EDIT_CHOICE%"=="5" goto MANAGE_SOURCES
if "%EDIT_CHOICE%"=="0" goto MAIN_MENU

echo %RED%  Invalid choice.%RESET%
timeout /t 2 >nul
goto EDIT_MENU

:EDIT_PASSWORD
echo.
echo   Enter new password (or leave empty to cancel):
set /p "NEW_VALUE="
if not "!NEW_VALUE!"=="" (
    call :BACKUP_BEFORE_EDIT
    call :UPDATE_CONFIG "PASSWORD" "!NEW_VALUE!"
    echo   %GREEN%Password updated.%RESET%
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto EDIT_MENU

:EDIT_COMPRESSION
echo.
echo   %BOLD%Select compression level:%RESET%
echo.
echo   %CYAN%[0]%RESET% Store (no compression, fastest)
echo   %CYAN%[1]%RESET% Fastest
echo   %CYAN%[3]%RESET% Fast
echo   %CYAN%[5]%RESET% Normal
echo   %CYAN%[7]%RESET% Maximum
echo   %CYAN%[9]%RESET% Ultra (smallest size, slowest)
echo.
set /p "COMP_CHOICE=  Enter level (0/1/3/5/7/9): "
if "!COMP_CHOICE!"=="0" goto SET_COMPRESSION
if "!COMP_CHOICE!"=="1" goto SET_COMPRESSION
if "!COMP_CHOICE!"=="3" goto SET_COMPRESSION
if "!COMP_CHOICE!"=="5" goto SET_COMPRESSION
if "!COMP_CHOICE!"=="7" goto SET_COMPRESSION
if "!COMP_CHOICE!"=="9" goto SET_COMPRESSION
echo   %RED%Invalid choice. Use 0, 1, 3, 5, 7, or 9.%RESET%
timeout /t 2 >nul
goto EDIT_MENU

:SET_COMPRESSION
call :BACKUP_BEFORE_EDIT
call :UPDATE_CONFIG "COMPRESSION_LEVEL" "!COMP_CHOICE!"
echo   %GREEN%Compression level updated to !COMP_CHOICE!.%RESET%
timeout /t 2 >nul
goto EDIT_MENU

:EDIT_ARCHIVE_DIR
echo.
echo   Current: !CFG_ARCHIVE_OUTPUT_DIR!
echo.
echo   %CYAN%[1]%RESET% Type path manually
echo   %CYAN%[2]%RESET% Browse with folder picker
echo   %CYAN%[0]%RESET% Cancel
echo.
set /p "DIR_CHOICE=  Enter choice: "
if "!DIR_CHOICE!"=="1" (
    echo.
    echo   Enter new archive output directory:
    set /p "NEW_VALUE="
    if not "!NEW_VALUE!"=="" (
        if exist "!NEW_VALUE!" (
            call :BACKUP_BEFORE_EDIT
            call :UPDATE_CONFIG "ARCHIVE_OUTPUT_DIR" "!NEW_VALUE!"
            echo   %GREEN%Archive output directory updated.%RESET%
        ) else (
            echo   %RED%Warning: Path does not exist!%RESET%
            set /p "CONFIRM=  Save anyway? (Y/N): "
            if /i "!CONFIRM!"=="Y" (
                call :BACKUP_BEFORE_EDIT
                call :UPDATE_CONFIG "ARCHIVE_OUTPUT_DIR" "!NEW_VALUE!"
                echo   %GREEN%Archive output directory updated.%RESET%
            ) else (
                echo   %YELLOW%Cancelled.%RESET%
            )
        )
    ) else (
        echo   %YELLOW%Cancelled.%RESET%
    )
) else if "!DIR_CHOICE!"=="2" (
    goto BROWSE_ARCHIVE
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto EDIT_MENU

:BROWSE_ARCHIVE
echo.
echo   %CYAN%Opening folder picker...%RESET%
call :BROWSE_FOLDER "Select Archive Output Directory"
if not "!SELECTED_FOLDER!"=="" (
    call :BACKUP_BEFORE_EDIT
    call :UPDATE_CONFIG "ARCHIVE_OUTPUT_DIR" "!SELECTED_FOLDER!"
    echo   %GREEN%Archive output directory updated to: !SELECTED_FOLDER!%RESET%
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto EDIT_MENU

:EDIT_FFS_BATCH
echo.
if defined CFG_FFS_BATCH_FILE (
    echo   Current: !CFG_FFS_BATCH_FILE!
) else (
    echo   Current: [Not configured]
)
echo.
echo   %CYAN%[1]%RESET% Type path manually
echo   %CYAN%[2]%RESET% Browse for .ffs_batch file
echo   %CYAN%[3]%RESET% Clear ^(disable sync^)
echo   %CYAN%[0]%RESET% Cancel
echo.
set /p "FFS_CHOICE=  Enter choice: "
if "!FFS_CHOICE!"=="1" (
    echo.
    echo   Enter path to .ffs_batch file:
    echo   ^(Can be relative to script dir, e.g., sync-backup.ffs_batch^)
    set /p "NEW_VALUE="
    if not "!NEW_VALUE!"=="" (
        :: Check if file exists (handle relative path)
        set "CHECK_PATH=!NEW_VALUE!"
        set "FILE_EXISTS=0"
        if "!CHECK_PATH:~1,1!"==":" (
            if exist "!NEW_VALUE!" set "FILE_EXISTS=1"
        ) else (
            if exist "%SCRIPT_DIR%!NEW_VALUE!" set "FILE_EXISTS=1"
        )
        if "!FILE_EXISTS!"=="1" (
            call :BACKUP_BEFORE_EDIT
            call :UPDATE_CONFIG "FFS_BATCH_FILE" "!NEW_VALUE!"
            echo   %GREEN%FFS batch file path updated.%RESET%
        ) else (
            echo   %RED%Warning: File does not exist!%RESET%
            set /p "CONFIRM=  Save anyway? (Y/N): "
            if /i "!CONFIRM!"=="Y" (
                call :BACKUP_BEFORE_EDIT
                call :UPDATE_CONFIG "FFS_BATCH_FILE" "!NEW_VALUE!"
                echo   %GREEN%FFS batch file path updated.%RESET%
            ) else (
                echo   %YELLOW%Cancelled.%RESET%
            )
        )
    ) else (
        echo   %YELLOW%Cancelled.%RESET%
    )
) else if "!FFS_CHOICE!"=="2" (
    goto BROWSE_FFS_BATCH
) else if "!FFS_CHOICE!"=="3" (
    call :BACKUP_BEFORE_EDIT
    call :UPDATE_CONFIG "FFS_BATCH_FILE" ""
    echo   %GREEN%FFS batch file cleared. Sync will be skipped.%RESET%
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto EDIT_MENU

:BROWSE_FFS_BATCH
echo.
echo   %CYAN%Opening file picker...%RESET%
set "SELECTED_FILE="
for /f "delims=" %%F in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $file = New-Object System.Windows.Forms.OpenFileDialog; $file.Title = 'Select FreeFileSync Batch File'; $file.Filter = 'FFS Batch files (*.ffs_batch)|*.ffs_batch|All files (*.*)|*.*'; $file.InitialDirectory = '%SCRIPT_DIR:\=\\%'; if ($file.ShowDialog() -eq 'OK') { $file.FileName }"') do set "SELECTED_FILE=%%F"
if not "!SELECTED_FILE!"=="" (
    call :BACKUP_BEFORE_EDIT
    call :UPDATE_CONFIG "FFS_BATCH_FILE" "!SELECTED_FILE!"
    echo   %GREEN%FFS batch file updated to: !SELECTED_FILE!%RESET%
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto EDIT_MENU

:: ============================================================================
:: MANAGE SOURCE FOLDERS/FILES
:: ============================================================================
:MANAGE_SOURCES
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                      MANAGE SOURCE FOLDERS/FILES                         %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

call :LOAD_CONFIG

echo   %BOLD%Current Sources (%CFG_SOURCE_COUNT% configured):%RESET%
if !CFG_SOURCE_COUNT! equ 0 (
    echo   %YELLOW%[None configured]%RESET%
) else (
    for /L %%i in (1,1,!CFG_SOURCE_COUNT!) do (
        echo   [%%i] %YELLOW%!CFG_SOURCE_%%i!%RESET%
        if exist "!CFG_SOURCE_%%i!" (
            echo       %GREEN%[EXISTS]%RESET%
        ) else (
            echo       %RED%[NOT FOUND]%RESET%
        )
    )
)
echo.
echo   %CYAN%[1]%RESET% Add Source (type path)
echo   %CYAN%[2]%RESET% Add Source (browse for folder)
echo   %CYAN%[3]%RESET% Add Source (browse for file)
echo   %CYAN%[4]%RESET% Remove Source
echo   %CYAN%[5]%RESET% Clear All Sources
echo.
echo   %CYAN%[0]%RESET% Back to Edit Menu
echo.
echo %CYAN%============================================================================%RESET%

set /p "SRC_CHOICE=  Enter choice: "

if "!SRC_CHOICE!"=="1" goto ADD_SOURCE_TYPE
if "!SRC_CHOICE!"=="2" goto ADD_SOURCE_BROWSE_FOLDER
if "!SRC_CHOICE!"=="3" goto ADD_SOURCE_BROWSE_FILE
if "!SRC_CHOICE!"=="4" goto REMOVE_SOURCE
if "!SRC_CHOICE!"=="5" goto CLEAR_SOURCES
if "!SRC_CHOICE!"=="0" goto EDIT_MENU

echo %RED%  Invalid choice.%RESET%
timeout /t 2 >nul
goto MANAGE_SOURCES

:ADD_SOURCE_TYPE
echo.
echo   Enter path to folder or file (or leave empty to cancel):
set /p "NEW_SOURCE="
if not "!NEW_SOURCE!"=="" (
    if exist "!NEW_SOURCE!" (
        call :BACKUP_BEFORE_EDIT
        call :ADD_SOURCE_TO_CONFIG "!NEW_SOURCE!"
        echo   %GREEN%Source added successfully.%RESET%
    ) else (
        echo   %RED%Warning: Path does not exist!%RESET%
        set /p "CONFIRM=  Add anyway? (Y/N): "
        if /i "!CONFIRM!"=="Y" (
            call :BACKUP_BEFORE_EDIT
            call :ADD_SOURCE_TO_CONFIG "!NEW_SOURCE!"
            echo   %GREEN%Source added.%RESET%
        ) else (
            echo   %YELLOW%Cancelled.%RESET%
        )
    )
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto MANAGE_SOURCES

:ADD_SOURCE_BROWSE_FOLDER
echo.
echo   %CYAN%Opening folder picker...%RESET%
call :BROWSE_FOLDER "Select Source Folder"
if not "!SELECTED_FOLDER!"=="" (
    call :BACKUP_BEFORE_EDIT
    call :ADD_SOURCE_TO_CONFIG "!SELECTED_FOLDER!"
    echo   %GREEN%Source folder added: !SELECTED_FOLDER!%RESET%
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto MANAGE_SOURCES

:ADD_SOURCE_BROWSE_FILE
echo.
echo   %CYAN%Opening file picker...%RESET%
set "SELECTED_FILE="
for /f "delims=" %%F in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $file = New-Object System.Windows.Forms.OpenFileDialog; $file.Title = 'Select Source File'; $file.Filter = 'All files (*.*)|*.*'; if ($file.ShowDialog() -eq 'OK') { $file.FileName }"') do set "SELECTED_FILE=%%F"
if not "!SELECTED_FILE!"=="" (
    call :BACKUP_BEFORE_EDIT
    call :ADD_SOURCE_TO_CONFIG "!SELECTED_FILE!"
    echo   %GREEN%Source file added: !SELECTED_FILE!%RESET%
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto MANAGE_SOURCES

:REMOVE_SOURCE
if !CFG_SOURCE_COUNT! equ 0 (
    echo.
    echo   %RED%No sources to remove.%RESET%
    timeout /t 2 >nul
    goto MANAGE_SOURCES
)
echo.
echo   Enter source number to remove (1-!CFG_SOURCE_COUNT!) or 0 to cancel:
set /p "REMOVE_NUM="
if "!REMOVE_NUM!"=="0" (
    echo   %YELLOW%Cancelled.%RESET%
    timeout /t 2 >nul
    goto MANAGE_SOURCES
)
if !REMOVE_NUM! GEQ 1 if !REMOVE_NUM! LEQ !CFG_SOURCE_COUNT! (
    call :BACKUP_BEFORE_EDIT
    call :REMOVE_SOURCE_FROM_CONFIG !REMOVE_NUM!
    echo   %GREEN%Source removed successfully.%RESET%
) else (
    echo   %RED%Invalid source number.%RESET%
)
timeout /t 2 >nul
goto MANAGE_SOURCES

:CLEAR_SOURCES
if !CFG_SOURCE_COUNT! equ 0 (
    echo.
    echo   %YELLOW%No sources to clear.%RESET%
    timeout /t 2 >nul
    goto MANAGE_SOURCES
)
echo.
echo   %RED%Warning: This will remove ALL !CFG_SOURCE_COUNT! source(s)!%RESET%
set /p "CONFIRM=  Are you sure? (Y/N): "
if /i "!CONFIRM!"=="Y" (
    call :BACKUP_BEFORE_EDIT
    call :CLEAR_ALL_SOURCES
    echo   %GREEN%All sources cleared.%RESET%
) else (
    echo   %YELLOW%Cancelled.%RESET%
)
timeout /t 2 >nul
goto MANAGE_SOURCES

:: ============================================================================
:: ============================================================================
:: OPEN IN NOTEPAD
:: ============================================================================
:OPEN_NOTEPAD
echo.
echo   %CYAN%Opening config in Notepad...%RESET%
start notepad "!CONFIG_FILE!"
timeout /t 1 >nul
goto MAIN_MENU

::: ============================================================================
:: TEST PATHS
:: ============================================================================
:TEST_PATHS
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                            PATH VALIDATION                                %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

call :LOAD_CONFIG

set "ALL_VALID=1"

echo   %BOLD%Testing Source Folders/Files (%CFG_SOURCE_COUNT% configured):%RESET%
if !CFG_SOURCE_COUNT! equ 0 (
    echo   %RED%[FAIL] No sources configured%RESET%
    set "ALL_VALID=0"
) else (
    for /L %%i in (1,1,!CFG_SOURCE_COUNT!) do (
        echo   [%%i] !CFG_SOURCE_%%i!
        if exist "!CFG_SOURCE_%%i!" (
            echo       %GREEN%[OK] Exists%RESET%
        ) else (
            echo       %RED%[FAIL] Not found%RESET%
            set "ALL_VALID=0"
        )
    )
)
echo.

echo   %BOLD%Testing Archive Output Directory:%RESET%
echo   Path: !CFG_ARCHIVE_OUTPUT_DIR!
if exist "!CFG_ARCHIVE_OUTPUT_DIR!" (
    echo   Status: %GREEN%[OK] Folder exists%RESET%
    :: Test write access
    set "TEST_FILE=!CFG_ARCHIVE_OUTPUT_DIR!\.write_test_%RANDOM%"
    echo test > "!TEST_FILE!" 2>nul
    if exist "!TEST_FILE!" (
        del "!TEST_FILE!" >nul 2>&1
        echo   Write: %GREEN%[OK] Writable%RESET%
    ) else (
        echo   Write: %RED%[FAIL] Not writable%RESET%
        set "ALL_VALID=0"
    )
) else (
    echo   Status: %RED%[FAIL] Folder does not exist%RESET%
    set "ALL_VALID=0"
)
echo.

echo   %BOLD%Testing FreeFileSync Batch File:%RESET%
if defined CFG_FFS_BATCH_FILE (
    echo   Path: !CFG_FFS_BATCH_FILE!
    :: Check if it's an absolute or relative path
    set "FFS_CHECK=!CFG_FFS_BATCH_FILE!"
    set "FFS_RESOLVED="
    if "!FFS_CHECK:~1,1!"==":" (
        set "FFS_RESOLVED=!CFG_FFS_BATCH_FILE!"
    ) else (
        set "FFS_RESOLVED=%SCRIPT_DIR%!CFG_FFS_BATCH_FILE!"
    )
    if exist "!FFS_RESOLVED!" (
        echo   Status: %GREEN%[OK] File exists%RESET%
    ) else (
        echo   Status: %RED%[FAIL] File not found%RESET%
        set "ALL_VALID=0"
    )
) else (
    echo   Path: %GRAY%[Not configured]%RESET%
    echo   Status: %YELLOW%[SKIP] Sync will be skipped%RESET%
)
)
echo.

echo %CYAN%============================================================================%RESET%
if "!ALL_VALID!"=="1" (
    echo   %GREEN%All local paths validated successfully!%RESET%
) else (
    echo   %RED%Some paths have issues. Please fix before running backup.%RESET%
)
echo.
pause
goto MAIN_MENU

:: ============================================================================
:: DRY RUN PREVIEW
:: ============================================================================
:DRY_RUN
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                           DRY-RUN PREVIEW                                 %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

call :LOAD_CONFIG

:: Determine archive name
if !CFG_SOURCE_COUNT! equ 1 (
    for %%F in ("!CFG_SOURCE_1!") do set "ARCHIVE_NAME=%%~nxF"
) else (
    set "ARCHIVE_NAME=backup_%DATE:~-4%%DATE:~-10,2%%DATE:~-7,2%"
    set "ARCHIVE_NAME=!ARCHIVE_NAME: =0!"
)

echo   %BOLD%What the backup script will do:%RESET%
echo.
echo   %CYAN%Step 1:%RESET% Compress !CFG_SOURCE_COUNT! source(s) into one archive
for /L %%i in (1,1,!CFG_SOURCE_COUNT!) do (
    echo           [%%i] !CFG_SOURCE_%%i!
)
echo           Output:  !CFG_ARCHIVE_OUTPUT_DIR!\!ARCHIVE_NAME!.7z
echo           Method:  7z with AES-256 encryption
echo.
echo   %CYAN%Step 2:%RESET% Verify archive integrity
echo.
if defined CFG_FFS_BATCH_FILE (
    echo   %CYAN%Step 3:%RESET% Sync with FreeFileSync
    echo           Batch:   !CFG_FFS_BATCH_FILE!
) else (
    echo   %CYAN%Step 3:%RESET% %YELLOW%Sync will be SKIPPED%RESET% ^(no FFS_BATCH_FILE configured^)
)
echo.

:: Estimate size
set "TOTAL_SIZE=0"
for /L %%i in (1,1,!CFG_SOURCE_COUNT!) do (
    if exist "!CFG_SOURCE_%%i!" (
        for /f "tokens=3" %%a in ('dir "!CFG_SOURCE_%%i!" /s /-c 2^>nul ^| findstr /C:"File(s)"') do (
            set /a "TOTAL_SIZE+=%%a/1048576" 2>nul
        )
    )
)

echo   %BOLD%Estimated total source size:%RESET% ~!TOTAL_SIZE! MB (before compression)
echo.

:: Check if archive already exists
if exist "!CFG_ARCHIVE_OUTPUT_DIR!\!ARCHIVE_NAME!.7z" (
    echo   %YELLOW%Note: Archive already exists and will be OVERWRITTEN%RESET%
    for %%A in ("!CFG_ARCHIVE_OUTPUT_DIR!\!ARCHIVE_NAME!.7z") do (
        echo         Existing file: %%~zA bytes, modified %%~tA
    )
) else (
    echo   %GREEN%Note: New archive will be created%RESET%
)
echo.

echo %CYAN%============================================================================%RESET%
echo.
pause
goto MAIN_MENU

:: ============================================================================
:: GENERATE PASSWORD
:: ============================================================================
:GENERATE_PASSWORD
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                         PASSWORD GENERATOR                                %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

echo   %BOLD%Choose password style:%RESET%
echo.
echo   %CYAN%[1]%RESET% Passphrase (word-based, easy to type)
echo       Example: correct-horse-battery-staple-42
echo.
echo   %CYAN%[2]%RESET% Random (mixed characters, maximum security)
echo       Example: K#9xMp$2vL@nQ7wR
echo.
echo   %CYAN%[3]%RESET% Alphanumeric (letters and numbers only)
echo       Example: Xk9mP2vLnQ7wRt5H
echo.
echo   %CYAN%[0]%RESET% Cancel
echo.

set /p "PW_STYLE=  Enter choice: "

if "%PW_STYLE%"=="0" goto MAIN_MENU
if "%PW_STYLE%"=="1" goto GEN_PASSPHRASE
if "%PW_STYLE%"=="2" goto GEN_RANDOM
if "%PW_STYLE%"=="3" goto GEN_ALPHANUM

echo %RED%  Invalid choice.%RESET%
timeout /t 2 >nul
goto GENERATE_PASSWORD

:GEN_PASSPHRASE
echo.
set /p "WORD_COUNT=  How many words? (3-8, default 5): "
if "!WORD_COUNT!"=="" set "WORD_COUNT=5"

:: Word list for passphrase generation
set "WORDS=anchor bacon castle dragon eagle falcon garden hammer island jungle kettle lemon mango nectar orange puzzle quartz rocket sunset temple umbrella violet winter xenon yellow zephyr alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform victor whiskey xray yankee zulu"

set "PASSPHRASE="
set "WORD_INDEX=0"

:: Generate random words using PowerShell
for /f "delims=" %%W in ('powershell -Command "$words = '%WORDS%' -split ' '; $result = @(); for($i=0; $i -lt %WORD_COUNT%; $i++) { $result += $words[(Get-Random -Maximum $words.Count)] }; ($result -join '-') + '-' + (Get-Random -Minimum 10 -Maximum 99)"') do set "PASSPHRASE=%%W"

echo.
echo   %GREEN%Generated Passphrase:%RESET%
echo   %YELLOW%!PASSPHRASE!%RESET%
echo.
set /p "APPLY_PW=  Apply this password to config? (Y/N): "
if /i "!APPLY_PW!"=="Y" (
    call :BACKUP_BEFORE_EDIT
    call :UPDATE_CONFIG "PASSWORD" "!PASSPHRASE!"
    echo   %GREEN%Password updated!%RESET%
)
timeout /t 2 >nul
goto MAIN_MENU

:GEN_RANDOM
echo.
set /p "PW_LENGTH=  Password length? (12-64, default 24): "
if "!PW_LENGTH!"=="" set "PW_LENGTH=24"

for /f "delims=" %%P in ('powershell -Command "$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%%^&*'; -join (1..%PW_LENGTH% | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })"') do set "RANDOM_PW=%%P"

echo.
echo   %GREEN%Generated Password:%RESET%
echo   %YELLOW%!RANDOM_PW!%RESET%
echo.
set /p "APPLY_PW=  Apply this password to config? (Y/N): "
if /i "!APPLY_PW!"=="Y" (
    call :BACKUP_BEFORE_EDIT
    call :UPDATE_CONFIG "PASSWORD" "!RANDOM_PW!"
    echo   %GREEN%Password updated!%RESET%
)
timeout /t 2 >nul
goto MAIN_MENU

:GEN_ALPHANUM
echo.
set /p "PW_LENGTH=  Password length? (12-64, default 24): "
if "!PW_LENGTH!"=="" set "PW_LENGTH=24"

for /f "delims=" %%P in ('powershell -Command "$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'; -join (1..%PW_LENGTH% | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })"') do set "ALPHANUM_PW=%%P"

echo.
echo   %GREEN%Generated Password:%RESET%
echo   %YELLOW%!ALPHANUM_PW!%RESET%
echo.
set /p "APPLY_PW=  Apply this password to config? (Y/N): "
if /i "!APPLY_PW!"=="Y" (
    call :BACKUP_BEFORE_EDIT
    call :UPDATE_CONFIG "PASSWORD" "!ALPHANUM_PW!"
    echo   %GREEN%Password updated!%RESET%
)
timeout /t 2 >nul
goto MAIN_MENU

:: ============================================================================
:: TOGGLE PASSWORD MASK
:: ============================================================================
:TOGGLE_MASK
if "!MASK_PASSWORD!"=="1" (
    set "MASK_PASSWORD=0"
    echo   %YELLOW%Password masking disabled - passwords will be shown%RESET%
) else (
    set "MASK_PASSWORD=1"
    echo   %GREEN%Password masking enabled - passwords will be hidden%RESET%
)
timeout /t 2 >nul
goto MAIN_MENU

:: ============================================================================
:: JOB MENU (formerly PROFILE MENU)
:: ============================================================================
:PROFILE_MENU
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                            JOB MANAGEMENT                                 %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

:: Check current default job
set "DEFAULT_JOB="
set "ACTIVE_JOB_FILE=%SCRIPT_DIR%active-job.txt"
if exist "!ACTIVE_JOB_FILE!" (
    for /f "usebackq delims=" %%J in ("!ACTIVE_JOB_FILE!") do set "DEFAULT_JOB=%%J"
)

echo   %BOLD%Available Jobs:%RESET%
echo.
set "PROFILE_NUM=0"
for %%F in ("%SCRIPT_DIR%config*.txt") do (
    set "FNAME=%%~nxF"
    :: Skip backup files
    echo !FNAME! | findstr /i "\.bak\>" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo !FNAME! | findstr /i "backup" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            set /a "PROFILE_NUM+=1"
            set "PROFILE_!PROFILE_NUM!=%%~nxF"
            :: Determine job display name
            if "%%~nxF"=="config.txt" (
                set "JOB_DISPLAY_NAME=default"
            ) else (
                set "JOB_DISPLAY_NAME=%%~nxF"
                set "JOB_DISPLAY_NAME=!JOB_DISPLAY_NAME:config-=!"
                set "JOB_DISPLAY_NAME=!JOB_DISPLAY_NAME:.txt=!"
            )
            :: Build display line with markers
            set "MARKERS="
            if "%%~nxF"=="!CURRENT_PROFILE!" set "MARKERS=!MARKERS! %GREEN%[EDITING]%RESET%"
            if "!JOB_DISPLAY_NAME!"=="!DEFAULT_JOB!" set "MARKERS=!MARKERS! %CYAN%[DEFAULT]%RESET%"
            echo   %CYAN%[!PROFILE_NUM!]%RESET% !JOB_DISPLAY_NAME!!MARKERS!
        )
    )
)
echo.
echo   %CYAN%[N]%RESET% Create New Job
echo   %CYAN%[D]%RESET% Set Default Job ^(for compress-and-backup.bat^)
echo   %CYAN%[0]%RESET% Back to Main Menu
echo.
echo %CYAN%============================================================================%RESET%

set /p "PROFILE_CHOICE=  Enter choice: "

if /i "%PROFILE_CHOICE%"=="0" goto MAIN_MENU
if /i "%PROFILE_CHOICE%"=="N" goto CREATE_PROFILE
if /i "%PROFILE_CHOICE%"=="D" goto SET_DEFAULT_JOB

:: Check if numeric choice
set /a "CHECK_NUM=%PROFILE_CHOICE%" 2>nul
if !CHECK_NUM! gtr 0 if !CHECK_NUM! leq !PROFILE_NUM! (
    set "SELECTED_PROFILE=!PROFILE_%PROFILE_CHOICE%!"
    set "CONFIG_FILE=%SCRIPT_DIR%!SELECTED_PROFILE!"
    echo   %GREEN%Switched to job: !SELECTED_PROFILE!%RESET%
    timeout /t 2 >nul
    goto MAIN_MENU
)

echo %RED%  Invalid choice.%RESET%
timeout /t 2 >nul
goto PROFILE_MENU

:SET_DEFAULT_JOB
echo.
echo   %BOLD%Set Default Job:%RESET%
echo   The default job runs automatically when compress-and-backup.bat
 echo   is executed without arguments.
echo.
set "DJOB_IDX=0"
for %%F in ("%SCRIPT_DIR%config*.txt") do (
    set "FNAME=%%~nxF"
    echo !FNAME! | findstr /i "\.bak\>" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo !FNAME! | findstr /i "backup" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            set /a "DJOB_IDX+=1"
            set "DJOB_!DJOB_IDX!=%%~nxF"
            if "%%~nxF"=="config.txt" (
                echo   %CYAN%[!DJOB_IDX!]%RESET% default
            ) else (
                set "DJOB_DISP=%%~nxF"
                set "DJOB_DISP=!DJOB_DISP:config-=!"
                set "DJOB_DISP=!DJOB_DISP:.txt=!"
                echo   %CYAN%[!DJOB_IDX!]%RESET% !DJOB_DISP!
            )
        )
    )
)
echo.
echo   %CYAN%[C]%RESET% Clear default ^(show menu each time^)
echo   %CYAN%[0]%RESET% Cancel
echo.
set /p "DEFAULT_CHOICE=  Select job to set as default: "

if /i "!DEFAULT_CHOICE!"=="0" goto PROFILE_MENU
if /i "!DEFAULT_CHOICE!"=="C" (
    if exist "!ACTIVE_JOB_FILE!" del "!ACTIVE_JOB_FILE!" >nul 2>&1
    echo   %GREEN%Default cleared. Job menu will show each time.%RESET%
    timeout /t 2 >nul
    goto PROFILE_MENU
)

set /a "CHECK_DEFAULT=!DEFAULT_CHOICE!" 2>nul
if !CHECK_DEFAULT! GEQ 1 if !CHECK_DEFAULT! LEQ !DJOB_IDX! (
    set "SELECTED_DEFAULT=!DJOB_%DEFAULT_CHOICE%!"
    if "!SELECTED_DEFAULT!"=="config.txt" (
        echo default> "!ACTIVE_JOB_FILE!"
        echo   %GREEN%Default job set to: default%RESET%
    ) else (
        set "SAVE_NAME=!SELECTED_DEFAULT:config-=!"
        set "SAVE_NAME=!SAVE_NAME:.txt=!"
        echo !SAVE_NAME!> "!ACTIVE_JOB_FILE!"
        echo   %GREEN%Default job set to: !SAVE_NAME!%RESET%
    )
    timeout /t 2 >nul
    goto PROFILE_MENU
)

echo %RED%  Invalid choice.%RESET%
timeout /t 2 >nul
goto SET_DEFAULT_JOB

:CREATE_PROFILE
echo.
set /p "NEW_PROFILE_NAME=  Enter new job name (without .txt): "
if "!NEW_PROFILE_NAME!"=="" (
    echo   %YELLOW%Cancelled.%RESET%
    timeout /t 2 >nul
    goto PROFILE_MENU
)

set "NEW_PROFILE_FILE=%SCRIPT_DIR%config-!NEW_PROFILE_NAME!.txt"

if exist "!NEW_PROFILE_FILE!" (
    echo   %RED%Job already exists!%RESET%
    timeout /t 2 >nul
    goto PROFILE_MENU
)

:: Copy current config as template
copy "!CONFIG_FILE!" "!NEW_PROFILE_FILE!" >nul
set "CONFIG_FILE=!NEW_PROFILE_FILE!"

echo   %GREEN%Created and switched to job: !NEW_PROFILE_NAME!%RESET%
timeout /t 2 >nul
goto MAIN_MENU

:: ============================================================================
:: BACKUP CONFIG
:: ============================================================================
:BACKUP_CONFIG
set "BACKUP_NAME=config.backup.%DATE:~-4%%DATE:~-10,2%%DATE:~-7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.txt"
set "BACKUP_NAME=!BACKUP_NAME: =0!"
set "BACKUP_FILE=%SCRIPT_DIR%!BACKUP_NAME!"

copy "!CONFIG_FILE!" "!BACKUP_FILE!" >nul

if exist "!BACKUP_FILE!" (
    echo.
    echo   %GREEN%Backup created: !BACKUP_NAME!%RESET%
) else (
    echo.
    echo   %RED%Failed to create backup!%RESET%
)
timeout /t 2 >nul
goto MAIN_MENU

:: ============================================================================
:: RESET TO DEFAULTS
:: ============================================================================
:RESET_DEFAULTS
cls
echo %BOLD%%CYAN%============================================================================%RESET%
echo %BOLD%%CYAN%                          RESET TO DEFAULTS                                %RESET%
echo %BOLD%%CYAN%============================================================================%RESET%
echo.

echo   %RED%WARNING: This will overwrite your current configuration!%RESET%
echo.
echo   A backup will be created first.
echo.
set /p "CONFIRM_RESET=  Are you sure? Type 'RESET' to confirm: "

if not "!CONFIRM_RESET!"=="RESET" (
    echo   %YELLOW%Cancelled.%RESET%
    timeout /t 2 >nul
    goto MAIN_MENU
)

:: Create backup first
call :BACKUP_BEFORE_EDIT

:: Write default config
(
echo # Compress and Backup Configuration
echo # ==================================
echo.
echo # Password for 7z archive ^(keep this file secure!^)
echo PASSWORD=CHANGE-THIS-PASSWORD
echo.
echo # Compression level: 0=Store, 1=Fastest, 3=Fast, 5=Normal, 7=Maximum, 9=Ultra
echo COMPRESSION_LEVEL=0
echo.
echo # Source folders/files to compress ^(add as many as needed: SOURCE_1, SOURCE_2, etc.^)
echo SOURCE_1=C:\Path\To\Your\Folder
echo.
echo # Where to save the compressed .7z file
echo ARCHIVE_OUTPUT_DIR=C:\Backups
echo.
echo # FreeFileSync batch file path ^(create your own .ffs_batch file in FreeFileSync^)
echo # Leave empty to skip sync step. Can be relative ^(e.g., sync-backup.ffs_batch^) or absolute.
echo FFS_BATCH_FILE=
) > "!CONFIG_FILE!"

echo.
echo   %GREEN%Configuration reset to defaults.%RESET%
echo   %YELLOW%Please edit the settings before running backup.%RESET%
timeout /t 3 >nul
goto MAIN_MENU

:: ============================================================================
:: HELPER FUNCTIONS
:: ============================================================================

:LOAD_CONFIG
set "CFG_PASSWORD="
set "CFG_COMPRESSION_LEVEL=0"
set "CFG_ARCHIVE_OUTPUT_DIR="
set "CFG_FFS_BATCH_FILE="
set "CFG_SOURCE_COUNT=0"

:: Clear previous source entries (up to 20)
for /L %%i in (1,1,20) do set "CFG_SOURCE_%%i="

if not exist "!CONFIG_FILE!" (
    echo   %RED%Config file not found!%RESET%
    goto :eof
)

for /f "usebackq tokens=1,* delims==" %%A in ("!CONFIG_FILE!") do (
    set "LINE=%%A"
    if not "!LINE:~0,1!"=="#" if not "%%A"=="" (
        if "%%A"=="PASSWORD" set "CFG_PASSWORD=%%B"
        if "%%A"=="COMPRESSION_LEVEL" set "CFG_COMPRESSION_LEVEL=%%B"
        if "%%A"=="ARCHIVE_OUTPUT_DIR" set "CFG_ARCHIVE_OUTPUT_DIR=%%B"
        if "%%A"=="FFS_BATCH_FILE" set "CFG_FFS_BATCH_FILE=%%B"
        set "KEY_NAME=%%A"
        if "!KEY_NAME:~0,7!"=="SOURCE_" (
            set /a "CFG_SOURCE_COUNT+=1"
            set "CFG_SOURCE_!CFG_SOURCE_COUNT!=%%B"
        )
    )
)
goto :eof

:GET_CURRENT_PROFILE
for %%F in ("!CONFIG_FILE!") do set "CURRENT_PROFILE=%%~nxF"
goto :eof

:BACKUP_BEFORE_EDIT
if not exist "%SCRIPT_DIR%config.txt.bak" (
    copy "!CONFIG_FILE!" "%SCRIPT_DIR%config.txt.bak" >nul 2>&1
)
goto :eof

:UPDATE_CONFIG
set "KEY=%~1"
set "VALUE=%~2"

:: Create temp file with updated value
set "TEMP_FILE=%SCRIPT_DIR%config.tmp"

(
    for /f "usebackq tokens=1,* delims==" %%A in ("!CONFIG_FILE!") do (
        set "LINE=%%A"
        if "!LINE:~0,1!"=="#" (
            echo %%A=%%B
        ) else if "%%A"=="" (
            echo.
        ) else if "%%A"=="!KEY!" (
            echo !KEY!=!VALUE!
        ) else (
            echo %%A=%%B
        )
    )
) > "!TEMP_FILE!"

:: Handle comment lines and empty lines properly
> "!TEMP_FILE!" (
    for /f "usebackq delims=" %%L in ("!CONFIG_FILE!") do (
        set "LINE=%%L"
        if "!LINE:~0,1!"=="#" (
            echo %%L
        ) else (
            for /f "tokens=1 delims==" %%K in ("%%L") do (
                if "%%K"=="!KEY!" (
                    echo !KEY!=!VALUE!
                ) else (
                    echo %%L
                )
            )
        )
    )
)

move /y "!TEMP_FILE!" "!CONFIG_FILE!" >nul
goto :eof

:BROWSE_FOLDER
set "SELECTED_FOLDER="
set "DIALOG_TITLE=%~1"

for /f "delims=" %%F in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $folder = New-Object System.Windows.Forms.FolderBrowserDialog; $folder.Description = '%DIALOG_TITLE%'; $folder.ShowNewFolderButton = $true; if ($folder.ShowDialog() -eq 'OK') { $folder.SelectedPath }"') do set "SELECTED_FOLDER=%%F"

goto :eof

:ADD_SOURCE_TO_CONFIG
set "NEW_SRC_PATH=%~1"
:: Find the next available SOURCE_N number
set "NEXT_NUM=1"
:FIND_NEXT_SOURCE_NUM
for /f "usebackq tokens=1,* delims==" %%A in ("!CONFIG_FILE!") do (
    if "%%A"=="SOURCE_!NEXT_NUM!" (
        set /a "NEXT_NUM+=1"
        goto FIND_NEXT_SOURCE_NUM
    )
)
:: Append to config file
echo SOURCE_!NEXT_NUM!=!NEW_SRC_PATH!>> "!CONFIG_FILE!"
goto :eof

:REMOVE_SOURCE_FROM_CONFIG
set "REMOVE_IDX=%~1"
set "TEMP_FILE=%SCRIPT_DIR%config.tmp"
set "CURRENT_SOURCE_NUM=0"
set "NEW_SOURCE_NUM=0"

:: Rewrite config, renumbering sources and skipping the removed one
> "!TEMP_FILE!" (
    for /f "usebackq delims=" %%L in ("!CONFIG_FILE!") do (
        set "LINE=%%L"
        set "IS_SOURCE=0"
        :: Check if line starts with SOURCE_
        echo %%L | findstr /b "SOURCE_" >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            set "IS_SOURCE=1"
            set /a "CURRENT_SOURCE_NUM+=1"
        )
        if !IS_SOURCE! EQU 1 (
            if !CURRENT_SOURCE_NUM! NEQ !REMOVE_IDX! (
                set /a "NEW_SOURCE_NUM+=1"
                :: Extract the path value
                for /f "tokens=1,* delims==" %%A in ("%%L") do (
                    echo SOURCE_!NEW_SOURCE_NUM!=%%B
                )
            )
        ) else (
            echo %%L
        )
    )
)

move /y "!TEMP_FILE!" "!CONFIG_FILE!" >nul
goto :eof

:CLEAR_ALL_SOURCES
set "TEMP_FILE=%SCRIPT_DIR%config.tmp"

:: Rewrite config without any SOURCE_ lines
> "!TEMP_FILE!" (
    for /f "usebackq delims=" %%L in ("!CONFIG_FILE!") do (
        set "LINE=%%L"
        echo %%L | findstr /b "SOURCE_" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo %%L
        )
    )
)

move /y "!TEMP_FILE!" "!CONFIG_FILE!" >nul
goto :eof

:: ============================================================================
:: EXIT
:: ============================================================================
:EXIT
echo.
echo   %CYAN%Goodbye!%RESET%
timeout /t 1 >nul
exit /b 0
