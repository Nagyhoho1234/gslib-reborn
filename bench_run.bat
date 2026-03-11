@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1
set OMP_STACKSIZE=128M
set OMP_NUM_THREADS=%1
if "%1"=="" set OMP_NUM_THREADS=16

set BIN=c:\Codename_EpicFury\gslib2_opt\bin_opt
set WORK=%2
if "%2"=="" set WORK=c:\Codename_EpicFury\gslib2_opt\bench_work

cd /d "%WORK%"

echo ============================================================
echo  SGSIM_FC: 160 realizations, 127x216 grid, %OMP_NUM_THREADS% threads
echo  Working dir: %WORK%
echo ============================================================

echo.
echo --- SGSIM_FC ---
echo %time%
%BIN%\sgsim_fc.exe < nul
echo %time%

echo.
echo --- POSTSIM ---
echo %time%
%BIN%\postsim.exe < nul
echo %time%

echo.
echo --- BACKTR ---
echo %time%
%BIN%\backtr.exe < nul
echo %time%

echo.
echo Done. Output files:
if exist sgsim.out (for %%f in (sgsim.out) do echo   sgsim.out: %%~zf bytes) else (echo   sgsim.out: MISSING)
if exist postsim.out (for %%f in (postsim.out) do echo   postsim.out: %%~zf bytes) else (echo   postsim.out: MISSING)
if exist backtr.out (for %%f in (backtr.out) do echo   backtr.out: %%~zf bytes) else (echo   backtr.out: MISSING)
