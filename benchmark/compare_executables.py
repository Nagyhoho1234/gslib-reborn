"""
Per-executable old vs new comparison.
Runs sgsim_fc, backtr, postsim each independently (old vs new) in parallel.
"""
import subprocess, os, time, shutil, sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

BIN_NEW = Path(r"c:\Codename_EpicFury\gslib2_opt\bin_opt")
BIN_OLD = Path(r"e:\Backup_O\00000\DTK\2000_ 02_ 01_")
DTK     = BIN_OLD
FELSZIN = Path(r"e:\Backup_O\00000\DTK\felszin\PSEtype_SG_NS_HS_ddm.out")
BASE    = Path(r"c:\Codename_EpicFury\gslib2_opt\benchmark")

NREAL = 100  # same count for fair comparison

def make_env_new():
    env = os.environ.copy()
    env["PATH"] = r"C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\bin;" + env.get("PATH", "")
    env["OMP_STACKSIZE"] = "128M"
    env["OMP_NUM_THREADS"] = "1"  # single thread for fair comparison
    return env

env_new = make_env_new()
env_old = os.environ.copy()

def run_exe(exe, parname, workdir, env, timeout=180):
    t0 = time.perf_counter()
    r = subprocess.run([str(exe)], input=parname+"\n",
                       capture_output=True, text=True, cwd=str(workdir),
                       env=env, timeout=timeout)
    elapsed = time.perf_counter() - t0
    return elapsed, r.returncode, r.stdout, r.stderr

def read_gslib_values(f, col=0):
    """Read a GSLIB file, return values from column col (0-based)."""
    vals = []
    with open(f) as fh:
        fh.readline()  # title
        hdr2 = fh.readline().strip().split()
        ncols = int(hdr2[0])
        for _ in range(ncols): fh.readline()
        for line in fh:
            parts = line.strip().split()
            if parts:
                try:
                    v = float(parts[col])
                    vals.append(v)
                except (ValueError, IndexError):
                    continue
    return vals

def stats(vals, label=""):
    if not vals:
        return {"n":0}
    n = len(vals)
    mean = sum(vals)/n
    var = sum((v-mean)**2 for v in vals)/n
    vs = sorted(vals)
    return {"n":n, "mean":mean, "sd":var**.5,
            "min":vs[0], "p10":vs[int(n*.1)], "p25":vs[int(n*.25)],
            "p50":vs[int(n*.5)], "p75":vs[int(n*.75)], "p90":vs[int(n*.9)],
            "max":vs[-1]}

def compare_values(v_old, v_new, name):
    """Point-by-point comparison of two value lists."""
    if len(v_old) != len(v_new):
        print(f"  WARNING: {name} record count differs: old={len(v_old)} new={len(v_new)}")
        n = min(len(v_old), len(v_new))
    else:
        n = len(v_old)
    if n == 0:
        print(f"  {name}: no data to compare")
        return
    diffs = [abs(v_new[i] - v_old[i]) for i in range(n)]
    max_diff = max(diffs)
    mean_diff = sum(diffs)/n
    rel_diffs = [abs(v_new[i]-v_old[i])/(abs(v_old[i])+1e-30) for i in range(n) if abs(v_old[i])>1e-10]
    max_rel = max(rel_diffs) if rel_diffs else 0
    exact = sum(1 for d in diffs if d == 0.0)
    close4 = sum(1 for d in diffs if d < 0.0001)
    print(f"  {name}: n={n}, exact_match={exact}/{n} ({100*exact/n:.1f}%), "
          f"<0.0001={close4}/{n} ({100*close4/n:.1f}%)")
    print(f"    max_abs_diff={max_diff:.6f}, mean_abs_diff={mean_diff:.6f}, max_rel_diff={max_rel:.6e}")

# =========================================================================
# SGSIM_FC comparison
# =========================================================================
def test_sgsim():
    print("\n" + "="*70)
    print("  SGSIM_FC: OLD (32-bit) vs NEW (64-bit, 1 thread)")
    print("="*70)

    sgsim_par = f"""Parameters for SGSIM_FC
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
{NREAL}
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
    # Setup old dir
    d_old = BASE / "exe_cmp_sgsim_old"
    if d_old.exists(): shutil.rmtree(d_old)
    d_old.mkdir(parents=True)
    shutil.copy2(DTK / "ns_data_tv.dat", d_old)
    shutil.copy2(DTK / "ns_data_tv.trn", d_old)
    shutil.copy2(FELSZIN, d_old / "felszin_secondary.dat")
    (d_old / "sgsim_fc.par").write_text(sgsim_par)

    # Setup new dir
    d_new = BASE / "exe_cmp_sgsim_new"
    if d_new.exists(): shutil.rmtree(d_new)
    d_new.mkdir(parents=True)
    shutil.copy2(DTK / "ns_data_tv.dat", d_new)
    shutil.copy2(DTK / "ns_data_tv.trn", d_new)
    shutil.copy2(FELSZIN, d_new / "felszin_secondary.dat")
    (d_new / "sgsim_fc.par").write_text(sgsim_par)

    # Run old
    t_old, rc_old, _, stderr_old = run_exe(BIN_OLD / "sgsim_fc.exe", "sgsim_fc.par", d_old, env_old, timeout=300)
    print(f"  OLD: {t_old:.2f}s rc={rc_old}")
    if rc_old != 0: print(f"    stderr: {stderr_old[-200:]}")

    # Run new
    t_new, rc_new, _, stderr_new = run_exe(BIN_NEW / "sgsim_fc.exe", "sgsim_fc.par", d_new, env_new, timeout=300)
    print(f"  NEW: {t_new:.2f}s rc={rc_new}")
    if rc_new != 0: print(f"    stderr: {stderr_new[-200:]}")

    # Compare outputs
    if rc_old == 0 and rc_new == 0:
        v_old = read_gslib_values(d_old / "sgsim.out")
        v_new = read_gslib_values(d_new / "sgsim.out")
        s_old = stats(v_old)
        s_new = stats(v_new)
        print(f"\n  Distribution comparison (NS-space simulated values):")
        print(f"  {'':12s} {'N':>8s} {'Mean':>10s} {'SD':>10s} {'P50':>10s} {'Min':>10s} {'Max':>10s}")
        for lbl, s in [("OLD", s_old), ("NEW", s_new)]:
            print(f"  {lbl:12s} {s['n']:8d} {s['mean']:10.4f} {s['sd']:10.4f} {s['p50']:10.4f} {s['min']:10.4f} {s['max']:10.4f}")
        # Same seed -> should be identical or very close
        compare_values(v_old, v_new, "sgsim.out")

    return {"old_time": t_old, "new_time": t_new, "old_rc": rc_old, "new_rc": rc_new}

# =========================================================================
# BACKTR comparison
# =========================================================================
def test_backtr():
    print("\n" + "="*70)
    print("  BACKTR: OLD (32-bit) vs NEW (64-bit, 1-col output)")
    print("="*70)

    backtr_par = """Parameters for BACKTR
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
    # Use the original sgsim.out as shared input
    sgsim_src = DTK / "sgsim_ORIGINAL.out.bak"

    # Setup old dir
    d_old = BASE / "exe_cmp_backtr_old"
    if d_old.exists(): shutil.rmtree(d_old)
    d_old.mkdir(parents=True)
    shutil.copy2(sgsim_src, d_old / "sgsim.out")
    shutil.copy2(DTK / "ns_data_tv.trn", d_old)
    (d_old / "backtr.par").write_text(backtr_par)

    # Setup new dir
    d_new = BASE / "exe_cmp_backtr_new"
    if d_new.exists(): shutil.rmtree(d_new)
    d_new.mkdir(parents=True)
    shutil.copy2(sgsim_src, d_new / "sgsim.out")
    shutil.copy2(DTK / "ns_data_tv.trn", d_new)
    (d_new / "backtr.par").write_text(backtr_par)

    # Run old
    t_old, rc_old, _, stderr_old = run_exe(BIN_OLD / "backtr.exe", "backtr.par", d_old, env_old)
    print(f"  OLD: {t_old:.2f}s rc={rc_old}")
    if rc_old != 0: print(f"    stderr: {stderr_old[-200:]}")

    # Run new
    t_new, rc_new, _, stderr_new = run_exe(BIN_NEW / "backtr.exe", "backtr.par", d_new, env_new)
    print(f"  NEW: {t_new:.2f}s rc={rc_new}")
    if rc_new != 0: print(f"    stderr: {stderr_new[-200:]}")

    # Compare outputs
    if rc_old == 0 and rc_new == 0:
        # Old backtr outputs nvari+1 columns, new outputs 1 column
        # Read last column from old, first (only) column from new
        v_old_raw = read_gslib_values(d_old / "backtr.out", col=-1)
        v_new = read_gslib_values(d_new / "backtr.out", col=0)

        # Old backtr: need to figure out which column has BT values
        # Read header to check
        with open(d_old / "backtr.out") as fh:
            title = fh.readline().strip()
            hdr = fh.readline().strip()
            print(f"  OLD header: '{title}' / '{hdr}'")

        s_old = stats(v_old_raw)
        s_new = stats(v_new)
        print(f"\n  Distribution comparison (back-transformed values):")
        print(f"  {'':12s} {'N':>8s} {'Mean':>10s} {'SD':>10s} {'P50':>10s} {'Min':>10s} {'Max':>10s}")
        for lbl, s in [("OLD", s_old), ("NEW", s_new)]:
            print(f"  {lbl:12s} {s['n']:8d} {s['mean']:10.4f} {s['sd']:10.4f} {s['p50']:10.4f} {s['min']:10.4f} {s['max']:10.4f}")
        compare_values(v_old_raw, v_new, "backtr.out (BT values)")

    return {"old_time": t_old, "new_time": t_new, "old_rc": rc_old, "new_rc": rc_new}

# =========================================================================
# POSTSIM comparison
# =========================================================================
def test_postsim():
    print("\n" + "="*70)
    print("  POSTSIM: OLD (32-bit) vs NEW (64-bit, allocatable)")
    print("="*70)

    postsim_par = f"""Parameters for POSTSIM
***********************

START OF PARAMETERS:
backtr.out
{NREAL}
-2,145.18124267578
127,216,1
postsim.out
1,0.50
"""
    # First generate backtr.out from original sgsim using NEW backtr
    # (same input for both old and new postsim)
    backtr_par = """Parameters for BACKTR
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
    d_prep = BASE / "exe_cmp_postsim_prep"
    if d_prep.exists(): shutil.rmtree(d_prep)
    d_prep.mkdir(parents=True)
    shutil.copy2(DTK / "sgsim_ORIGINAL.out.bak", d_prep / "sgsim.out")
    shutil.copy2(DTK / "ns_data_tv.trn", d_prep)
    (d_prep / "backtr.par").write_text(backtr_par)
    t, rc, _, _ = run_exe(BIN_NEW / "backtr.exe", "backtr.par", d_prep, env_new)
    print(f"  Prep backtr: {t:.2f}s rc={rc}")
    if rc != 0:
        print("  ABORT: could not prepare backtr.out")
        return {}

    # Setup old dir (old postsim reads 1-col backtr.out)
    d_old = BASE / "exe_cmp_postsim_old"
    if d_old.exists(): shutil.rmtree(d_old)
    d_old.mkdir(parents=True)
    shutil.copy2(d_prep / "backtr.out", d_old)
    (d_old / "postsim.par").write_text(postsim_par)

    # Setup new dir
    d_new = BASE / "exe_cmp_postsim_new"
    if d_new.exists(): shutil.rmtree(d_new)
    d_new.mkdir(parents=True)
    shutil.copy2(d_prep / "backtr.out", d_new)
    (d_new / "postsim.par").write_text(postsim_par)

    # Run old
    t_old, rc_old, _, stderr_old = run_exe(BIN_OLD / "postsim.exe", "postsim.par", d_old, env_old)
    print(f"  OLD: {t_old:.2f}s rc={rc_old}")
    if rc_old != 0: print(f"    stderr: {stderr_old[-200:]}")

    # Run new
    t_new, rc_new, _, stderr_new = run_exe(BIN_NEW / "postsim.exe", "postsim.par", d_new, env_new)
    print(f"  NEW: {t_new:.2f}s rc={rc_new}")
    if rc_new != 0: print(f"    stderr: {stderr_new[-200:]}")

    # Compare outputs
    if rc_old == 0 and rc_new == 0:
        v_old = read_gslib_values(d_old / "postsim.out", col=0)
        v_new = read_gslib_values(d_new / "postsim.out", col=0)
        s_old = stats(v_old)
        s_new = stats(v_new)
        print(f"\n  Distribution comparison (E-type values):")
        print(f"  {'':12s} {'N':>8s} {'Mean':>10s} {'SD':>10s} {'P50':>10s} {'Min':>10s} {'Max':>10s}")
        for lbl, s in [("OLD", s_old), ("NEW", s_new)]:
            print(f"  {lbl:12s} {s['n']:8d} {s['mean']:10.4f} {s['sd']:10.4f} {s['p50']:10.4f} {s['min']:10.4f} {s['max']:10.4f}")
        compare_values(v_old, v_new, "postsim.out (E-type)")

    return {"old_time": t_old, "new_time": t_new, "old_rc": rc_old, "new_rc": rc_new}

# =========================================================================
# RUN ALL THREE IN PARALLEL
# =========================================================================
print("="*70)
print("  EXECUTABLE COMPARISON: OLD (32-bit) vs NEW (64-bit)")
print(f"  {NREAL} realizations, single-thread, same seed")
print("  Running all 3 comparisons in parallel...")
print("="*70)

results = {}
with ThreadPoolExecutor(max_workers=3) as pool:
    futures = {
        pool.submit(test_sgsim): "sgsim_fc",
        pool.submit(test_backtr): "backtr",
        pool.submit(test_postsim): "postsim",
    }
    for f in as_completed(futures):
        name = futures[f]
        try:
            results[name] = f.result()
        except Exception as e:
            print(f"\n  ERROR in {name}: {e}")
            results[name] = {}

# =========================================================================
# SUMMARY
# =========================================================================
print("\n" + "="*70)
print("  TIMING SUMMARY (single-thread)")
print("="*70)
print(f"  {'Executable':<12s} {'OLD':>10s} {'NEW':>10s} {'Speedup':>10s}")
print(f"  {'-'*12} {'-'*10} {'-'*10} {'-'*10}")
for name in ["sgsim_fc", "backtr", "postsim"]:
    r = results.get(name, {})
    t_old = r.get("old_time", 0)
    t_new = r.get("new_time", 0)
    speedup = t_old / t_new if t_new > 0 else 0
    print(f"  {name:<12s} {t_old:9.2f}s {t_new:9.2f}s {speedup:9.2f}x")

print("\n" + "="*70)
print("  DONE")
print("="*70)
