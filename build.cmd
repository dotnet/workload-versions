@echo off
if "%1"=="" (
    echo Error: sourceBranch argument is required
    echo Usage: build.cmd ^<sourceBranch^> [additional arguments...]
    exit /b 1
)
set SOURCE_BRANCH=%1
rem Keep the arguments, excluding the first (SOURCE_BRANCH)
set "REMAINING_ARGS="
for /f "tokens=1* delims= " %%a in ("%*") do set "REMAINING_ARGS=%%b"
for /f %%i in ('git config --get remote.origin.url') do set REPO_URL=%%i
git clone -b %SOURCE_BRANCH% %REPO_URL% source-branch
robocopy "source-branch" "." /E /XO /XD ".git" ".config" /XF ".gitignore" "build.cmd" "public.yml" /NJH /NJS /NP /NFL /NDL
rmdir /s /q "source-branch"
powershell -NoLogo -NoProfile -ExecutionPolicy ByPass -Command "& """%~dp0eng\common\build.ps1""" -restore -build -msbuildEngine vs %REMAINING_ARGS%"
exit /b %ErrorLevel%
