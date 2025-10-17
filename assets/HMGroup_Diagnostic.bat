@echo off
title HM Group - Diagnostic Mode
color 0A
echo.
echo ==========================================
echo   HM GROUP - DIAGNOSTIC MODE
echo ==========================================
echo.
echo Starting diagnostic checks...
echo Please wait...
echo.

"%~dp0HMGroup.exe" --diagnostic

echo.
echo ==========================================
echo   Diagnostic complete!
echo ==========================================
echo.
pause
