@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Setup.ps1" -Action Remove -Language en
if errorlevel 1 (echo Removal failed.) else (echo Done.)
pause
