@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Setup.ps1" -Action Install -Language en
if errorlevel 1 (echo Installation failed.) else (echo Done. Launch the demo through Steam. Co-op menu: F2.)
pause
