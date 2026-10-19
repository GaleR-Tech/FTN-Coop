@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Setup.ps1" -Action Remove
if errorlevel 1 (echo Entfernen fehlgeschlagen.) else (echo FTN-Koop entfernt.)
pause
