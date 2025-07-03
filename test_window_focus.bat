@echo off
echo Testing Window-Focused Key Simulation Feature
echo =============================================
echo.

echo This script helps test the window-focused key simulation feature.
echo.

echo Step 1: Launch MyWhooshHD
echo -----------------------
echo Please start MyWhooshHD application if it's not already running.
echo Once started, press any key to continue...
pause >nul

echo.
echo Step 2: Launch SwiftControl
echo --------------------------
echo Start SwiftControl and:
echo 1. Connect your Zwift device
echo 2. Select "MyWhoosh" as your target application
echo 3. Make sure key mapping is configured (default: I/K for shifting)
echo.
echo Press any key when SwiftControl is ready...
pause >nul

echo.
echo Step 3: Focus Test
echo -----------------
echo Now we'll test the window focus feature:
echo.
echo 1. This command window should be in focus (active)
echo 2. MyWhooshHD should be running in the background
echo 3. Try using your Zwift device to send key presses
echo 4. The key presses should reach MyWhooshHD even though this window has focus
echo.
echo Expected behavior:
echo - Gear shifts in MyWhooshHD should work
echo - This command window should remain focused
echo - You should see responses in MyWhooshHD without clicking on it
echo.
echo Press any key after testing...
pause >nul

echo.
echo Step 4: Verify Process Detection
echo -------------------------------
echo Checking if MyWhooshHD.exe is running...

tasklist /FI "IMAGENAME eq MyWhooshHD.exe" 2>NUL | find /I /N "MyWhooshHD.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo ✓ MyWhooshHD.exe process found
    echo.
    echo Process details:
    tasklist /FI "IMAGENAME eq MyWhooshHD.exe" /FO LIST
) else (
    echo ✗ MyWhooshHD.exe process not found
    echo   Make sure MyWhooshHD is running for the feature to work
)

echo.
echo Step 5: Test Results
echo -------------------
echo Please report your test results:
echo.
echo 1. Did key presses reach MyWhooshHD while this window was focused? (Y/N)
set /p result1="Enter Y or N: "

echo 2. Did gear shifts work in MyWhooshHD? (Y/N)
set /p result2="Enter Y or N: "

echo 3. Did you need to click on MyWhooshHD window for keys to work? (Y/N)
set /p result3="Enter Y or N: "

echo.
echo Test Summary:
echo - Key presses reached MyWhooshHD: %result1%
echo - Gear shifts worked: %result2%
echo - Manual focus required: %result3%
echo.

if /I "%result1%"=="Y" if /I "%result2%"=="Y" if /I "%result3%"=="N" (
    echo ✓ SUCCESS: Window-focused key simulation is working correctly!
) else (
    echo ✗ ISSUE: Window-focused key simulation may not be working as expected.
    echo   Please check the troubleshooting section in WINDOW_FOCUS_FEATURE.md
)

echo.
echo Additional Testing:
echo - Try opening a web browser and keeping it focused while using Zwift controls
echo - Test with different supported applications (IndieVelo, Biketerra)
echo - Verify fallback behavior when target app is not running
echo.
echo Press any key to exit...
pause >nul