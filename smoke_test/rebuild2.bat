@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >/dev/null 2>&1

set ROOT=c:\Codename_EpicFury\gslib2_opt
set FC=ifx
set FFLAGS=/O2 /heap-arrays0 /static
set BINDIR=%ROOT%\smoke_test
set LIBDIR=%ROOT%\gslib

echo Rebuilding without OpenMP, fully static...

cd /d "%ROOT%\nscore"
%FC% %FFLAGS% /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBDIR%\libgs.lib" 2>&1
if errorlevel 1 (echo FAIL nscore) else (echo OK nscore)

echo Done.
