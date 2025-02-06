@echo off
:: Elevate privileges if not running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c %~dpnx0' -Verb RunAs"
    exit
)

:: Run PowerShell script with Bypass policy
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\Your\Script.ps1"
