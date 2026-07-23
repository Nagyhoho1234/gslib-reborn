#!/bin/bash
# ============================================================
#  GSLIB2-OPT Master Build Script (Intel oneAPI ifx, Linux)
#  Static OpenMP linking - standalone, no libiomp5.so needed
#  Output: bin_opt_linux/
#
#  Linux counterpart of build_all.bat -- same compiler (ifx),
#  same program table, only the flag spelling and path/output
#  conventions differ between the two platforms. Keep both
#  scripts' program lists in sync when adding a new program.
# ============================================================
source /opt/intel/oneapi/setvars.sh --force > /dev/null 2>&1

ROOT=/mnt/c/Codename_EpicFury/gslib2_opt
FC=ifx
FFLAGS="-O2 -qopenmp-link=static -heap-arrays 0"
FFLAGS_LIB="-c -O2 -qopenmp-link=static -heap-arrays 0"
BINDIR="$ROOT/bin_opt_linux"
LIBDIR="$ROOT/gslib"

mkdir -p "$BINDIR"

echo "============================================================"
echo " Step 1: Building shared library (gslib/libgs.a)"
echo "============================================================"
cd "$LIBDIR"
rm -f *.o libgs.a
for f in acorni.f backtr.f beyond.f blue.f chknam.f chktitle.f cova3.f dlocate.f dpowint.f dsortem.f gauinv.f gcum.f getindx.f getz.f green.f hexa.f ksol.f ktsol.f locate.f nscore.f numtext.f ordrel.f picksupr.f powint.f psfill.f psline.f pstext.f rand.f red.f resc.f scal.f setrot.f setsupr.f sortem.f sqdist.f srchsupr.f strlen.f srchsuprsisim.f; do
    $FC $FFLAGS_LIB "$f" >/dev/null 2>&1
    if [ $? -ne 0 ]; then echo "  ERROR compiling $f"; fi
done
ar rcs libgs.a *.o
echo "  Library: libgs.a created"
echo ""

echo "============================================================"
echo " Step 2: Building all programs"
echo "============================================================"
OK=0
FAIL=0

build_one() {
    local dir="$1" src="$2" out="$3"
    cd "$ROOT/$dir"
    $FC $FFLAGS -o "$BINDIR/$out" $src "$LIBDIR/libgs.a" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "  FAIL: $out"; FAIL=$((FAIL+1))
    else
        echo "  OK: $out"; OK=$((OK+1))
    fi
}

build_one kt3d kt3d.f kt3d
build_one kb2d kb2d.f kb2d
build_one ik3d ik3d.f ik3d
build_one dual3d dual.f dual3d
build_one cokb3d newcokb3d.f cokb3d
build_one newcokb3d newcokb3d.f newcokb3d
build_one sgsim sgsim.f sgsim
build_one sgsim_fc sgsim_fc.f sgsim_fc
build_one sisim sisim.f sisim
build_one sisim_gs sisim_gs.f sisim_gs
build_one sisim_lm sisim_lm.f sisim_lm
build_one dssim dssim.f dssim
build_one lusim lusim.f lusim
build_one gtsim gtsim.f gtsim
build_one pfsim pfsim.f pfsim
build_one sasim sasim.f sasim
build_one ellipsim ellipsim.f ellipsim
build_one fluvsim fluvsim.f fluvsim

# iksim: F90 module compiled first, then the multi-file link
cd "$ROOT/iksim"
$FC $FFLAGS_LIB iksim_mod.f90 >/dev/null 2>&1
$FC $FFLAGS -o "$BINDIR/iksim" iksim.f trans.f postik.f pfsimfft.f iksim_mod.o "$LIBDIR/libgs.a" >/dev/null 2>&1
if [ $? -ne 0 ]; then echo "  FAIL: iksim"; FAIL=$((FAIL+1)); else echo "  OK: iksim"; OK=$((OK+1)); fi

# anneal: F90 module compiled first, then linked
cd "$ROOT/anneal"
$FC $FFLAGS_LIB anneal_mod.f90 >/dev/null 2>&1
$FC $FFLAGS -o "$BINDIR/anneal" anneal.f anneal_mod.o "$LIBDIR/libgs.a" >/dev/null 2>&1
if [ $? -ne 0 ]; then echo "  FAIL: anneal"; FAIL=$((FAIL+1)); else echo "  OK: anneal"; OK=$((OK+1)); fi

build_one backtr backtr.f backtr
build_one backtr backtr2.f backtr2
build_one nscore nscore.f nscore
build_one trans trans.f trans
build_one histsmth histsmth.f histsmth
build_one bicalib bicalib.f bicalib
build_one bigaus bigaus.f bigaus
build_one gamv gamv.f gamv
build_one gam gam.f gam
build_one varmap varmap.f varmap
build_one newvarmap newvarmap.f newvarmap
build_one vmodel vmodel.f vmodel
build_one declus declus.f declus
build_one postik postik.f postik
build_one postsim postsim.f postsim
build_one postsim postsim2.f postsim2
build_one addcoord addcoord.f addcoord
build_one addcoord addcoord2.f addcoord2
build_one rotcoord rotcoord.f rotcoord
build_one scatsmth scatsmth.f scatsmth
build_one draw draw.f draw
build_one histplt histplt.f histplt
build_one probplt probplt.f probplt
build_one qpplt qpplt.f qpplt
build_one scatplt scatplt.f scatplt
build_one locmap locmap.f locmap
build_one pixelplt pixelplt.f pixelplt
build_one vargplt vargplt.f vargplt
build_one bivplt bivplt.f bivplt

echo ""
echo "============================================================"
echo " Build complete. OK: $OK, FAILED: $FAIL"
echo " Binaries in: $BINDIR"
echo "============================================================"
