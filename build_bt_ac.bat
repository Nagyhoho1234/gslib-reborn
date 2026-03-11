@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64
set "LIB=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\lib;%LIB%"

cd /d c:\Codename_EpicFury\gslib2_opt\backtr
echo Building backtr...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:c:\Codename_EpicFury\gslib2_opt\bin_opt\backtr.exe backtr.f c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib
if errorlevel 1 (echo BACKTR FAILED) else (echo BACKTR OK)

echo Building backtr2...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:c:\Codename_EpicFury\gslib2_opt\bin_opt\backtr2.exe backtr2.f c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib
if errorlevel 1 (echo BACKTR2 FAILED) else (echo BACKTR2 OK)

cd /d c:\Codename_EpicFury\gslib2_opt\addcoord
echo Building addcoord...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:c:\Codename_EpicFury\gslib2_opt\bin_opt\addcoord.exe addcoord.f c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib
if errorlevel 1 (echo ADDCOORD FAILED) else (echo ADDCOORD OK)

echo Building addcoord2...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:c:\Codename_EpicFury\gslib2_opt\bin_opt\addcoord2.exe addcoord2.f c:\Codename_EpicFury\gslib2_opt\gslib\libgs.lib
if errorlevel 1 (echo ADDCOORD2 FAILED) else (echo ADDCOORD2 OK)
