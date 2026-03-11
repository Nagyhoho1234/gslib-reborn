@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64 >/dev/null 2>&1
where ifx 2>&1
echo ERRORLEVEL=%ERRORLEVEL%
