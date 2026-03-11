# GSLIB Reborn

### Codename: *Anisotropy Assassin* — v2026.1

---

> ## **ORIGINAL AUTHORS & ACKNOWLEDGEMENT**
>
> **This project is entirely based on the work of the original GSLIB authors.**
> All intellectual credit belongs to them. This repository contains only
> minor build and performance optimizations for modern (2026-era) hardware.
>
> ### **Clayton V. Deutsch** & **André G. Journel**
> *Stanford University, Stanford Center for Reservoir Forecasting*
>
> **GSLIB: Geostatistical Software Library and User's Guide**
> Second Edition, Oxford University Press, 1998
> ISBN: 978-0-19-510015-0
>
> The **original, unmodified GSLIB source code** is available at:
> **[http://www.gslib.com](http://www.gslib.com)**
>
> *If you use any of these programs in your research, please cite the
> original GSLIB book by Deutsch & Journel — not this repository.*

---

## What is this?

This is **not** a new geostatistical library. This is a straightforward
recompilation and optimization of the classic **GSLIB2** programs for
modern 64-bit systems with large memory. The original Fortran source code
by Deutsch & Journel remains essentially unchanged — the modifications are
limited to:

- 64-bit compilation with Intel oneAPI ifx (2025.3)
- Heap-based array allocation to remove legacy size limits
- OpenMP-ready builds (static and dynamic linking)
- Increased parameter limits (e.g., MAXDAT up to 5,000,000)
- Conversion of selected COMMON blocks to Fortran 90 allocatable arrays
- Minor I/O optimizations (e.g., single-pass reads in nscore)
- Two additional output-format variants (backtr2, addcoord2, postsim2)

**The algorithms, mathematics, and geostatistical methods are 100% the work
of Deutsch & Journel.** My contribution is purely mechanical — making these
proven programs run efficiently on 2026-era hardware.

## Key Optimizations

| Program | Change | Result |
|---------|--------|--------|
| iksim | COMMON blocks → allocatable arrays | Exe: 1.5 GB → 965 KB (99.94% reduction) |
| anneal | COMMON blocks → allocatable arrays | Exe: 97 MB → 751 KB (99.2% reduction) |
| nscore | Single-pass I/O, allocatable arrays | Eliminated backspace/re-read pattern |
| All 41 | Heap arrays, 16 GB stack reservation | No stack overflow on large datasets |

## Build Configurations

| Config | Script | Output | Notes |
|--------|--------|--------|-------|
| Static OpenMP | `build_all.bat` | `bin_opt/` (~41 MB) | Standalone, no DLL dependencies |
| Dynamic OpenMP | `build_all_dynamic.bat` | `bin_opt2/` (~35 MB) | Requires `libiomp5md.dll` (included) |

**Compiler:** Intel oneAPI ifx 2025.3, 64-bit
**Flags:** `/O2 /heap-arrays0 /F17179869184 /Qopenmp`

## Programs Included (41 total)

### Kriging & Estimation
`kt3d` · `kb2d` · `ik3d` · `dual3d` · `cokb3d` · `newcokb3d`

### Simulation
`sgsim` · `sgsim_fc` · `sisim` · `sisim_gs` · `sisim_lm` · `dssim` · `lusim` · `gtsim` · `pfsim` · `sasim` · `ellipsim` · `fluvsim` · `iksim` · `anneal`

### Data Transformation & Utilities
`backtr` · `backtr2` · `nscore` · `trans` · `histsmth` · `bicalib` · `bigaus`

### Variography
`gamv` · `gam` · `varmap` · `newvarmap` · `vmodel`

### Post-processing & Coordinates
`declus` · `postik` · `postsim` · `postsim2` · `addcoord` · `addcoord2` · `rotcoord` · `scatsmth` · `draw`

### Plotting (PostScript)
`histplt` · `probplt` · `qpplt` · `scatplt` · `locmap` · `pixelplt` · `vargplt` · `bivplt`

## Enhanced by

**Zsolt Zoltán Fehér**
University of Debrecen, Hungary
ORCID: [0009-0007-6659-4197](https://orcid.org/0009-0007-6659-4197)

*Minor optimizations and 64-bit recompilation only.
All geostatistical methods are the original work of Deutsch & Journel.*

## License

The original GSLIB code is distributed by its authors at [gslib.com](http://www.gslib.com).
Please refer to the original distribution for licensing terms.

## How to Cite

If you use these programs, **please cite the original work**:

> Deutsch, C.V. and Journel, A.G., 1998. *GSLIB: Geostatistical Software
> Library and User's Guide.* Second Edition. Oxford University Press, New York.
> 369 pp. ISBN 978-0-19-510015-0.
