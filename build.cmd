@echo off
for /f %%i in ('git config --get remote.origin.url') do set REPO_URL=%%i
git clone -b eng %REPO_URL% eng-branch
robocopy "eng-branch" "." /E /XD ".git" ".config" /XF ".gitignore"
rmdir /s /q "eng-branch"
powershell -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "& """%~dp0eng\common\build.ps1""" -restore -build -msbuildEngine vs %*"
exit /b %ErrorLevel%
