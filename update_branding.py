"""
Mass-update VERSION number and author branding across all GSLIB2-OPT programs.
"""
import re, os

ROOT = r"c:\Codename_EpicFury\gslib2_opt"

# All source files that get compiled into bin_opt (from build_all.bat)
SOURCES = [
    ("kt3d",       "kt3d.f"),
    ("kb2d",       "kb2d.f"),
    ("ik3d",       "ik3d.f"),
    ("dual3d",     "dual.f"),
    ("cokb3d",     "newcokb3d.f"),
    ("newcokb3d",  "newcokb3d.f"),
    ("sgsim",      "sgsim.f"),
    ("sgsim_fc",   "sgsim_fc.f"),
    ("sisim",      "sisim.f"),
    ("sisim_gs",   "sisim_gs.f"),
    ("sisim_lm",   "sisim_lm.f"),
    ("dssim",      "dssim.f"),
    ("lusim",      "lusim.f"),
    ("gtsim",      "gtsim.f"),
    ("pfsim",      "pfsim.f"),
    ("sasim",      "sasim.f"),
    ("ellipsim",   "ellipsim.f"),
    ("fluvsim",    "fluvsim.f"),
    ("iksim",      "iksim.f"),
    ("anneal",     "anneal.f"),
    ("backtr",     "backtr.f"),
    ("backtr",     "backtr2.f"),
    ("nscore",     "nscore.f"),
    ("trans",      "trans.f"),
    ("histsmth",   "histsmth.f"),
    ("bicalib",    "bicalib.f"),
    ("bigaus",     "bigaus.f"),
    ("gamv",       "gamv.f"),
    ("gam",        "gam.f"),
    ("varmap",     "varmap.f"),
    ("newvarmap",  "newvarmap.f"),
    ("vmodel",     "vmodel.f"),
    ("declus",     "declus.f"),
    ("postik",     "postik.f"),
    ("postsim",    "postsim.f"),
    ("postsim",    "postsim2.f"),
    ("addcoord",   "addcoord.f"),
    ("addcoord",   "addcoord2.f"),
    ("rotcoord",   "rotcoord.f"),
    ("scatsmth",   "scatsmth.f"),
    ("draw",       "draw.f"),
]

# VERSION as real parameter: must fit f7.1 format (e.g., " 2026.1")
NEW_VERSION = "2026.1"

updated = 0
skipped = 0

for subdir, fname in SOURCES:
    fpath = os.path.join(ROOT, subdir, fname)
    if not os.path.isfile(fpath):
        print(f"  SKIP {subdir}/{fname} - not found")
        skipped += 1
        continue

    with open(fpath, 'r') as f:
        text = f.read()

    orig = text

    # 1. Update VERSION parameter value
    #    Match patterns like VERSION=2.191) or VERSION=2.000) or VERSION=2.200)
    text = re.sub(
        r'VERSION\s*=\s*[\d.]+\)',
        f'VERSION={NEW_VERSION})',
        text
    )

    # 2. Update the start banner (label 9999)
    #    Various patterns:
    #    format(/' PROGNAME Version: ',f5.3/)
    #    format(/' PROGNAME Version: ',f5.3,' (Optimized)'/)
    #    format(/' ADDCOORD for Surfer Version: ',f5.3/)
    #    format(/' Dual Kriging Version: ',f5.3, ' Finished'/)
    #    Replace with unified branding using f7.1 for 2026.1
    text = re.sub(
        r"( 9999 format\().*?\)\s*$",
        r""" 9999 format(/' GSLIB2-OPT v',f7.1,' (64-bit, OpenMP)'/
     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/
     +' Enhanced: Zs.Z. Feher, U.Debrecen',
     +' ORCID:0009-0007-6659-4197'/)""",
        text,
        flags=re.MULTILINE
    )

    # 3. Update the finished banner (label 9998)
    #    format(/' PROGNAME Version: ',f5.3, ' Finished'/)
    #    Replace with simple version finished
    text = re.sub(
        r"( 9998 format\().*?\)\s*$",
        r" 9998 format(/' GSLIB2-OPT v',f7.1, ' Finished'/)",
        text,
        flags=re.MULTILINE
    )

    # 4. Update the write statement to use correct format specifier
    #    The VERSION parameter is now a larger number, need f7.1 not f5.3
    #    But the write(*,9999) VERSION calls don't need changing - they just pass VERSION

    if text != orig:
        with open(fpath, 'w') as f:
            f.write(text)
        print(f"  OK   {subdir}/{fname}")
        updated += 1
    else:
        print(f"  SKIP {subdir}/{fname} - no changes")
        skipped += 1

print(f"\nUpdated: {updated}, Skipped: {skipped}")
