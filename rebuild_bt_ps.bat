@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64
set "LIB=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\lib;%LIB%"
set FC=ifx
set FFLAGS=/O2 /Qopenmp /heap-arrays0 /F17179869184
set BIN=c:\Codename_EpicFury\gslib2_opt\bin_opt
set GSLIB=c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib

echo === Building backtr ===
cd /d c:\Codename_EpicFury\gslib2_opt\backtr
%FC% %FFLAGS% backtr.f %GSLIB% /Fe:%BIN%\backtr.exe
if errorlevel 1 (echo BACKTR FAILED) else (echo BACKTR OK)

echo === Building postsim ===
cd /d c:\Codename_EpicFury\gslib2_opt\postsim
%FC% %FFLAGS% postsim.f %GSLIB% /Fe:%BIN%\postsim.exe
if errorlevel 1 (echo POSTSIM FAILED) else (echo POSTSIM OK)
