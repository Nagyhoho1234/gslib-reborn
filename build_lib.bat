@echo off
call "C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\env\vars.bat" >NUL 2>&1
cd /d "c:\Codename_EpicFury\gslib2_opt\gslib"
del /q *.obj libgs.lib 2>NUL
echo Building shared library...
set ERRCNT=0
for %%f in (acorni.f backtr.f beyond.f blue.f chknam.f chktitle.f cova3.f dlocate.f dpowint.f dsortem.f gauinv.f gcum.f getindx.f getz.f green.f hexa.f ksol.f ktsol.f locate.f nscore.f numtext.f ordrel.f picksupr.f powint.f psfill.f psline.f pstext.f rand.f red.f resc.f scal.f setrot.f setsupr.f sortem.f sqdist.f srchsupr.f strlen.f srchsuprsisim.f) do (
    ifx /c /O2 /Qopenmp /heap-arrays0 %%f >NUL 2>&1
    if errorlevel 1 (
        echo ERROR: %%f
        set /a ERRCNT+=1
    ) else (
        echo   OK: %%f
    )
)
lib /OUT:libgs.lib *.obj >NUL 2>&1
if exist libgs.lib (echo LIBRARY OK) else (echo LIBRARY FAILED)
