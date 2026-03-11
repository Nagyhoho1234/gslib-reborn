"""
Update branding to include program name in banner.
"""
import re, os

ROOT = r"c:\Codename_EpicFury\gslib2_opt"

# Map (subdir, filename) -> display name for banner
SOURCES = [
    ("kt3d",       "kt3d.f",       "KT3D"),
    ("kb2d",       "kb2d.f",       "KB2D"),
    ("ik3d",       "ik3d.f",       "IK3D"),
    ("dual3d",     "dual.f",       "DUAL3D"),
    ("cokb3d",     "newcokb3d.f",  "COKB3D"),
    ("newcokb3d",  "newcokb3d.f",  "NEWCOKB3D"),
    ("sgsim",      "sgsim.f",      "SGSIM"),
    ("sgsim_fc",   "sgsim_fc.f",   "SGSIM_FC"),
    ("sisim",      "sisim.f",      "SISIM"),
    ("sisim_gs",   "sisim_gs.f",   "SISIM_GS"),
    ("sisim_lm",   "sisim_lm.f",   "SISIM_LM"),
    ("dssim",      "dssim.f",      "DSSIM"),
    ("lusim",      "lusim.f",      "LUSIM"),
    ("gtsim",      "gtsim.f",      "GTSIM"),
    ("pfsim",      "pfsim.f",      "PFSIM"),
    ("sasim",      "sasim.f",      "SASIM"),
    ("ellipsim",   "ellipsim.f",   "ELLIPSIM"),
    ("fluvsim",    "fluvsim.f",    "FLUVSIM"),
    ("iksim",      "iksim.f",      "IKSIM"),
    ("anneal",     "anneal.f",     "ANNEAL"),
    ("backtr",     "backtr.f",     "BACKTR"),
    ("backtr",     "backtr2.f",    "BACKTR2"),
    ("nscore",     "nscore.f",     "NSCORE"),
    ("trans",      "trans.f",      "TRANS"),
    ("histsmth",   "histsmth.f",   "HISTSMTH"),
    ("bicalib",    "bicalib.f",    "BICALIB"),
    ("bigaus",     "bigaus.f",     "BIGAUS"),
    ("gamv",       "gamv.f",       "GAMV"),
    ("gam",        "gam.f",        "GAM"),
    ("varmap",     "varmap.f",     "VARMAP"),
    ("newvarmap",  "newvarmap.f",  "NEWVARMAP"),
    ("vmodel",     "vmodel.f",     "VMODEL"),
    ("declus",     "declus.f",     "DECLUS"),
    ("postik",     "postik.f",     "POSTIK"),
    ("postsim",    "postsim.f",    "POSTSIM"),
    ("postsim",    "postsim2.f",   "POSTSIM2"),
    ("addcoord",   "addcoord.f",   "ADDCOORD"),
    ("addcoord",   "addcoord2.f",  "ADDCOORD2"),
    ("rotcoord",   "rotcoord.f",   "ROTCOORD"),
    ("scatsmth",   "scatsmth.f",   "SCATSMTH"),
    ("draw",       "draw.f",       "DRAW"),
]

updated = 0

for subdir, fname, progname in SOURCES:
    fpath = os.path.join(ROOT, subdir, fname)
    if not os.path.isfile(fpath):
        print(f"  SKIP {subdir}/{fname}")
        continue

    with open(fpath, 'r', encoding='latin-1') as f:
        text = f.read()

    orig = text

    # Replace the 9999 format block (may span multiple lines with continuation)
    # Match from " 9999 format(" to the closing "/)"
    new_banner = (
        f" 9999 format(/' {progname} - GSLIB2-OPT v',f7.1,"
        f"' (64-bit, OpenMP)'/\n"
        f"     +' Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)'/\n"
        f"     +' Enhanced: Zs.Z. Feher, U.Debrecen',\n"
        f"     +' ORCID:0009-0007-6659-4197'/)"
    )

    # Replace the multi-line 9999 format block
    text = re.sub(
        r" 9999 format\(.*?ORCID:0009-0007-6659-4197'\s*/\)",
        new_banner,
        text,
        flags=re.DOTALL
    )

    # Replace the 9998 format with program name
    new_finished = f" 9998 format(/' {progname} - GSLIB2-OPT v',f7.1, ' Finished'/)"
    text = re.sub(
        r" 9998 format\(/' GSLIB2-OPT v',f7\.1, ' Finished'/\)",
        new_finished,
        text
    )

    if text != orig:
        # Check line lengths
        for line in text.split('\n'):
            if '9999 format' in line or '9998 format' in line:
                if len(line.rstrip()) > 72:
                    print(f"  WARN {subdir}/{fname}: line too long ({len(line.rstrip())}): {line.rstrip()[:80]}")
        with open(fpath, 'w', encoding='latin-1') as f:
            f.write(text)
        print(f"  OK   {subdir}/{fname} -> {progname}")
        updated += 1
    else:
        print(f"  SKIP {subdir}/{fname} - no match")

print(f"\nUpdated: {updated}")
