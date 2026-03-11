@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1
ifx --version
echo COMPILER_OK
