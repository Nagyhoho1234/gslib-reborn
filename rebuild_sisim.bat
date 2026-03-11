@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64
set "LIB=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\lib;%LIB%"
set FC=ifx
set FFLAGS=/O2 /Qopenmp /heap-arrays0 /F17179869184
set BIN=c:\Codename_EpicFury\gslib2_opt\bin_opt
set GSLIB=c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib

echo === Building sisim ===
cd /d c:\Codename_EpicFury\gslib2_opt\sisim
%FC% %FFLAGS% sisim.f %GSLIB% /Fe:%BIN%\sisim.exe
if errorlevel 1 (echo SISIM FAILED) else (echo SISIM OK)

echo === Building sisim_gs ===
cd /d c:\Codename_EpicFury\gslib2_opt\sisim_gs
%FC% %FFLAGS% sisim_gs.f %GSLIB% /Fe:%BIN%\sisim_gs.exe
if errorlevel 1 (echo SISIM_GS FAILED) else (echo SISIM_GS OK)

echo === Building sisim_lm ===
cd /d c:\Codename_EpicFury\gslib2_opt\sisim_lm
%FC% %FFLAGS% sisim_lm.f %GSLIB% /Fe:%BIN%\sisim_lm.exe
if errorlevel 1 (echo SISIM_LM FAILED) else (echo SISIM_LM OK)
