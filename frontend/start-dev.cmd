@echo off
cd /d "%~dp0"
if not exist "node_modules\vite\bin\vite.js" (
  echo Dependencies are missing. Run pnpm 9 install first.
  pause
  exit /b 1
)
echo Taxhub demo: http://127.0.0.1:5173
node node_modules\vite\bin\vite.js --host 127.0.0.1
