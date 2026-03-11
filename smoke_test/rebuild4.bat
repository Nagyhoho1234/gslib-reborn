@echo off
set IFX="C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\bin\ifx.exe"
set ROOT=c:\Codename_EpicFury\gslib2_opt
set FFLAGS=/O2 /heap-arrays0
set BINDIR=%ROOT%\smoke_test
set LIBDIR=%ROOT%\gslib

REM Set PATH for MSVC linker
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >/dev/null 2>&1

cd /d "%ROOT%\nscore"
%IFX% %FFLAGS% /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBDIR%\libgs.lib" 2>&1
if errorlevel 1 (echo FAIL nscore) else (echo OK nscore)
