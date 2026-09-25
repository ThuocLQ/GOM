@echo off
setlocal
set "SCRIPT=%~dp0DeliveryCopy.ps1"
set "LOG=%~dp0DeliveryCopy_startup_error.log"

if not exist "%SCRIPT%" (
  echo DeliveryCopy.ps1 was not found.
  echo Extract the ZIP first, then run this CMD file from the extracted folder.
  pause
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" 1>"%LOG%" 2>&1
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo.
  echo Delivery Copy could not start. Details are in:
  echo %LOG%
  echo.
  type "%LOG%"
  pause
  exit /b %EXITCODE%
)

if exist "%LOG%" del "%LOG%" >nul 2>&1
exit /b 0
