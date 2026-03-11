@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >/dev/null 2>&1

set ROOT=c:\Codename_EpicFury\gslib2_opt
set FC=ifx
set FFLAGS=/O2 /Qopenmp /heap-arrays0 /libs:static
set BINDIR=%ROOT%\smoke_test
set LIBDIR=%ROOT%\gslib

echo Rebuilding with static linking and /heap-arrays0...

cd /d "%ROOT%\nscore"
%FC% %FFLAGS% /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBDIR%\libgs.lib" >/dev/null 2>&1
if errorlevel 1 (echo FAIL nscore) else (echo OK nscore)

cd /d "%ROOT%\backtr"
%FC% %FFLAGS% /Fe:"%BINDIR%\backtr.exe" backtr.f "%LIBDIR%\libgs.lib" >/dev/null 2>&1
if errorlevel 1 (echo FAIL backtr) else (echo OK backtr)

cd /d "%ROOT%\postsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\postsim.exe" postsim.f "%LIBDIR%\libgs.lib" >/dev/null 2>&1
if errorlevel 1 (echo FAIL postsim) else (echo OK postsim)

cd /d "%ROOT%\pfsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\pfsim.exe" pfsim.f "%LIBDIR%\libgs.lib" >/dev/null 2>&1
if errorlevel 1 (echo FAIL pfsim) else (echo OK pfsim)

cd /d "%ROOT%\bicalib"
%FC% %FFLAGS% /Fe:"%BINDIR%\bicalib.exe" bicalib.f "%LIBDIR%\libgs.lib" >/dev/null 2>&1
if errorlevel 1 (echo FAIL bicalib) else (echo OK bicalib)

echo Done.
