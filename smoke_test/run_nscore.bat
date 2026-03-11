@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64 vs2022 >/dev/null 2>&1
cd /d c:\Codename_EpicFury\gslib2_opt\smoke_test
echo nscore.par | nscore.exe
echo EXITCODE=%ERRORLEVEL%
