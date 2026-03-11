@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1

set ROOT=c:\Codename_EpicFury\gslib2_opt
set LIBFILE=%ROOT%\gslib\libgs.lib
set BINDIR=%ROOT%\bin_opt
set FFLAGS=/O2 /Qopenmp /heap-arrays0 /F17179869184

if not exist "%BINDIR%" mkdir "%BINDIR%"

echo ============================================================
echo  Building all GSLIB2 programs
echo ============================================================

call :build kt3d kt3d.f kt3d
call :build kb2d kb2d.f kb2d
call :build ik3d ik3d.f ik3d
call :build dual3d dual.f dual3d
call :build cokb3d newcokb3d.f cokb3d
call :build newcokb3d newcokb3d.f newcokb3d
call :build sgsim sgsim.f sgsim
call :build sgsim_fc sgsim_fc.f sgsim_fc
call :build sisim sisim.f sisim
call :build sisim_gs sisim_gs.f sisim_gs
call :build sisim_lm sisim_lm.f sisim_lm
call :build dssim dssim.f dssim
call :build lusim lusim.f lusim
call :build gtsim gtsim.f gtsim
call :build pfsim pfsim.f pfsim
call :build sasim sasim.f sasim
call :build ellipsim ellipsim.f ellipsim
call :build fluvsim fluvsim.f fluvsim
call :build iksim iksim.f iksim
call :build anneal anneal.f anneal
call :build backtr backtr.f backtr
call :build nscore nscore.f nscore
call :build trans trans.f trans
call :build histsmth histsmth.f histsmth
call :build bicalib bicalib.f bicalib
call :build bigaus bigaus.f bigaus
call :build gamv gamv.f gamv
call :build gam gam.f gam
call :build varmap varmap.f varmap
call :build newvarmap newvarmap.f newvarmap
call :build vmodel vmodel.f vmodel
call :build declus declus.f declus
call :build postik postik.f postik
call :build postsim postsim.f postsim
call :build addcoord addcoord.f addcoord
call :build rotcoord rotcoord.f rotcoord
call :build scatsmth scatsmth.f scatsmth
call :build draw draw.f draw

echo.
echo ============================================================
echo  Build complete. Results:
echo ============================================================
set /a COUNT=0
for %%f in ("%BINDIR%\*.exe") do set /a COUNT+=1
echo  %COUNT% programs built in %BINDIR%
dir /b "%BINDIR%\*.exe" 2>NUL
goto :eof

:build
set PROGDIR=%ROOT%\%1
set SRCFILE=%2
set EXENAME=%3
if not exist "%PROGDIR%\%SRCFILE%" (
    echo   SKIP %EXENAME% - %SRCFILE% not found in %1
    goto :eof
)
cd /d "%PROGDIR%"
ifx %FFLAGS% /Fe:"%BINDIR%\%EXENAME%.exe" %SRCFILE% "%LIBFILE%" >NUL 2>&1
if errorlevel 1 (
    echo   FAIL: %EXENAME%
    ifx %FFLAGS% /Fe:"%BINDIR%\%EXENAME%.exe" %SRCFILE% "%LIBFILE%" 2>&1 | findstr /i "error"
) else (
    echo   OK:   %EXENAME%.exe
)
goto :eof
