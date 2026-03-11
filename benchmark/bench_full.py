"""
Full 4-way pipeline benchmark: Baseline vs Direct vs Workflow vs Ramdisk
=========================================================================
Runs sgsim_fc -> postsim -> backtr sequentially in 4 configurations,
then cross-validates results.
"""
import subprocess, os, sys, time, shutil
from pathlib import Path

# -- Paths --------------------------------------------------------------
BIN_OPT = Path(r"c:\Codename_EpicFury\gslib2_opt\bin_opt")
DTK     = Path(r"e:\Backup_O\00000\DTK\2000_ 02_ 01_")
FELSZIN = Path(r"e:\Backup_O\00000\DTK\felszin\PSEtype_SG_NS_HS_ddm.out")
BASE    = Path(r"c:\Codename_EpicFury\gslib2_opt\benchmark")

sys.path.insert(0, str(Path(r"c:\Codename_EpicFury\gslib2_opt\workflow")))
from ramdisk import RamDisk

# -- Par file templates -------------------------------------------------
def sgsim_par(nreal):
    return f"""Parameters for SGSIM_FC
***********************

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
"""

def backtr_sgsim_par():
    """backtr reads sgsim.out (all realizations in NS space) -> backtr.out (original space)"""
    return """Parameters for BACKTR
***********************

START OF PARAMETERS:
sgsim.out
1
-5.338762,3.451316
backtr.out
ns_data_tv.trn
-2,145.18124267578
1,-2
1,145.18124267578
"""

def postsim_par(nreal):
    """postsim reads backtr.out (back-transformed realizations) -> postsim.out"""
    return f"""Parameters for POSTSIM
***********************

START OF PARAMETERS:
backtr.out
{nreal}
-2,145.18124267578
127,216,1
postsim.out
1,0.50
"""

# -- Helpers ------------------------------------------------------------
def make_env(threads=32):
    env = os.environ.copy()
    intel_bin = r"C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\bin"
    env["PATH"] = intel_bin + ";" + env.get("PATH", "")
    env["OMP_STACKSIZE"] = "128M"
    env["OMP_NUM_THREADS"] = str(threads)
    return env

def run_exe(exe, parfile, workdir, env, label=""):
    """Run a GSLIB exe, return (success, elapsed_seconds)."""
    t0 = time.perf_counter()
    proc = subprocess.run(
        [str(exe)], input=str(parfile) + "\n",
        capture_output=True, text=True,
        cwd=str(workdir), env=env, timeout=120
    )
    elapsed = time.perf_counter() - t0
    ok = proc.returncode == 0
    tag = "OK" if ok else f"FAIL(rc={proc.returncode})"
    print(f"    {label:10s} {tag:6s} {elapsed:6.2f}s")
    if not ok and proc.stderr:
        for line in proc.stderr.strip().split("\n")[-3:]:
            print(f"      {line}")
    return ok, elapsed

def setup_workdir(d, nreal):
    """Prepare a working directory with data + par files."""
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    shutil.copy2(DTK / "ns_data_tv.dat", d)
    shutil.copy2(DTK / "ns_data_tv.trn", d)
    shutil.copy2(FELSZIN, d / "felszin_secondary.dat")
    (d / "sgsim_fc.par").write_text(sgsim_par(nreal))
    (d / "backtr.par").write_text(backtr_sgsim_par())
    (d / "postsim.par").write_text(postsim_par(nreal))

def run_pipeline(workdir, exe_dir, env, label):
    """Run sgsim_fc -> postsim -> backtr, return dict of timings."""
    print(f"\n  [{label}]")
    t_total = time.perf_counter()
    timings = {}

    ok1, t1 = run_exe(exe_dir / "sgsim_fc.exe", "sgsim_fc.par", workdir, env, "sgsim_fc")
    timings["sgsim_fc"] = t1
    if not ok1:
        print(f"    ABORT: sgsim_fc failed")
        return timings

    ok2, t2 = run_exe(exe_dir / "backtr.exe", "backtr.par", workdir, env, "backtr")
    timings["backtr"] = t2
    if not ok2:
        print(f"    ABORT: backtr failed")
        return timings

    ok3, t3 = run_exe(exe_dir / "postsim.exe", "postsim.par", workdir, env, "postsim")
    timings["postsim"] = t3

    timings["total"] = time.perf_counter() - t_total

    # Output sizes
    for f in ["sgsim.out", "postsim.out", "backtr.out"]:
        p = workdir / f
        sz = p.stat().st_size if p.exists() else 0
        print(f"    {f:14s} {sz:>12,} bytes")

    return timings

def read_backtr_stats(backtr_file):
    """Read backtr.out and compute basic statistics for cross-validation.
    Takes the LAST column (back-transformed values) from each data line."""
    if not backtr_file.exists():
        return None
    vals = []
    with open(backtr_file) as f:
        # Read header: first line = title, second = ncols, then ncols var names
        title = f.readline()
        ncols_line = f.readline().strip().split()
        ncols = int(ncols_line[0])
        for _ in range(ncols):
            f.readline()  # skip variable names
        for line in f:
            parts = line.strip().split()
            if not parts:
                continue
            try:
                v = float(parts[-1])  # last column = back-transformed
                if v > -90:
                    vals.append(v)
            except ValueError:
                continue
    if not vals:
        return None
    n = len(vals)
    mean = sum(vals) / n
    var = sum((v - mean)**2 for v in vals) / n
    vals_sorted = sorted(vals)
    p25 = vals_sorted[int(n * 0.25)]
    p50 = vals_sorted[int(n * 0.50)]
    p75 = vals_sorted[int(n * 0.75)]
    return {"n": n, "mean": mean, "var": var, "p25": p25, "p50": p50, "p75": p75,
            "min": vals_sorted[0], "max": vals_sorted[-1]}


# ======================================================================
#  MAIN BENCHMARK
# ======================================================================
print("=" * 64)
print("  GSLIB PIPELINE BENCHMARK")
print("  sgsim_fc -> backtr -> postsim (correct statistical order)")
print("  Grid: 127x216 (27,432 nodes), ktype=5 Markov-II")
print("  DTK project data + felszin secondary")
print("=" * 64)

env = make_env(32)
results = {}
backtr_stats = {}

# -- 0. BASELINE: Original 32-bit DTK executables, 100 realizations ---
print("\n" + "-" * 64)
print("  SCENARIO 0: BASELINE (original 32-bit, 100 realizations)")
print("-" * 64)
d0 = BASE / "test0_baseline"
setup_workdir(d0, 100)
# Use original 32-bit executables from DTK
env_baseline = os.environ.copy()  # no Intel OpenMP needed for 32-bit
results["baseline"] = run_pipeline(d0, DTK, env_baseline, "BASELINE 32-bit")
backtr_stats["baseline"] = read_backtr_stats(d0 / "postsim.out")

# -- 1. DIRECT: Optimized 64-bit, 160 realizations -------------------
print("\n" + "-" * 64)
print("  SCENARIO 1: DIRECT (optimized 64-bit, 160 realizations)")
print("-" * 64)
d1 = BASE / "test1_direct"
setup_workdir(d1, 160)
results["direct"] = run_pipeline(d1, BIN_OPT, env, "DIRECT 64-bit")
backtr_stats["direct"] = read_backtr_stats(d1 / "postsim.out")

# -- 2. WORKFLOW: Same exes, Python-orchestrated pipeline -------------
print("\n" + "-" * 64)
print("  SCENARIO 2: WORKFLOW (Python-orchestrated, 160 realizations)")
print("-" * 64)
d2 = BASE / "test2_workflow"
setup_workdir(d2, 160)
results["workflow"] = run_pipeline(d2, BIN_OPT, env, "WORKFLOW")
backtr_stats["workflow"] = read_backtr_stats(d2 / "postsim.out")

# -- 3. RAMDISK: Cache-pinned temp directory --------------------------
print("\n" + "-" * 64)
print("  SCENARIO 3: RAMDISK (cache-pinned, 160 realizations)")
print("-" * 64)
rd = RamDisk(size_mb=2048, force_mode="cache")
try:
    rd.create()
    d3 = rd.path
    # Copy data to ramdisk
    shutil.copy2(DTK / "ns_data_tv.dat", d3)
    shutil.copy2(DTK / "ns_data_tv.trn", d3)
    shutil.copy2(FELSZIN, d3 / "felszin_secondary.dat")
    (d3 / "sgsim_fc.par").write_text(sgsim_par(160))
    (d3 / "backtr.par").write_text(backtr_sgsim_par())
    (d3 / "postsim.par").write_text(postsim_par(160))
    rd.pin_files()

    results["ramdisk"] = run_pipeline(d3, BIN_OPT, env, "RAMDISK")
    rd.pin_files()  # pin output files too

    backtr_stats["ramdisk"] = read_backtr_stats(d3 / "postsim.out")

    # Copy results before cleanup
    d3_save = BASE / "test3_ramdisk"
    if d3_save.exists():
        shutil.rmtree(d3_save)
    d3_save.mkdir(parents=True)
    for f in ["sgsim.out", "postsim.out", "backtr.out"]:
        src = d3 / f
        if src.exists():
            shutil.copy2(src, d3_save)
finally:
    rd.destroy()

# ======================================================================
#  RESULTS SUMMARY
# ======================================================================
print("\n" + "=" * 64)
print("  TIMING RESULTS")
print("=" * 64)
print(f"\n  Pipeline: sgsim_fc -> backtr -> postsim")
print(f"  (backtr first: back-transform to original space BEFORE computing statistics)")
print(f"\n  {'Scenario':<16s} {'sgsim_fc':>9s} {'backtr':>9s} {'postsim':>9s} {'TOTAL':>9s}  nreal")
print(f"  {'-'*16} {'-'*9} {'-'*9} {'-'*9} {'-'*9}  -----")
for name, nreal in [("baseline", 100), ("direct", 160), ("workflow", 160), ("ramdisk", 160)]:
    r = results.get(name, {})
    s = r.get("sgsim_fc", 0)
    b = r.get("backtr", 0)
    p = r.get("postsim", 0)
    t = r.get("total", 0)
    print(f"  {name:<16s} {s:8.2f}s {b:8.2f}s {p:8.2f}s {t:8.2f}s  {nreal}")

# Per-realization comparison
print(f"\n  Per-realization pipeline time:")
for name, nreal in [("baseline", 100), ("direct", 160), ("workflow", 160), ("ramdisk", 160)]:
    r = results.get(name, {})
    t = r.get("total", 0)
    if t > 0:
        print(f"    {name:<16s} {t/nreal*1000:6.1f} ms/realization")

# -- Cross-validation -------------------------------------------------
print("\n" + "=" * 64)
print("  CROSS-VALIDATION: postsim.out (E-type in original data space)")
print("=" * 64)
print(f"\n  {'Scenario':<16s} {'N':>7s} {'Mean':>10s} {'Var':>10s} {'P25':>10s} {'P50':>10s} {'P75':>10s}")
print(f"  {'-'*16} {'-'*7} {'-'*10} {'-'*10} {'-'*10} {'-'*10} {'-'*10}")
for name in ["baseline", "direct", "workflow", "ramdisk"]:
    s = backtr_stats.get(name)
    if s:
        print(f"  {name:<16s} {s['n']:7d} {s['mean']:10.4f} {s['var']:10.4f} "
              f"{s['p25']:10.4f} {s['p50']:10.4f} {s['p75']:10.4f}")
    else:
        print(f"  {name:<16s}  (no data)")

print(f"\n  Note: Baseline=100 real, others=160 real. All P25 quantile.")
print(f"  E-type computed in original data space (backtr BEFORE postsim).")
print(f"  Statistics should be similar -- same input data, same variogram model.")

print(f"\n{'='*64}")
print(f"  DONE")
print(f"{'='*64}")
