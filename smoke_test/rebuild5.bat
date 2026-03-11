@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >/dev/null 2>&1
set IFX="C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\bin\ifx.exe"
set ROOT=c:\Codename_EpicFury\gslib2_opt
set BINDIR=%ROOT%\smoke_test
set LIBDIR=%ROOT%\gslib

REM Try different heap-arrays syntax options
cd /d "%ROOT%\nscore"

echo Testing /heap-arrays:0
%IFX% /O2 /heap-arrays:0 /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBDIR%\libgs.lib" 2>&1
if not errorlevel 1 echo SUCCESS
echo.

echo Testing /heap-arrays
%IFX% /O2 /heap-arrays /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBDIR%\libgs.lib" 2>&1
if not errorlevel 1 echo SUCCESS
