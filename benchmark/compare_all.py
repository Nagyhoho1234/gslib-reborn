"""
Compare all scenarios: old/new sgsim -> our backtr -> old/new postsim
All using E-type (median-type estimation, iout=1)
"""
import subprocess, os, time, shutil
from pathlib import Path

BIN_OPT = Path(r"c:\Codename_EpicFury\gslib2_opt\bin_opt")
DTK     = Path(r"e:\Backup_O\00000\DTK\2000_ 02_ 01_")
FELSZIN = Path(r"e:\Backup_O\00000\DTK\felszin\PSEtype_SG_NS_HS_ddm.out")
BASE    = Path(r"c:\Codename_EpicFury\gslib2_opt\benchmark")

def make_env():
    env = os.environ.copy()
    env["PATH"] = r"C:\Program Files (x86)\Intel\oneAPI\compiler\2025.3\bin;" + env.get("PATH", "")
    env["OMP_STACKSIZE"] = "128M"
    env["OMP_NUM_THREADS"] = "32"
    return env

def run_exe(exe, parname, workdir, env):
    t0 = time.perf_counter()
    r = subprocess.run([str(exe)], input=parname+"\n",
                       capture_output=True, text=True, cwd=str(workdir),
                       env=env, timeout=120)
    return time.perf_counter() - t0, r.returncode

def backtr_par():
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

def setup_dir(d):
    if d.exists(): shutil.rmtree(d)
    d.mkdir(parents=True)
    shutil.copy2(DTK / "ns_data_tv.dat", d)
    shutil.copy2(DTK / "ns_data_tv.trn", d)
    shutil.copy2(FELSZIN, d / "felszin_secondary.dat")

def read_postsim_stats(f):
    vals = []
    with open(f) as fh:
        fh.readline()
        # Old postsim: "2  127  216  1", new postsim: "1"
        hdr2 = fh.readline().strip().split()
        ncols = int(hdr2[0])
        for _ in range(ncols): fh.readline()
        for line in fh:
            parts = line.strip().split()
            if parts:
                v = float(parts[0])
                if v > -90: vals.append(v)
    if not vals: return None
    n = len(vals)
    mean = sum(vals)/n
    var = sum((v-mean)**2 for v in vals)/n
    vs = sorted(vals)
    return {"n":n, "mean":mean, "sd":var**.5,
            "min":vs[0], "p10":vs[int(n*.1)], "p25":vs[int(n*.25)],
            "p50":vs[int(n*.5)], "p75":vs[int(n*.75)], "p90":vs[int(n*.9)],
            "max":vs[-1]}

env_new = make_env()
env_old = os.environ.copy()

results = {}

# ---- SCENARIO A: Old sgsim.out (100r) -> our backtr -> our postsim ----
print("SCENARIO A: Original sgsim.out (100r) -> NEW backtr -> NEW postsim")
d = BASE / "cmp_A_oldsgsim_newbt_newps"
setup_dir(d)
shutil.copy2(DTK / "sgsim_ORIGINAL.out.bak", d / "sgsim.out")
(d / "backtr.par").write_text(backtr_par())
(d / "postsim.par").write_text(postsim_par(100))
t, rc = run_exe(BIN_OPT / "backtr.exe", "backtr.par", d, env_new)
print(f"  backtr: {t:.2f}s rc={rc}")
t, rc = run_exe(BIN_OPT / "postsim.exe", "postsim.par", d, env_new)
print(f"  postsim: {t:.2f}s rc={rc}")
results["A: old_sgsim+new_bt+new_ps (100r)"] = read_postsim_stats(d / "postsim.out")

# ---- SCENARIO B: Old sgsim.out (100r) -> our backtr -> OLD postsim ----
print("\nSCENARIO B: Original sgsim.out (100r) -> NEW backtr -> OLD postsim")
d = BASE / "cmp_B_oldsgsim_newbt_oldps"
setup_dir(d)
shutil.copy2(DTK / "sgsim_ORIGINAL.out.bak", d / "sgsim.out")
(d / "backtr.par").write_text(backtr_par())
(d / "postsim.par").write_text(postsim_par(100))
t, rc = run_exe(BIN_OPT / "backtr.exe", "backtr.par", d, env_new)
print(f"  backtr (new): {t:.2f}s rc={rc}")
t, rc = run_exe(DTK / "postsim.exe", "postsim.par", d, env_old)
print(f"  postsim (old): {t:.2f}s rc={rc}")
results["B: old_sgsim+new_bt+old_ps (100r)"] = read_postsim_stats(d / "postsim.out")

# ---- SCENARIO C: NEW sgsim_fc (100r) -> our backtr -> our postsim ----
print("\nSCENARIO C: NEW sgsim_fc (100r) -> NEW backtr -> NEW postsim")
d = BASE / "cmp_C_newsgsim100_newbt_newps"
setup_dir(d)
(d / "sgsim_fc.par").write_text(sgsim_par(100))
(d / "backtr.par").write_text(backtr_par())
(d / "postsim.par").write_text(postsim_par(100))
t, rc = run_exe(BIN_OPT / "sgsim_fc.exe", "sgsim_fc.par", d, env_new)
print(f"  sgsim_fc (new, 100r): {t:.2f}s rc={rc}")
t, rc = run_exe(BIN_OPT / "backtr.exe", "backtr.par", d, env_new)
print(f"  backtr: {t:.2f}s rc={rc}")
t, rc = run_exe(BIN_OPT / "postsim.exe", "postsim.par", d, env_new)
print(f"  postsim: {t:.2f}s rc={rc}")
results["C: new_sgsim+new_bt+new_ps (100r)"] = read_postsim_stats(d / "postsim.out")

# ---- SCENARIO D: NEW sgsim_fc (160r) -> our backtr -> our postsim ----
print("\nSCENARIO D: NEW sgsim_fc (160r) -> NEW backtr -> NEW postsim")
d = BASE / "cmp_D_newsgsim160_newbt_newps"
setup_dir(d)
(d / "sgsim_fc.par").write_text(sgsim_par(160))
(d / "backtr.par").write_text(backtr_par())
(d / "postsim.par").write_text(postsim_par(160))
t, rc = run_exe(BIN_OPT / "sgsim_fc.exe", "sgsim_fc.par", d, env_new)
print(f"  sgsim_fc (new, 160r): {t:.2f}s rc={rc}")
t, rc = run_exe(BIN_OPT / "backtr.exe", "backtr.par", d, env_new)
print(f"  backtr: {t:.2f}s rc={rc}")
t, rc = run_exe(BIN_OPT / "postsim.exe", "postsim.par", d, env_new)
print(f"  postsim: {t:.2f}s rc={rc}")
results["D: new_sgsim+new_bt+new_ps (160r)"] = read_postsim_stats(d / "postsim.out")

# ---- SCENARIO E: NEW sgsim_fc (100r) -> our backtr -> OLD postsim ----
print("\nSCENARIO E: NEW sgsim_fc (100r) -> NEW backtr -> OLD postsim")
d = BASE / "cmp_E_newsgsim100_newbt_oldps"
setup_dir(d)
(d / "sgsim_fc.par").write_text(sgsim_par(100))
(d / "backtr.par").write_text(backtr_par())
(d / "postsim.par").write_text(postsim_par(100))
t, rc = run_exe(BIN_OPT / "sgsim_fc.exe", "sgsim_fc.par", d, env_new)
print(f"  sgsim_fc (new, 100r): {t:.2f}s rc={rc}")
t, rc = run_exe(BIN_OPT / "backtr.exe", "backtr.par", d, env_new)
print(f"  backtr: {t:.2f}s rc={rc}")
t, rc = run_exe(DTK / "postsim.exe", "postsim.par", d, env_old)
print(f"  postsim (old): {t:.2f}s rc={rc}")
results["E: new_sgsim+new_bt+old_ps (100r)"] = read_postsim_stats(d / "postsim.out")

# ---- RESULTS TABLE ----
print("\n" + "="*140)
print("  E-TYPE COMPARISON (iout=1, median-type estimation)")
print("  Pipeline: sgsim -> NEW backtr (1-col output) -> postsim")
print("="*140)
print(f"  {'Scenario':<42s} {'N':>6s} {'Mean':>8s} {'SD':>8s} {'Min':>8s} {'P10':>8s} {'P25':>8s} {'P50':>8s} {'P75':>8s} {'P90':>8s} {'Max':>8s}")
print(f"  {'-'*42} {'-'*6} {'-'*8} {'-'*8} {'-'*8} {'-'*8} {'-'*8} {'-'*8} {'-'*8} {'-'*8} {'-'*8}")
for name, s in results.items():
    if s:
        print(f"  {name:<42s} {s['n']:6d} {s['mean']:8.2f} {s['sd']:8.2f} {s['min']:8.2f} {s['p10']:8.2f} {s['p25']:8.2f} {s['p50']:8.2f} {s['p75']:8.2f} {s['p90']:8.2f} {s['max']:8.2f}")
    else:
        print(f"  {name:<42s}  (no data)")

# Point-by-point A vs C (same 100r, old vs new sgsim, same pipeline)
sA = results.get("A: old_sgsim+new_bt+new_ps (100r)")
sC = results.get("C: new_sgsim+new_bt+new_ps (100r)")
if sA and sC:
    print(f"\n  A vs C diff (old vs new sgsim, same 100r):")
    print(f"    Mean: {sC['mean']-sA['mean']:+.4f}  SD: {sC['sd']-sA['sd']:+.4f}  P50: {sC['p50']-sA['p50']:+.4f}")

# A vs B (new vs old postsim on same data)
sB = results.get("B: old_sgsim+new_bt+old_ps (100r)")
if sA and sB:
    print(f"  A vs B diff (new vs old postsim on same data):")
    print(f"    Mean: {sA['mean']-sB['mean']:+.4f}  SD: {sA['sd']-sB['sd']:+.4f}  P50: {sA['p50']-sB['p50']:+.4f}")

print("\n" + "="*140)
