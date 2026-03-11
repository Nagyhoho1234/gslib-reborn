"""Smoke test runner for all 37 GSLIB2 optimized programs."""
import subprocess
import os
import sys

BINDIR = r"c:\Codename_EpicFury\gslib2_opt\bin_opt"
TESTDIR = r"c:\Codename_EpicFury\gslib2_opt\smoke_test"

# Map: program_name -> (par_file, list_of_expected_output_files)
PROGRAMS = {
    # Tier 1 - Data preparation
    "declus":    ("declus.par",    ["declus.out", "declus.sum"]),
    "histsmth":  ("histsmth.par",  ["histsmth_run.out"]),
    "nscore":    ("nscore.par",    ["nscore_run.out", "nscore_run.trn"]),
    "gamv":      ("gamv.par",      ["gamv.out"]),
    "vmodel":    ("vmodel.par",    ["vmodel.var"]),
    # Tier 2 - Kriging
    "kt3d":      ("kt3d.par",      ["kt3d.out"]),
    "kb2d":      ("kb2d.par",      ["kb2d.out"]),
    "ik3d":      ("ik3d.par",      ["ik3d.out"]),
    # Tier 3 - Simulation (core)
    "sgsim":     ("sgsim.par",     ["sgsim_run.out"]),
    "sisim":     ("sisim.par",     ["sisim_run.out"]),
    "dssim":     ("dssim.par",     ["dssim.out"]),
    "lusim":     ("lusim.par",     ["lusim.out"]),
    # Tier 4 - Post-processing
    "backtr":    ("backtr.par",    ["backtr.out"]),
    "postsim":   ("postsim.par",   ["postsim.out"]),
    "postik":    ("postik.par",    ["postik.out"]),
    "addcoord":  ("addcoord.par",  ["addcoord.out"]),
    "gtsim":     ("gtsim.par",     ["gtsim.out"]),
    # Tier 5 - Other simulators
    "sgsim_fc":  ("sgsim_fc.par",  ["sgsim_fc.out"]),
    "sisim_gs":  ("sisim_gs.par",  ["sisim_gs.out"]),
    "sisim_lm":  ("sisim_lm.par",  ["sisim_lm.out"]),
    "pfsim":     ("pfsim.par",     ["pfsim.out"]),
    "sasim":     ("sasim.par",     ["sasim.out"]),
    "ellipsim":  ("ellipsim.par",  ["ellipsim.out"]),
    "fluvsim":   ("fluvsim.par",   ["fluvsim.out"]),
    "iksim":     ("iksim.par",     ["iksim_ik3d.out"]),
    "anneal":    ("anneal.par",    ["anneal.out"]),
    # Tier 6 - Other utilities
    "gam":       ("gam.par",       ["gam.out"]),
    "varmap":    ("varmap.par",    ["varmap.out"]),
    "newvarmap": ("newvarmap.par", ["newvarmap.out"]),
    "bigaus":    ("bigaus.par",    ["bigaus.out"]),
    "bicalib":   ("bicalib.par",   ["bicalib_run.out", "bicalib_run.cal"]),
    "trans":     ("trans.par",     ["trans.out"]),
    "rotcoord":  ("rotcoord.par",  ["rotcoord.out"]),
    "draw":      ("draw.par",      ["draw.out"]),
    "scatsmth":  ("scatsmth.par",  ["scatsmth.out"]),
    "cokb3d":    ("cokb3d.par",    ["cokb3d.out"]),
    "newcokb3d": ("newcokb3d.par", ["newcokb3d.out"]),
    "dual3d":    ("dual3d.par",    ["dual3d.out"]),
}

results = {}
os.chdir(TESTDIR)

for prog, (parfile, outputs) in PROGRAMS.items():
    # Prefer local patched copy (larger stack) over bin_opt version
    local_exe = os.path.join(TESTDIR, f"{prog}.exe")
    bindir_exe = os.path.join(BINDIR, f"{prog}.exe")
    if os.path.exists(local_exe):
        exe = local_exe
    elif os.path.exists(bindir_exe):
        exe = bindir_exe
    else:
        results[prog] = ("SKIP", "exe not found")
        continue
    if not os.path.exists(parfile):
        results[prog] = ("SKIP", "par file not found")
        continue

    # Remove old output files
    for outf in outputs:
        if os.path.exists(outf):
            os.remove(outf)

    # Run: pipe par file name to stdin
    try:
        proc = subprocess.run(
            f'echo {parfile} | "{exe}"',
            shell=True,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=TESTDIR,
        )
        exitcode = proc.returncode

        # Check outputs
        found = []
        for outf in outputs:
            if os.path.exists(outf) and os.path.getsize(outf) > 0:
                found.append(outf)

        if found:
            sizes = ", ".join(f"{f}={os.path.getsize(f)}B" for f in found)
            results[prog] = ("OK", f"exit={exitcode}, outputs: {sizes}")
        else:
            stderr_snippet = proc.stderr[:200] if proc.stderr else ""
            stdout_snippet = proc.stdout[:200] if proc.stdout else ""
            results[prog] = ("FAIL", f"exit={exitcode}, no output. stderr={stderr_snippet} stdout={stdout_snippet}")

    except subprocess.TimeoutExpired:
        results[prog] = ("FAIL", "TIMEOUT after 120s")
    except Exception as e:
        results[prog] = ("FAIL", f"Exception: {e}")

# Print results
print("\n" + "="*80)
print("GSLIB2 SMOKE TEST RESULTS")
print("="*80)

ok_count = 0
fail_count = 0
skip_count = 0

for prog, (status, detail) in results.items():
    marker = {"OK": "[OK]  ", "FAIL": "[FAIL]", "SKIP": "[SKIP]"}[status]
    print(f"  {marker}  {prog:15s}  {detail}")
    if status == "OK":
        ok_count += 1
    elif status == "FAIL":
        fail_count += 1
    else:
        skip_count += 1

print(f"\nTOTAL: {ok_count} OK, {fail_count} FAIL, {skip_count} SKIP out of {len(PROGRAMS)}")
