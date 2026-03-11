"""
DTK Benchmark: Compare 3 execution modes for SGSIM
===================================================
1. Direct exe (disk I/O, no orchestration)
2. Workflow orchestrator (temp dir, cache-pinned)
3. RAM disk (VHD mount or cache-pinned)

Uses DTK project data: 127x216 grid, 160 realizations, Markov-II cokriging
with felszin auxiliary. Cross-validates against original 100-realization results.
"""

import os
import shutil
import subprocess
import sys
import time
import struct
import numpy as np
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────
BIN = Path(r"c:\Codename_EpicFury\gslib2_opt\bin_opt")
DTK_DIR = Path(r"e:\Backup_O\00000\DTK\2000_ 02_ 01_")
FELSZIN = Path(r"e:\Backup_O\00000\DTK\felszin\PSEtype_SG_NS_HS_ddm.out")
RESULTS_DIR = Path(r"c:\Codename_EpicFury\gslib2_opt\benchmark_results")

# Grid
NX, NY, NZ = 127, 216, 1
NNODES = NX * NY * NZ  # 27432
NREAL = 160

# ── Helpers ───────────────────────────────────────────────────────────

def run_exe(name, parfile, workdir, timeout=7200):
    """Run a GSLIB exe, return (success, elapsed_seconds)."""
    exe = BIN / f"{name}.exe"
    env = os.environ.copy()
    # Add Intel OpenMP runtime to PATH
    intel_bin = r"C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\bin"
    env["PATH"] = intel_bin + ";" + env.get("PATH", "")
    env["OMP_STACKSIZE"] = "128M"
    env["OMP_NUM_THREADS"] = str(os.cpu_count() or 4)
    t0 = time.perf_counter()
    r = subprocess.run(
        [str(exe)], input=str(parfile) + "\n",
        capture_output=True, text=True,
        cwd=str(workdir), env=env, timeout=timeout
    )
    elapsed = time.perf_counter() - t0
    return r.returncode == 0, elapsed, r.stderr


def make_sgsim_par(workdir, nreal=NREAL):
    """Create SGSIM parameter file — exact copy of DTK original, nreal changed."""
    par = workdir / "sgsim.par"
    par.write_text(f"""Parameters for SGSIM
********************

START OF PARAMETERS:
ns_data_tv.dat
2,3,0,5,0,0
-4.85342,3.13756
0
none
0
none
0,0
-5.338762,3.451316
1,-5.338762
1,3.451316
0
sgsim.dbg
sgsim.out
{nreal}
127,620520,1000
216,67275,1000
1,0,1
18034
0,8
12
1
1,3
0
100000,100000,1
0,0,0
5
0.98
1
felszin_secondary.dat
1
2,0.001
1,0.53,273,0,0
32000,9697,1
1,0.46,61,0,0
31360,9224,1
2,0.38
1,0.47,90,0,0
9350,9350,1
1,0.16,90,0,0
32300,32300,1
2,0.1
3,0.581,74.7,0,0
33010,16175,1
3,0.281,54.8,0,0
360844,57735,1
""")
    return par


def make_postsim_par(workdir, nreal=NREAL, infile="sgsim.out",
                      outfile="postsim.out"):
    """Create POSTSIM parameter file — matches DTK original format."""
    par = workdir / "postsim.par"
    par.write_text(f"""Parameters for POSTSIM
***********************

START OF PARAMETERS:
{infile}
{nreal}
-5.338762,3.451316
127,216,1
{outfile}
1,0.25
""")
    return par


def make_backtr_par(workdir, infile="postsim.out", outfile="backtr.out"):
    """Create BACKTR parameter file."""
    par = workdir / "backtr.par"
    par.write_text(f"""Parameters for BACKTR
*********************

START OF PARAMETERS:
{infile}
1
-5.338762,3.451316
{outfile}
ns_data_tv.trn
-2,145.18124267578
1,-2
1,145.18124267578
""")
    return par


def setup_workdir(workdir):
    """Copy all needed DTK files into working directory."""
    workdir.mkdir(parents=True, exist_ok=True)
    # Copy data files
    shutil.copy2(DTK_DIR / "ns_data_tv.dat", workdir / "ns_data_tv.dat")
    shutil.copy2(DTK_DIR / "ns_data_tv.trn", workdir / "ns_data_tv.trn")
    # Copy felszin secondary
    shutil.copy2(FELSZIN, workdir / "felszin_secondary.dat")


def read_gslib_column(filepath, col=0, skip_nodata=True, nodata=-999.0):
    """Read a column from a GSLIB/GeoEAS file."""
    lines = Path(filepath).read_text().strip().split("\n")
    ncols = int(lines[1].strip().split()[0])
    data_start = 2 + ncols
    vals = []
    for line in lines[data_start:]:
        parts = line.strip().split()
        if not parts:
            continue
        try:
            v = float(parts[col])
            if skip_nodata and abs(v - nodata) < 0.01:
                continue
            vals.append(v)
        except (ValueError, IndexError):
            continue
    return np.array(vals)


def cross_validate(orig_sgsim, new_postsim, orig_nreal=100):
    """Cross-validate new results against original DTK sgsim output."""
    print("\n" + "=" * 60)
    print("  CROSS-VALIDATION vs Original DTK Results")
    print("=" * 60)

    # Read original sgsim.out (100 realizations) and compute E-type
    print("  Reading original sgsim.out (100 realizations)...")
    lines = Path(orig_sgsim).read_text().strip().split("\n")
    ncols = int(lines[1].strip().split()[0])
    data_start = 2 + ncols
    data_lines = lines[data_start:]

    orig_vals = []
    for line in data_lines:
        parts = line.strip().split()
        if parts:
            try:
                orig_vals.append(float(parts[0]))
            except ValueError:
                continue

    orig_arr = np.array(orig_vals[:NNODES * orig_nreal])
    if len(orig_arr) < NNODES * orig_nreal:
        print(f"  WARNING: Expected {NNODES * orig_nreal} values, got {len(orig_arr)}")
        orig_nreal = len(orig_arr) // NNODES

    orig_grid = orig_arr.reshape(orig_nreal, NNODES)
    orig_etype = orig_grid.mean(axis=0)
    orig_var = orig_grid.var(axis=0)

    # Read new postsim E-type
    print("  Reading new postsim E-type (160 realizations)...")
    new_vals = read_gslib_column(new_postsim, col=0, skip_nodata=False,
                                  nodata=-99999)

    if len(new_vals) < NNODES:
        print(f"  ERROR: postsim has only {len(new_vals)} values, need {NNODES}")
        return

    new_etype = new_vals[:NNODES]

    # Compare
    diff = new_etype - orig_etype
    corr = np.corrcoef(orig_etype, new_etype)[0, 1]
    rmse = np.sqrt(np.mean(diff ** 2))
    mae = np.mean(np.abs(diff))
    bias = np.mean(diff)

    print(f"\n  Original (100 real):  mean={orig_etype.mean():.6f}  std={orig_etype.std():.6f}")
    print(f"  New (160 real):       mean={new_etype.mean():.6f}  std={new_etype.std():.6f}")
    print(f"  Correlation:          {corr:.6f}")
    print(f"  RMSE:                 {rmse:.6f}")
    print(f"  MAE:                  {mae:.6f}")
    print(f"  Bias:                 {bias:.6f}")
    print(f"  Max abs diff:         {np.max(np.abs(diff)):.6f}")

    # Variance comparison
    print(f"\n  Original avg variance:  {orig_var.mean():.6f}")
    print(f"  160-real should have ~{100/160:.0f}% of 100-real sampling variance")

    if corr > 0.95:
        print("\n  VERDICT: EXCELLENT — results are highly consistent")
    elif corr > 0.85:
        print("\n  VERDICT: GOOD — results are consistent (expected minor differences)")
    else:
        print("\n  VERDICT: CHECK — correlation lower than expected")


# ── Test 1: Direct EXE on disk ────────────────────────────────────────

def test_direct():
    """Run sgsim + postsim directly on disk."""
    print("\n" + "=" * 60)
    print("  TEST 1: Direct EXE (disk I/O)")
    print("=" * 60)

    workdir = RESULTS_DIR / "test1_direct"
    if workdir.exists():
        shutil.rmtree(workdir)
    setup_workdir(workdir)

    # SGSIM
    par = make_sgsim_par(workdir)
    print(f"  Running sgsim_fc ({NREAL} realizations, {NX}x{NY} grid)...")
    ok, t_sgsim, err = run_exe("sgsim_fc", par, workdir)
    if not ok:
        print(f"  SGSIM_FC FAILED: {err[-300:]}")
        return None, None

    # POSTSIM
    par = make_postsim_par(workdir)
    print(f"  Running postsim...")
    ok, t_postsim, err = run_exe("postsim", par, workdir)
    if not ok:
        print(f"  POSTSIM FAILED: {err[-300:]}")

    # BACKTR
    par = make_backtr_par(workdir)
    ok, t_backtr, err = run_exe("backtr", par, workdir)

    total = t_sgsim + t_postsim + t_backtr
    print(f"\n  Timing:")
    print(f"    SGSIM_FC: {t_sgsim:8.2f}s")
    print(f"    POSTSIM: {t_postsim:8.2f}s")
    print(f"    BACKTR:  {t_backtr:8.2f}s")
    print(f"    TOTAL:   {total:8.2f}s")

    return workdir, total


def test_workflow():
    """Run via Python workflow (temp dir, cache-pinned)."""
    print("\n" + "=" * 60)
    print("  TEST 2: Workflow Orchestrator (cache-pinned temp dir)")
    print("=" * 60)

    import tempfile
    workdir = Path(tempfile.mkdtemp(prefix="gslib_bench_wf_"))
    setup_workdir(workdir)

    # Pin files in cache
    sys.path.insert(0, str(Path(r"c:\Codename_EpicFury\gslib2_opt\workflow")))
    from ramdisk import RamDisk
    import ctypes
    FILE_ATTRIBUTE_TEMPORARY = 0x100
    kernel32 = ctypes.windll.kernel32
    for f in workdir.iterdir():
        if f.is_file():
            attrs = kernel32.GetFileAttributesW(str(f))
            if attrs != -1:
                kernel32.SetFileAttributesW(str(f), attrs | FILE_ATTRIBUTE_TEMPORARY)

    t_total_start = time.perf_counter()

    # SGSIM
    par = make_sgsim_par(workdir)
    ok, t_sgsim, err = run_exe("sgsim_fc", par, workdir)
    if not ok:
        print(f"  SGSIM_FC FAILED: {err[-300:]}")
        return None, None

    # Pin output
    for f in workdir.iterdir():
        if f.is_file():
            attrs = kernel32.GetFileAttributesW(str(f))
            if attrs != -1:
                kernel32.SetFileAttributesW(str(f), attrs | FILE_ATTRIBUTE_TEMPORARY)

    # POSTSIM
    par = make_postsim_par(workdir)
    ok, t_postsim, err = run_exe("postsim", par, workdir)

    # BACKTR
    par = make_backtr_par(workdir)
    ok, t_backtr, err = run_exe("backtr", par, workdir)

    total = time.perf_counter() - t_total_start

    print(f"\n  Timing:")
    print(f"    SGSIM_FC: {t_sgsim:8.2f}s")
    print(f"    POSTSIM: {t_postsim:8.2f}s")
    print(f"    BACKTR:  {t_backtr:8.2f}s")
    print(f"    TOTAL:   {total:8.2f}s (incl. overhead)")

    # Copy results for cross-validation
    result_dir = RESULTS_DIR / "test2_workflow"
    result_dir.mkdir(parents=True, exist_ok=True)
    for f in ["postsim.out", "backtr.out", "sgsim.out"]:
        src = workdir / f
        if src.exists():
            shutil.copy2(src, result_dir / f)

    # Cleanup
    shutil.rmtree(workdir, ignore_errors=True)
    return result_dir, total


def test_ramdisk():
    """Run with VHD RAM disk (or cache-pinned fallback)."""
    print("\n" + "=" * 60)
    print("  TEST 3: RAM Disk (VHD or cache-pinned)")
    print("=" * 60)

    sys.path.insert(0, str(Path(r"c:\Codename_EpicFury\gslib2_opt\workflow")))
    from ramdisk import RamDisk

    rd = RamDisk(size_mb=2048, drive="R")
    t_total_start = time.perf_counter()

    try:
        rd.create()
        workdir = rd.path if rd.path.exists() else rd.path
        # Create a subdirectory on the ramdisk
        work = workdir / "dtk_bench"
        work.mkdir(parents=True, exist_ok=True)
        setup_workdir(work)
        rd.pin_files()

        # SGSIM
        par = make_sgsim_par(work)
        ok, t_sgsim, err = run_exe("sgsim", par, work)
        if not ok:
            print(f"  SGSIM_FC FAILED: {err[-300:]}")
            return None, None

        rd.pin_files()

        # POSTSIM
        par = make_postsim_par(work)
        ok, t_postsim, err = run_exe("postsim", par, work)

        # BACKTR
        par = make_backtr_par(work)
        ok, t_backtr, err = run_exe("backtr", par, work)

        total = time.perf_counter() - t_total_start

        print(f"\n  RAM disk mode: {rd.mode}")
        print(f"  Timing:")
        print(f"    SGSIM_FC: {t_sgsim:8.2f}s")
        print(f"    POSTSIM: {t_postsim:8.2f}s")
        print(f"    BACKTR:  {t_backtr:8.2f}s")
        print(f"    TOTAL:   {total:8.2f}s (incl. ramdisk setup)")

        # Copy results
        result_dir = RESULTS_DIR / "test3_ramdisk"
        result_dir.mkdir(parents=True, exist_ok=True)
        for f in ["postsim.out", "backtr.out", "sgsim.out"]:
            src = work / f
            if src.exists():
                shutil.copy2(src, result_dir / f)

        return result_dir, total

    finally:
        rd.destroy()


# ── Main ──────────────────────────────────────────────────────────────

def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("  DTK BENCHMARK: SGSIM_FC 160 Realizations")
    print(f"  Grid: {NX} x {NY} x {NZ} = {NNODES:,} nodes")
    print(f"  Realizations: {NREAL}")
    print(f"  Kriging: Markov-type II (felszin secondary, r=0.98)")
    print(f"  CPUs: {os.cpu_count()}")
    print("=" * 60)

    # Test 1: Direct
    dir1, t1 = test_direct()

    # Test 2: Workflow
    dir2, t2 = test_workflow()

    # Test 3: RAM disk
    dir3, t3 = test_ramdisk()

    # Summary
    print("\n" + "=" * 60)
    print("  SPEED COMPARISON")
    print("=" * 60)
    times = []
    labels = ["1. Direct (disk)", "2. Workflow (cache)", "3. RAM disk"]
    for label, t in zip(labels, [t1, t2, t3]):
        if t is not None:
            print(f"    {label:25s}  {t:8.2f}s")
            times.append(t)
        else:
            print(f"    {label:25s}  FAILED")
    if times:
        fastest = min(times)
        for label, t in zip(labels, [t1, t2, t3]):
            if t is not None:
                ratio = t / fastest
                print(f"    {label:25s}  {ratio:.2f}x")

    # Cross-validation against original DTK results
    orig_sgsim = DTK_DIR / "sgsim.out"
    # Use test1 (direct) results for cross-validation
    if dir1 and (dir1 / "postsim.out").exists():
        cross_validate(str(orig_sgsim), str(dir1 / "postsim.out"))
    elif dir2 and (dir2 / "postsim.out").exists():
        cross_validate(str(orig_sgsim), str(dir2 / "postsim.out"))
    elif dir3 and (dir3 / "postsim.out").exists():
        cross_validate(str(orig_sgsim), str(dir3 / "postsim.out"))


if __name__ == "__main__":
    main()
