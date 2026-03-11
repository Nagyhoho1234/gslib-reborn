# GSLIB2-OPT Changelog

## Version 2026.1

### Author & Credits
- **Enhanced by:** Zs.Z. Feher, University of Debrecen (ORCID: 0009-0007-6659-4197)
- **Original GSLIB:** C.V. Deutsch & A.G. Journel, Stanford University

### Overview
GSLIB2-OPT is a modernized, optimized build of the GSLIB geostatistical library.
All 41 programs have been updated for 64-bit compilation with Intel oneAPI ifx,
with performance optimizations, increased capacity, and two distribution modes.

---

### Build System
- Two build configurations:
  - `build_all.bat` - Static OpenMP linking (`/Qopenmp-link:static`), standalone executables in `bin_opt/` (~41 MB total)
  - `build_all_dynamic.bat` - Dynamic OpenMP linking, shared `libiomp5md.dll` in `bin_opt2/` (~35 MB total)
- Compiler: Intel oneAPI ifx 2025.3, 64-bit
- Flags: `/O2 /heap-arrays0 /F17179869184` (16 GB stack reservation)
- Shared library: `gslib/libgs.lib` built from 37 GSLIB subroutine source files

### Branding & Version
- Unified version number `2026.1` across all 41 programs (both `.f` and `.inc` files)
- Startup banner displays program name, version, and credits:
  ```
  SGSIM - GSLIB2-OPT v 2026.1 (64-bit, OpenMP)
  Original GSLIB: C.V. Deutsch & A.G. Journel (Stanford)
  Enhanced: Zs.Z. Feher, U.Debrecen ORCID:0009-0007-6659-4197
  ```
- Completion banner: `SGSIM - GSLIB2-OPT v 2026.1 Finished`

### Performance & Memory Optimizations

#### Dynamic Memory Allocation (iksim, anneal)
- **iksim**: Converted COMMON blocks to Fortran 90 module (`iksim_mod.f90`)
  - Large arrays (`pass`, `vr`, `x`, `y`, `z`, `closestData`, `variance`, etc.) are now `allocatable`
  - Allocated at runtime proportional to actual grid size, not compile-time maximums
  - Exe size reduced from **1.5 GB to 965 KB** (99.94% reduction)
  - Parameters restored to full capacity: MAXDAT=5,000,000, grid 500x500x100
- **anneal**: Converted COMMON blocks to Fortran 90 module (`anneal_mod.f90`)
  - Grid array `var(nx,ny,nz)` is now `allocatable`
  - Exe size reduced from **97 MB to 751 KB** (99.2% reduction)
  - Parameters restored to full capacity: grid 500x500x100

#### nscore Optimization
- Eliminated backspace/re-read I/O pattern - all data read into memory in single pass
- Output written in single buffered pass
- Converted static `lines`/`lostr`/`outval` arrays to `allocatable` (fixed COFF 2 GB data section limit)
- MAXDAT increased from 500,000 to 5,000,000

### Dual Output Format Programs

Three programs now have two versions each - the default (original format) and a "2" variant:

#### backtr / backtr2
- **backtr** (default): Original GSLIB format - outputs all original columns plus back-transformed value (nvari+1 columns)
- **backtr2**: Simplified format - outputs only the back-transformed value (1 column)

#### addcoord / addcoord2
- **addcoord** (default): Original single-line header format matching gslib2
- **addcoord2**: GIS-compatible format with proper GSLIB header structure (title line, ncols, variable names on separate lines)

#### postsim / postsim2
- **postsim** (default): Original GSLIB format - always outputs E-type mean and variance (2 columns), grid dimensions in header
- **postsim2**: Simplified format - outputs only the selected statistic (1 column)

### Programs Included (41 total)

#### Kriging & Estimation
| Program | Description |
|---------|-------------|
| kt3d | Kriging 3-D |
| kb2d | Kriging 2-D |
| ik3d | Indicator Kriging 3-D |
| dual3d | Dual Kriging 3-D |
| cokb3d | Cokriging 3-D |
| newcokb3d | New Cokriging 3-D |

#### Simulation
| Program | Description |
|---------|-------------|
| sgsim | Sequential Gaussian Simulation |
| sgsim_fc | Sequential Gaussian Simulation (full covariance) |
| sisim | Sequential Indicator Simulation |
| sisim_gs | Sequential Indicator Simulation (Gaussian smoothing) |
| sisim_lm | Sequential Indicator Simulation (local mean) |
| dssim | Direct Sequential Simulation |
| lusim | LU Decomposition Simulation |
| gtsim | Gaussian Truncation Simulation |
| pfsim | P-field Simulation |
| sasim | Simulated Annealing Simulation |
| ellipsim | Ellipsoidal Simulation |
| fluvsim | Fluvial Simulation |
| iksim | Indicator Kriging + Simulation (IK3D + POSTIK + PFSIMFFT + TRANS) |
| anneal | Simulated Annealing Post-processing |

#### Data Transformation & Utilities
| Program | Description |
|---------|-------------|
| backtr | Back-transform (original format) |
| backtr2 | Back-transform (simplified) |
| nscore | Normal Score Transform |
| trans | Distribution Transform |
| histsmth | Histogram Smoothing |
| bicalib | Bivariate Calibration |
| bigaus | Bivariate Gaussian |

#### Variography
| Program | Description |
|---------|-------------|
| gamv | Variogram Calculation |
| gam | Variogram Calculation (alternative) |
| varmap | Variogram Map |
| newvarmap | New Variogram Map |
| vmodel | Variogram Model |

#### Post-processing & Utilities
| Program | Description |
|---------|-------------|
| declus | Declustering |
| postik | Post-process IK distributions |
| postsim | Post-process simulations (original format) |
| postsim2 | Post-process simulations (simplified) |
| addcoord | Add coordinates (original format) |
| addcoord2 | Add coordinates (GIS-compatible) |
| rotcoord | Rotate coordinates |
| scatsmth | Scatter smoothing |
| draw | Drawing utility |

### Technical Notes
- All programs use `/heap-arrays0` to place arrays on the heap, preventing stack overflow with large datasets
- Stack reservation set to 16 GB (`/F17179869184`) for deep recursion safety
- Static OpenMP build (`bin_opt/`) produces standalone executables requiring no runtime DLLs
- Dynamic build (`bin_opt2/`) requires `libiomp5md.dll` (included) but produces smaller individual executables
