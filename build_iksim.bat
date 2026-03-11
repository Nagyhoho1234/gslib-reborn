@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1
set ROOT=c:\Codename_EpicFury\gslib2_opt
set BINDIR=%ROOT%\bin_opt
cd /d "%ROOT%\iksim"
echo Building iksim (multi-source)...
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 /Fe:"%BINDIR%\iksim.exe" iksim.f trans.f postik.f pfsimfft.f "%ROOT%\gslib\libgs.lib" 2>&1
if exist "%BINDIR%\iksim.exe" (echo OK: iksim.exe) else (echo FAIL: iksim)
