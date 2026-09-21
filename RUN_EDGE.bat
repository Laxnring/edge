@echo off
setlocal
title OpenStrap Edge - Windows preview
cd /d "%~dp0"

echo.
echo   OpenStrap Edge is starting in Chrome...
echo   The first launch can take a few minutes while Flutter compiles.
echo   Keep this window open while using the app.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-web-preview.ps1"
set "EDGE_EXIT=%ERRORLEVEL%"

echo.
if not "%EDGE_EXIT%"=="0" (
  echo Edge stopped with error code %EDGE_EXIT%.
  echo Copy the text above and send it to Codex so I can fix it.
) else (
  echo Edge closed.
)
echo.
pause
exit /b %EDGE_EXIT%
