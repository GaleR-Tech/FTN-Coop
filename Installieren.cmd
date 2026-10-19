@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Setup.ps1" -Action Install -Language de
if errorlevel 1 (echo Installation fehlgeschlagen.) else (echo Fertig. Demo ueber Steam starten. Koop-Menue: F2.)
pause
