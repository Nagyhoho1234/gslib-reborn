@echo off
call "C:\Program Files (x86)\Intel\oneAPI\setvars.bat" intel64 >/dev/null 2>&1
where ifx
echo ----
set ROOT=c:\Codename_EpicFury\gslib2_opt
set FC=ifx
set FFLAGS=/O2 /heap-arrays0
set BINDIR=%ROOT%\smoke_test
set LIBDIR=%ROOT%\gslib

cd /d "%ROOT%\nscore"
%FC% %FFLAGS% /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBDIR%\libgs.lib" 2>&1
if errorlevel 1 (echo FAIL nscore) else (echo OK nscore)
