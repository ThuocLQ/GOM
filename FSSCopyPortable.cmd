@echo off
setlocal
set "SCRIPT=%~dp0FSSCopyPortable.ps1"
set "LOG=%~dp0FSSCopyPortable_startup_error.log"

if not exist "%SCRIPT%" (
  echo FSSCopyPortable.ps1 was not found.
  echo Extract the ZIP first, then run this CMD file from the extracted folder.
  pause
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" 1>"%LOG%" 2>&1
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo FSS Copy Portable could not start. Details are in:
  echo %LOG%
  echo.
  type "%LOG%"
  pause
  exit /b %EXITCODE%
)

if exist "%LOG%" del "%LOG%" >nul 2>&1
exit /b 0
