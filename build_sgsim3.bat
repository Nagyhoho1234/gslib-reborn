@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64
set "LIB=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\lib;%LIB%"
cd /d c:\Codename_EpicFury\gslib2_opt\sgsim
del c:\Codename_EpicFury\gslib2_opt\bin_opt\sgsim.exe 2>/dev/null
echo Building sgsim...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:c:\Codename_EpicFury\gslib2_opt\bin_opt\sgsim.exe sgsim.f c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib
if errorlevel 1 (echo SGSIM FAILED) else (echo SGSIM OK)
