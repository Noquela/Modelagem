@echo off
echo ================================================
echo Traffic Simulator 3D - Quick Start
echo ================================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found in PATH
    echo Please install Python 3.8+ and try again
    pause
    exit /b 1
)

echo Python found. Checking dependencies...

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo ================================================
echo Starting Traffic Simulator 3D...
echo ================================================
echo.
echo Controls:
echo   Mouse: Rotate camera
echo   Scroll: Zoom in/out
echo   WASD: Move camera target
echo   SPACE: Pause/Resume
echo   F1: Toggle debug info
echo   ESC: Exit
echo.
echo Starting in 3 seconds...
ping 127.0.0.1 -n 4 >nul 2>&1

REM Run the simulator
cd traffic_simulator
python main.py

REM Pause to show any error messages
if errorlevel 1 (
    echo.
    echo Simulation ended with errors.
    pause
) else (
    echo.
    echo Simulation ended successfully.
)

REM Deactivate virtual environment
deactivate