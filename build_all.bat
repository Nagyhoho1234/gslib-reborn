@echo off
REM ============================================================
REM  GSLIB2-OPT Master Build Script (Intel oneAPI ifx)
REM  Output: bin_opt/ (self-contained: libiomp5md.dll copied alongside)
REM
REM  NOTE: /Qopenmp-link:static below is now a silently-ignored remark
REM  on this Intel oneAPI version (2025.3) -- Intel no longer ships a
REM  static OpenMP runtime archive at all (only libiomp5md.dll +
REM  libiomp5md.lib exist under compiler/2025.3/lib), so true static
REM  OpenMP linking is not achievable with this toolchain regardless of
REM  flag spelling. Programs that pull in gslib/cova3.f's OpenMP code
REM  (most kriging/simulation programs) now link dynamically against
REM  libiomp5md.dll even though this script's flags still request
REM  static -- the DLL copy step at the end of this script is what
REM  actually makes bin_opt/ runnable standalone, not the flag.
REM ============================================================
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" intel64
set "LIB=C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\lib;%LIB%"

set ROOT=c:\Codename_EpicFury\gslib2_opt
set FC=ifx
set FFLAGS=/O2 /Qopenmp-link:static /heap-arrays0 /F17179869184
set FFLAGS_LIB=/c /O2 /Qopenmp-link:static /heap-arrays0
set BINDIR=%ROOT%\bin_opt
set LIBDIR=%ROOT%\gslib

if not exist "%BINDIR%" mkdir "%BINDIR%"

echo ============================================================
echo  Step 1: Building shared library (gslib/libgs.lib)
echo ============================================================
cd /d "%LIBDIR%"
for %%f in (acorni.f backtr.f beyond.f blue.f chknam.f chktitle.f cova3.f dlocate.f dpowint.f dsortem.f gauinv.f gcum.f getindx.f getz.f green.f hexa.f ksol.f ktsol.f locate.f nscore.f numtext.f ordrel.f picksupr.f powint.f psfill.f psline.f pstext.f rand.f red.f resc.f scal.f setrot.f setsupr.f sortem.f sqdist.f srchsupr.f strlen.f srchsuprsisim.f) do (
    %FC% %FFLAGS_LIB% %%f >NUL 2>&1
    if errorlevel 1 (echo   ERROR compiling %%f)
)
lib /OUT:libgs.lib *.obj >NUL 2>&1
echo   Library: libgs.lib created
echo.

echo ============================================================
echo  Step 2: Building all programs
echo ============================================================
set /a OK=0
set /a FAIL=0

cd /d "%ROOT%\kt3d"
%FC% %FFLAGS% /Fe:"%BINDIR%\kt3d.exe" kt3d.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: kt3d & set /a FAIL+=1) else (echo   OK: kt3d & set /a OK+=1)

cd /d "%ROOT%\kb2d"
%FC% %FFLAGS% /Fe:"%BINDIR%\kb2d.exe" kb2d.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: kb2d & set /a FAIL+=1) else (echo   OK: kb2d & set /a OK+=1)

cd /d "%ROOT%\ik3d"
%FC% %FFLAGS% /Fe:"%BINDIR%\ik3d.exe" ik3d.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: ik3d & set /a FAIL+=1) else (echo   OK: ik3d & set /a OK+=1)

cd /d "%ROOT%\dual3d"
%FC% %FFLAGS% /Fe:"%BINDIR%\dual3d.exe" dual.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: dual3d & set /a FAIL+=1) else (echo   OK: dual3d & set /a OK+=1)

cd /d "%ROOT%\cokb3d"
%FC% %FFLAGS% /Fe:"%BINDIR%\cokb3d.exe" newcokb3d.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: cokb3d & set /a FAIL+=1) else (echo   OK: cokb3d & set /a OK+=1)

cd /d "%ROOT%\newcokb3d"
%FC% %FFLAGS% /Fe:"%BINDIR%\newcokb3d.exe" newcokb3d.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: newcokb3d & set /a FAIL+=1) else (echo   OK: newcokb3d & set /a OK+=1)

cd /d "%ROOT%\sgsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\sgsim.exe" sgsim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: sgsim & set /a FAIL+=1) else (echo   OK: sgsim & set /a OK+=1)

cd /d "%ROOT%\sgsim_fc"
%FC% %FFLAGS% /Fe:"%BINDIR%\sgsim_fc.exe" sgsim_fc.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: sgsim_fc & set /a FAIL+=1) else (echo   OK: sgsim_fc & set /a OK+=1)

cd /d "%ROOT%\sisim"
%FC% %FFLAGS% /Fe:"%BINDIR%\sisim.exe" sisim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: sisim & set /a FAIL+=1) else (echo   OK: sisim & set /a OK+=1)

cd /d "%ROOT%\sisim_gs"
%FC% %FFLAGS% /Fe:"%BINDIR%\sisim_gs.exe" sisim_gs.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: sisim_gs & set /a FAIL+=1) else (echo   OK: sisim_gs & set /a OK+=1)

cd /d "%ROOT%\sisim_lm"
%FC% %FFLAGS% /Fe:"%BINDIR%\sisim_lm.exe" sisim_lm.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: sisim_lm & set /a FAIL+=1) else (echo   OK: sisim_lm & set /a OK+=1)

cd /d "%ROOT%\dssim"
%FC% %FFLAGS% /Fe:"%BINDIR%\dssim.exe" dssim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: dssim & set /a FAIL+=1) else (echo   OK: dssim & set /a OK+=1)

cd /d "%ROOT%\lusim"
%FC% %FFLAGS% /Fe:"%BINDIR%\lusim.exe" lusim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: lusim & set /a FAIL+=1) else (echo   OK: lusim & set /a OK+=1)

cd /d "%ROOT%\gtsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\gtsim.exe" gtsim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: gtsim & set /a FAIL+=1) else (echo   OK: gtsim & set /a OK+=1)

cd /d "%ROOT%\pfsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\pfsim.exe" pfsim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: pfsim & set /a FAIL+=1) else (echo   OK: pfsim & set /a OK+=1)

cd /d "%ROOT%\sasim"
%FC% %FFLAGS% /Fe:"%BINDIR%\sasim.exe" sasim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: sasim & set /a FAIL+=1) else (echo   OK: sasim & set /a OK+=1)

cd /d "%ROOT%\ellipsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\ellipsim.exe" ellipsim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: ellipsim & set /a FAIL+=1) else (echo   OK: ellipsim & set /a OK+=1)

cd /d "%ROOT%\fluvsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\fluvsim.exe" fluvsim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: fluvsim & set /a FAIL+=1) else (echo   OK: fluvsim & set /a OK+=1)

cd /d "%ROOT%\iksim"
%FC% /c %FFLAGS_LIB% iksim_mod.f90 >NUL 2>&1
%FC% %FFLAGS% /Fe:"%BINDIR%\iksim.exe" iksim.f trans.f postik.f pfsimfft.f iksim_mod.obj "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: iksim & set /a FAIL+=1) else (echo   OK: iksim & set /a OK+=1)

cd /d "%ROOT%\anneal"
%FC% /c %FFLAGS_LIB% anneal_mod.f90 >NUL 2>&1
%FC% %FFLAGS% /Fe:"%BINDIR%\anneal.exe" anneal.f anneal_mod.obj "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: anneal & set /a FAIL+=1) else (echo   OK: anneal & set /a OK+=1)

cd /d "%ROOT%\backtr"
%FC% %FFLAGS% /Fe:"%BINDIR%\backtr.exe" backtr.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: backtr & set /a FAIL+=1) else (echo   OK: backtr & set /a OK+=1)

cd /d "%ROOT%\backtr"
%FC% %FFLAGS% /Fe:"%BINDIR%\backtr2.exe" backtr2.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: backtr2 & set /a FAIL+=1) else (echo   OK: backtr2 & set /a OK+=1)

cd /d "%ROOT%\nscore"
%FC% %FFLAGS% /Fe:"%BINDIR%\nscore.exe" nscore.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: nscore & set /a FAIL+=1) else (echo   OK: nscore & set /a OK+=1)

cd /d "%ROOT%\trans"
%FC% %FFLAGS% /Fe:"%BINDIR%\trans.exe" trans.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: trans & set /a FAIL+=1) else (echo   OK: trans & set /a OK+=1)

cd /d "%ROOT%\histsmth"
%FC% %FFLAGS% /Fe:"%BINDIR%\histsmth.exe" histsmth.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: histsmth & set /a FAIL+=1) else (echo   OK: histsmth & set /a OK+=1)

cd /d "%ROOT%\bicalib"
%FC% %FFLAGS% /Fe:"%BINDIR%\bicalib.exe" bicalib.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: bicalib & set /a FAIL+=1) else (echo   OK: bicalib & set /a OK+=1)

cd /d "%ROOT%\bigaus"
%FC% %FFLAGS% /Fe:"%BINDIR%\bigaus.exe" bigaus.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: bigaus & set /a FAIL+=1) else (echo   OK: bigaus & set /a OK+=1)

cd /d "%ROOT%\gamv"
%FC% %FFLAGS% /Fe:"%BINDIR%\gamv.exe" gamv.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: gamv & set /a FAIL+=1) else (echo   OK: gamv & set /a OK+=1)

cd /d "%ROOT%\gam"
%FC% %FFLAGS% /Fe:"%BINDIR%\gam.exe" gam.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: gam & set /a FAIL+=1) else (echo   OK: gam & set /a OK+=1)

cd /d "%ROOT%\varmap"
%FC% %FFLAGS% /Fe:"%BINDIR%\varmap.exe" varmap.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: varmap & set /a FAIL+=1) else (echo   OK: varmap & set /a OK+=1)

cd /d "%ROOT%\newvarmap"
%FC% %FFLAGS% /Fe:"%BINDIR%\newvarmap.exe" newvarmap.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: newvarmap & set /a FAIL+=1) else (echo   OK: newvarmap & set /a OK+=1)

cd /d "%ROOT%\vmodel"
%FC% %FFLAGS% /Fe:"%BINDIR%\vmodel.exe" vmodel.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: vmodel & set /a FAIL+=1) else (echo   OK: vmodel & set /a OK+=1)

cd /d "%ROOT%\declus"
%FC% %FFLAGS% /Fe:"%BINDIR%\declus.exe" declus.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: declus & set /a FAIL+=1) else (echo   OK: declus & set /a OK+=1)

cd /d "%ROOT%\postik"
%FC% %FFLAGS% /Fe:"%BINDIR%\postik.exe" postik.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: postik & set /a FAIL+=1) else (echo   OK: postik & set /a OK+=1)

cd /d "%ROOT%\postsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\postsim.exe" postsim.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: postsim & set /a FAIL+=1) else (echo   OK: postsim & set /a OK+=1)

cd /d "%ROOT%\postsim"
%FC% %FFLAGS% /Fe:"%BINDIR%\postsim2.exe" postsim2.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: postsim2 & set /a FAIL+=1) else (echo   OK: postsim2 & set /a OK+=1)

cd /d "%ROOT%\addcoord"
%FC% %FFLAGS% /Fe:"%BINDIR%\addcoord.exe" addcoord.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: addcoord & set /a FAIL+=1) else (echo   OK: addcoord & set /a OK+=1)

cd /d "%ROOT%\addcoord"
%FC% %FFLAGS% /Fe:"%BINDIR%\addcoord2.exe" addcoord2.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: addcoord2 & set /a FAIL+=1) else (echo   OK: addcoord2 & set /a OK+=1)

cd /d "%ROOT%\rotcoord"
%FC% %FFLAGS% /Fe:"%BINDIR%\rotcoord.exe" rotcoord.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: rotcoord & set /a FAIL+=1) else (echo   OK: rotcoord & set /a OK+=1)

cd /d "%ROOT%\scatsmth"
%FC% %FFLAGS% /Fe:"%BINDIR%\scatsmth.exe" scatsmth.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: scatsmth & set /a FAIL+=1) else (echo   OK: scatsmth & set /a OK+=1)

cd /d "%ROOT%\draw"
%FC% %FFLAGS% /Fe:"%BINDIR%\draw.exe" draw.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: draw & set /a FAIL+=1) else (echo   OK: draw & set /a OK+=1)

cd /d "%ROOT%\histplt"
%FC% %FFLAGS% /Fe:"%BINDIR%\histplt.exe" histplt.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: histplt & set /a FAIL+=1) else (echo   OK: histplt & set /a OK+=1)

cd /d "%ROOT%\probplt"
%FC% %FFLAGS% /Fe:"%BINDIR%\probplt.exe" probplt.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: probplt & set /a FAIL+=1) else (echo   OK: probplt & set /a OK+=1)

cd /d "%ROOT%\qpplt"
%FC% %FFLAGS% /Fe:"%BINDIR%\qpplt.exe" qpplt.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: qpplt & set /a FAIL+=1) else (echo   OK: qpplt & set /a OK+=1)

cd /d "%ROOT%\scatplt"
%FC% %FFLAGS% /Fe:"%BINDIR%\scatplt.exe" scatplt.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: scatplt & set /a FAIL+=1) else (echo   OK: scatplt & set /a OK+=1)

cd /d "%ROOT%\locmap"
%FC% %FFLAGS% /Fe:"%BINDIR%\locmap.exe" locmap.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: locmap & set /a FAIL+=1) else (echo   OK: locmap & set /a OK+=1)

cd /d "%ROOT%\pixelplt"
%FC% %FFLAGS% /Fe:"%BINDIR%\pixelplt.exe" pixelplt.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: pixelplt & set /a FAIL+=1) else (echo   OK: pixelplt & set /a OK+=1)

cd /d "%ROOT%\vargplt"
%FC% %FFLAGS% /Fe:"%BINDIR%\vargplt.exe" vargplt.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: vargplt & set /a FAIL+=1) else (echo   OK: vargplt & set /a OK+=1)

cd /d "%ROOT%\bivplt"
%FC% %FFLAGS% /Fe:"%BINDIR%\bivplt.exe" bivplt.f "%LIBDIR%\libgs.lib" >NUL 2>&1
if errorlevel 1 (echo   FAIL: bivplt & set /a FAIL+=1) else (echo   OK: bivplt & set /a OK+=1)

echo.
echo ============================================================
echo  Build complete. OK: %OK%, FAILED: %FAIL%
echo  Binaries in: %BINDIR%
echo ============================================================
REM Copy OpenMP runtime DLL -- required at runtime for any program that
REM pulls in gslib/cova3.f's OpenMP code (see the note at the top of this
REM script: this Intel oneAPI version has no static OpenMP archive, so
REM /Qopenmp-link:static above no longer has any effect).
copy /Y "%ROOT%\smoke_test\libiomp5md.dll" "%BINDIR%\" >NUL 2>&1
if not exist "%BINDIR%\libiomp5md.dll" (
    echo  WARNING: libiomp5md.dll not found, copy it manually!
) else (
    echo  Copied libiomp5md.dll to %BINDIR%
)
