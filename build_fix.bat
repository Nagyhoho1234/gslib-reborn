@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64
set "LIB=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\lib;%LIB%"
set ROOT=c:\Codename_EpicFury\gslib2_opt
set FC=ifx
set FFLAGS=/O2 /Qopenmp-link:static /heap-arrays0 /F17179869184
set BINDIR=%ROOT%\bin_opt
set LIBDIR=%ROOT%\gslib

cd /d %ROOT%\sgsim
echo Building sgsim...
%FC% %FFLAGS% /Fe:%BINDIR%\sgsim.exe sgsim.f %LIBDIR%\libgs.lib
if errorlevel 1 (echo SGSIM FAILED) else (echo SGSIM OK)

cd /d %ROOT%\kb2d
echo Building kb2d...
%FC% %FFLAGS% /Fe:%BINDIR%\kb2d.exe kb2d.f %LIBDIR%\libgs.lib
if errorlevel 1 (echo KB2D FAILED) else (echo KB2D OK)

cd /d %ROOT%\nscore
echo Building nscore...
%FC% %FFLAGS% /Fe:%BINDIR%\nscore.exe nscore.f %LIBDIR%\libgs.lib
if errorlevel 1 (echo NSCORE FAILED) else (echo NSCORE OK)
