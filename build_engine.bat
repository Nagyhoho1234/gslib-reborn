@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1
set ROOT=c:\Codename_EpicFury\gslib2_opt
cd /d "%ROOT%\unified"
echo Building unified GSLIB engine...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:"%ROOT%\bin_opt\gslib_engine.exe" gslib_engine.f90 "%ROOT%\gslib\libgs.lib" 2>&1
if exist "%ROOT%\bin_opt\gslib_engine.exe" (echo OK: gslib_engine.exe) else (echo FAIL)
