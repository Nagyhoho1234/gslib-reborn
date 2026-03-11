@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64
cd /d c:\Codename_EpicFury\gslib2_opt\sgsim_fc
echo Building sgsim_fc...
where ifx
ifx /O2 /Qopenmp /heap-arrays0 /F17179869184 sgsim_fc.f ..\gslib\libgs.lib /Fe:..\bin_opt\sgsim_fc.exe
if errorlevel 1 (
    echo BUILD FAILED
) else (
    echo BUILD OK
    dir ..\bin_opt\sgsim_fc.exe
)
