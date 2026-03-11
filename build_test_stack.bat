@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1
set ROOT=c:\Codename_EpicFury\gslib2_opt
set BINDIR=%ROOT%\bin_opt
set LIBFILE=%ROOT%\gslib\libgs.lib

echo Test 1: nscore with /link /STACK:4294967296 (4GB)
cd /d "%ROOT%\nscore"
ifx /O2 /Qopenmp /heap-arrays0 /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBFILE%" /link /STACK:4294967296 2>&1
if exist "%BINDIR%\nscore.exe" (echo OK: nscore.exe) else (echo FAIL)
