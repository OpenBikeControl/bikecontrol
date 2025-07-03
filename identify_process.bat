@echo off
echo SwiftControl Window Targeting Helper
echo ===================================
echo.
echo This utility helps identify the correct process names for window targeting.
echo Use this if the automatic targeting isn't working for your training app.
echo.

:menu
echo Options:
echo 1. List all running applications
echo 2. Search for specific application
echo 3. Find windows with specific titles
echo 4. Test window targeting (advanced)
echo 5. Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto list_all
if "%choice%"=="2" goto search_app
if "%choice%"=="3" goto find_windows
if "%choice%"=="4" goto test_targeting
if "%choice%"=="5" goto exit
echo Invalid choice. Please try again.
echo.
goto menu

:list_all
echo.
echo All running applications:
echo ------------------------
tasklist /FO TABLE | findstr /V "System Idle Process"
echo.
echo Look for your training application in the list above.
echo The "Image Name" column shows the process name to use for targeting.
echo.
pause
goto menu

:search_app
echo.
set /p appname="Enter part of the application name to search for: "
echo.
echo Searching for applications containing "%appname%":
echo ----------------------------------------------
tasklist /FI "IMAGENAME eq *%appname%*" 2>NUL
if errorlevel 1 (
    echo No exact matches found. Trying broader search...
    tasklist | findstr /I "%appname%"
    if errorlevel 1 (
        echo No applications found containing "%appname%"
    )
)
echo.
pause
goto menu

:find_windows
echo.
echo This feature requires PowerShell. Checking window titles...
echo.
powershell -Command "Get-Process | Where-Object {$_.MainWindowTitle -ne ''} | Select-Object ProcessName, MainWindowTitle | Format-Table -AutoSize"
echo.
echo The ProcessName column shows what to use for windowsProcessName
echo The MainWindowTitle column shows what to use for windowsWindowTitle
echo.
pause
goto menu

:test_targeting
echo.
echo Advanced Window Targeting Test
echo =============================
echo.
set /p testprocess="Enter process name to test (e.g., MyWhooshHD.exe): "
echo.
echo Testing if process "%testprocess%" is running...
tasklist /FI "IMAGENAME eq %testprocess%" 2>NUL | find /I /N "%testprocess%">NUL
if "%ERRORLEVEL%"=="0" (
    echo ✓ Process found! Window targeting should work for this process.
    echo.
    echo Process details:
    tasklist /FI "IMAGENAME eq %testprocess%" /FO LIST
) else (
    echo ✗ Process not found. Make sure the application is running.
    echo   Try option 1 to see all running processes.
)
echo.
pause
goto menu

:exit
echo.
echo Common Training Application Process Names:
echo ========================================
echo MyWhoosh: MyWhooshHD.exe
echo IndieVelo/TrainingPeaks: indieVelo.exe  
echo Biketerra: biketerra.exe
echo Zwift: ZwiftApp.exe
echo.
echo How to use this information:
echo 1. Find your application's process name using this tool
echo 2. If it differs from the defaults, please report it to the SwiftControl developers
echo 3. The targeting feature will automatically use the correct process name
echo.
echo Thank you for using SwiftControl!
pause