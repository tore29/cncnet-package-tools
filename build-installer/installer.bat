@echo off
rem Manual installer build from the tools repo. Pass the CLI args through, e.g.:
rem   installer.bat --game yr
rem   installer.bat --game ts --workingDir C:\path\to\ts-package

cd ../
cmd /c npm ci
cmd /c npm run build-installer -- %*

pause
