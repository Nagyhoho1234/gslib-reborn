"""
Parallel smoke test runner for all 37 GSLIB2 optimized programs.
Launches ALL programs simultaneously using subprocess.Popen.
Each program runs in its own isolated temp directory.
"""
import subprocess
import os
import sys
import shutil
import tempfile
import time
import threading

# Default BINDIR/SRCDIR assume the traditional in-place Windows layout;
# override via env vars for a Linux build (e.g. BINDIR=.../bin_opt_linux)
# or any other build output location, so this one script works for both
# build_all.bat's output and build_all.sh's output without edits.
_ROOT_WIN = r"c:\Codename_EpicFury\gslib2_opt"
BINDIR = os.environ.get("GSLIB_SMOKE_BINDIR", os.path.join(_ROOT_WIN, "bin_opt"))
SRCDIR = os.environ.get("GSLIB_SMOKE_SRCDIR", os.path.join(_ROOT_WIN, "smoke_test"))

# Windows executables carry a .exe suffix; Linux binaries (built by
# build_all.sh) do not.
EXE_SUFFIX = ".exe" if sys.platform == "win32" else ""

# Environment for all programs
ENV = os.environ.copy()
ENV["OMP_STACKSIZE"] = "128M"
ENV["OMP_NUM_THREADS"] = "4"

# Map: program_name -> (par_file, list_of_expected_output_files)
# Excludes gslib_engine.exe (unified engine) and dual3d (no exe in bin_opt)
PROGRAMS = {
    "addcoord":   ("addcoord.par",   ["addcoord.out"]),
    "anneal":     ("anneal.par",     ["anneal.out"]),
    "backtr":     ("backtr.par",     ["backtr.out"]),
    "bicalib":    ("bicalib.par",    ["bicalib_run.out", "bicalib_run.cal"]),
    "bigaus":     ("bigaus.par",     ["bigaus.out"]),
    "cokb3d":     ("cokb3d.par",     ["cokb3d.out"]),
    "declus":     ("declus.par",     ["declus.out", "declus.sum"]),
    "draw":       ("draw.par",       ["draw.out"]),
    "dssim":      ("dssim.par",      ["dssim.out"]),
    "ellipsim":   ("ellipsim.par",   ["ellipsim.out"]),
    "fluvsim":    ("fluvsim.par",    ["fluvsim.out"]),
    "gam":        ("gam.par",        ["gam.out"]),
    "gamv":       ("gamv.par",       ["gamv.out"]),
    "gtsim":      ("gtsim.par",      ["gtsim.out"]),
    "histsmth":   ("histsmth.par",   ["histsmth_run.out"]),
    "ik3d":       ("ik3d.par",       ["ik3d.out"]),
    "iksim":      ("iksim.par",      ["iksim_ik3d.out"]),
    "kb2d":       ("kb2d.par",       ["kb2d.out"]),
    "kt3d":       ("kt3d.par",       ["kt3d.out"]),
    "lusim":      ("lusim.par",      ["lusim.out"]),
    "newcokb3d":  ("newcokb3d.par",  ["newcokb3d.out"]),
    "newvarmap":  ("newvarmap.par",  ["newvarmap.out"]),
    "nscore":     ("nscore.par",     ["nscore_run.out", "nscore_run.trn"]),
    "pfsim":      ("pfsim.par",      ["pfsim.out"]),
    "postik":     ("postik.par",     ["postik.out"]),
    "postsim":    ("postsim.par",    ["postsim.out"]),
    "rotcoord":   ("rotcoord.par",   ["rotcoord.out"]),
    "sasim":      ("sasim.par",      ["sasim.out"]),
    "scatsmth":   ("scatsmth.par",   ["scatsmth.out"]),
    "sgsim":      ("sgsim.par",      ["sgsim_run.out"]),
    "sgsim_fc":   ("sgsim_fc.par",   ["sgsim_fc.out"]),
    "sisim":      ("sisim.par",      ["sisim_run.out"]),
    "sisim_gs":   ("sisim_gs.par",   ["sisim_gs.out"]),
    "sisim_lm":   ("sisim_lm.par",   ["sisim_lm.out"]),
    "trans":      ("trans.par",      ["trans.out"]),
    "varmap":     ("varmap.par",     ["varmap.out"]),
    "vmodel":     ("vmodel.par",     ["vmodel.var"]),
}

TIMEOUT = 30  # seconds per program


def run_program(prog, parfile, expected_outputs, exe, workdir):
    """Run a single GSLIB program in its own working directory."""
    result = {}
    t0 = time.perf_counter()
    try:
        proc = subprocess.Popen(
            [exe],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=workdir,
            env=ENV,
        )
        try:
            stdout, stderr = proc.communicate(
                input=f"{parfile}\n".encode(), timeout=TIMEOUT
            )
            elapsed = time.perf_counter() - t0
            exitcode = proc.returncode

            # Check for expected output files
            found = []
            for outf in expected_outputs:
                fpath = os.path.join(workdir, outf)
                if os.path.exists(fpath) and os.path.getsize(fpath) > 0:
                    found.append((outf, os.path.getsize(fpath)))

            if found:
                sizes = ", ".join(f"{f}={sz}B" for f, sz in found)
                result = {
                    "status": "PASS",
                    "detail": f"exit={exitcode}, outputs: {sizes}",
                    "elapsed": elapsed,
                }
            else:
                stderr_snip = stderr.decode("utf-8", errors="replace")[:200]
                stdout_snip = stdout.decode("utf-8", errors="replace")[:200]
                result = {
                    "status": "FAIL",
                    "detail": f"exit={exitcode}, no output. stderr={stderr_snip}",
                    "elapsed": elapsed,
                }

        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate()
            elapsed = time.perf_counter() - t0
            result = {
                "status": "TIMEOUT",
                "detail": f"killed after {TIMEOUT}s",
                "elapsed": elapsed,
            }

    except Exception as e:
        elapsed = time.perf_counter() - t0
        result = {
            "status": "FAIL",
            "detail": f"Exception: {e}",
            "elapsed": elapsed,
        }
    return result


def main():
    # Create a master temp directory
    master_tmp = tempfile.mkdtemp(prefix="gslib_smoke_")
    print(f"Working directory: {master_tmp}")
    print(f"Programs to test: {len(PROGRAMS)}")
    print(f"Timeout per program: {TIMEOUT}s")
    print(f"OMP_NUM_THREADS={ENV.get('OMP_NUM_THREADS')}, OMP_STACKSIZE={ENV.get('OMP_STACKSIZE')}")
    print()

    # Collect all source files to copy (everything in smoke_test dir that
    # programs might need: .dat, .out, .trn, .cal, .ps, .geo, .xr, .yr, etc.)
    src_files = []
    for f in os.listdir(SRCDIR):
        fpath = os.path.join(SRCDIR, f)
        if os.path.isfile(fpath) and not f.endswith(('.exe', '.dll', '.bat', '.py')):
            src_files.append(f)

    # Prepare per-program directories and launch all processes
    processes = {}
    workdirs = {}

    t_start = time.perf_counter()

    for prog, (parfile, expected_outputs) in PROGRAMS.items():
        # Find executable
        exe = os.path.join(BINDIR, f"{prog}{EXE_SUFFIX}")
        if not os.path.exists(exe):
            processes[prog] = None
            workdirs[prog] = None
            continue

        # Check par file exists in source
        par_src = os.path.join(SRCDIR, parfile)
        if not os.path.exists(par_src):
            processes[prog] = None
            workdirs[prog] = None
            continue

        # Create isolated work directory
        wdir = os.path.join(master_tmp, prog)
        os.makedirs(wdir)
        workdirs[prog] = wdir

        # Copy all source files into this directory
        for f in src_files:
            src = os.path.join(SRCDIR, f)
            dst = os.path.join(wdir, f)
            shutil.copy2(src, dst)

        # Remove old expected outputs so we can detect fresh creation
        for outf in expected_outputs:
            outpath = os.path.join(wdir, outf)
            if os.path.exists(outpath):
                os.remove(outpath)

    # Now launch ALL programs in parallel using threads that each use Popen
    from concurrent.futures import ThreadPoolExecutor, as_completed

    results = {}
    futures = {}

    with ThreadPoolExecutor(max_workers=len(PROGRAMS)) as executor:
        for prog, (parfile, expected_outputs) in PROGRAMS.items():
            exe = os.path.join(BINDIR, f"{prog}{EXE_SUFFIX}")
            wdir = workdirs.get(prog)

            if not os.path.exists(exe):
                results[prog] = {
                    "status": "SKIP",
                    "detail": "exe not found",
                    "elapsed": 0,
                }
                continue

            par_src = os.path.join(SRCDIR, parfile)
            if not os.path.exists(par_src):
                results[prog] = {
                    "status": "SKIP",
                    "detail": "par file not found",
                    "elapsed": 0,
                }
                continue

            future = executor.submit(
                run_program, prog, parfile, expected_outputs, exe, wdir
            )
            futures[future] = prog

        # Collect results as they complete
        for future in as_completed(futures):
            prog = futures[future]
            try:
                results[prog] = future.result()
            except Exception as e:
                results[prog] = {
                    "status": "FAIL",
                    "detail": f"Thread exception: {e}",
                    "elapsed": 0,
                }

    t_total = time.perf_counter() - t_start

    # Print results sorted by program name
    print()
    print("=" * 90)
    print("GSLIB2 PARALLEL SMOKE TEST RESULTS")
    print("=" * 90)

    pass_count = 0
    fail_count = 0
    timeout_count = 0
    skip_count = 0

    for prog in sorted(results.keys()):
        r = results[prog]
        status = r["status"]
        elapsed = r["elapsed"]
        detail = r["detail"]

        if status == "PASS":
            marker = "[PASS]   "
            pass_count += 1
        elif status == "TIMEOUT":
            marker = "[TIMEOUT]"
            timeout_count += 1
        elif status == "SKIP":
            marker = "[SKIP]   "
            skip_count += 1
        else:
            marker = "[FAIL]   "
            fail_count += 1

        print(f"  {marker}  {prog:15s}  ({elapsed:5.1f}s)  {detail}")

    print()
    print("-" * 90)
    print(
        f"  TOTALS: {pass_count} PASS, {fail_count} FAIL, "
        f"{timeout_count} TIMEOUT, {skip_count} SKIP  "
        f"(out of {len(PROGRAMS)} programs)"
    )
    print(f"  Wall-clock time: {t_total:.1f}s")
    print(f"  Temp directory: {master_tmp}")
    print("=" * 90)

    # Clean up temp directory
    try:
        shutil.rmtree(master_tmp)
        print(f"  Cleaned up temp directory.")
    except Exception as e:
        print(f"  Warning: could not clean up {master_tmp}: {e}")

    # Return exit code
    if fail_count + timeout_count > 0:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
