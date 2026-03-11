@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1
cd /d c:\Codename_EpicFury\gslib2_opt\dual3d
echo Compiling dual.f...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:"c:\Codename_EpicFury\gslib2_opt\bin_opt\dual3d.exe" dual.f "c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib" 2>&1
if exist "c:\Codename_EpicFury\gslib2_opt\bin_opt\dual3d.exe" (echo OK: dual3d.exe) else (echo FAIL: dual3d.exe)
