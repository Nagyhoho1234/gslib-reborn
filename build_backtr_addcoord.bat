@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64 >/dev/null 2>&1
set "LIB=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\lib;%LIB%"
set ROOT=c:\Codename_EpicFury\gslib2_opt
set FC=ifx
set FFLAGS=/O2 /Qopenmp /heap-arrays0 /F17179869184
set BINDIR=%ROOT%\bin_opt
set LIBDIR=%ROOT%\gslib

echo Building backtr (original format)...
cd /d %ROOT%\backtr
%FC% %FFLAGS% /Fe:%BINDIR%\backtr.exe backtr.f %LIBDIR%\libgs.lib
if errorlevel 1 (echo BACKTR FAILED) else (echo BACKTR OK)

echo Building backtr2 (simplified format)...
%FC% %FFLAGS% /Fe:%BINDIR%\backtr2.exe backtr2.f %LIBDIR%\libgs.lib
if errorlevel 1 (echo BACKTR2 FAILED) else (echo BACKTR2 OK)

echo Building addcoord (original format)...
cd /d %ROOT%\addcoord
%FC% %FFLAGS% /Fe:%BINDIR%\addcoord.exe addcoord.f %LIBDIR%\libgs.lib
if errorlevel 1 (echo ADDCOORD FAILED) else (echo ADDCOORD OK)

echo Building addcoord2 (with column count)...
%FC% %FFLAGS% /Fe:%BINDIR%\addcoord2.exe addcoord2.f %LIBDIR%\libgs.lib
if errorlevel 1 (echo ADDCOORD2 FAILED) else (echo ADDCOORD2 OK)
