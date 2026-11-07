@echo off
chcp 65001 >nul
title BEnotiz - Upload zu GitHub
echo ========================================================
echo   BEnotiz App - Automatischer Upload zu GitHub
echo ========================================================
echo.
echo Verbinde mit GitHub und uebertrage Code...
echo.
set "PATH=C:\Users\gohla\dev\git\cmd;C:\Users\gohla\dev\flutter\bin;%PATH%"
cd /d "C:\Users\gohla\Documents\Antygravity"
git push -u origin main
echo.
echo ========================================================
if %ERRORLEVEL% EQU 0 (
    echo   ERFOLGREICH! Ihre App wurde zu GitHub uebertragen.
) else (
    echo   Hinweis: Falls Sie noch nicht angemeldet waren,
    echo   wurde gerade ein Browserfenster zur Anmeldung geoeffnet.
)
echo ========================================================
echo.
pause
