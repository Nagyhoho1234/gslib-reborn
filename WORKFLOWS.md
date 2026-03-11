# GSLIB2 Simulation Workflows — Book Reference (Deutsch & Journel, 2nd Ed.)

## 1. SGSIM (Sequential Gaussian Simulation) — Ch.V.2.3
```
DECLUS → HISTSMTH → NSCORE(ref=histsmth.out) → GAMV(on normal scores) → SGSIM → BACKTR → POSTSIM → ADDCOORD
```
- SGSIM can do its own nscore+backtr internally with `itrans=1` and a ref dist file
- Minimal: DECLUS → HISTSMTH → GAMV(nscore) → SGSIM(itrans=1) → POSTSIM
- Variogram must be fitted on NORMAL SCORES, not original data
- Nugget + sill must sum to 1.0

## 2. SISIM (Sequential Indicator Simulation) — Ch.V.3
```
DECLUS → GAMV(indicator variograms, raw data) → SISIM → POSTIK/POSTSIM → ADDCOORD
```
- NO nscore, NO histsmth, NO backtr
- Indicator variograms computed on RAW data at each threshold
- Indicator variogram sills = p*(1-p) for each threshold probability
- Within-class interpolation via ltail/middle/utail options

## 3. SISIM_GS (with Gridded Secondary) — Ch.V.8.1
```
DECLUS → GAMV(indicator) → BICALIB → SISIM_GS → POSTSIM
```
- BICALIB calibrates soft indicator data from secondary variable

## 4. SISIM_LM (with Local Means) — Ch.V.8.1
```
DECLUS → GAMV(indicator) → SISIM_LM(+prior mean file) → POSTSIM
```

## 5. LUSIM (LU Decomposition) — Ch.V.2.4
```
DECLUS → HISTSMTH → NSCORE → LUSIM → BACKTR → POSTSIM
```
- LUSIM does NOT do internal transform — external NSCORE+BACKTR required
- Small grids only (n+N ≤ few hundred)

## 6. GTSIM (Truncated Gaussian) — Ch.V.2.6
```
[SGSIM workflow] → GTSIM
```
- GTSIM is a POST-PROCESSOR — takes SGSIM Gaussian output and truncates into K categories
- Not standalone

## 7. PFSIM (p-Field Simulation) — Ch.V.4
```
Track A: IK3D or KT3D → conditional distributions
Track B: SGSIM(unconditional) → p-field probabilities
→ PFSIM(ccdfs + p-field) → POSTSIM
```
- Two independent inputs combined by PFSIM
- ccdfs conditioned on original data only (not sequentially updated)

## 8. SASIM (Simulated Annealing) — Ch.V.6.1
```
DECLUS → HISTSMTH → GAMV → SASIM → POSTSIM
```
- No nscore needed — works on original or log-transformed data
- Objective function: histogram + variogram + indicator variograms + correlation + conditional dists

## 9. ANNEAL (Annealing Post-Processor) — Ch.V.6.2
```
SISIM or ELLIPSIM → ANNEAL
```
- Post-processes categorical realizations to match training image two-point histograms

## 10. ELLIPSIM (Boolean) — Ch.V.5
```
ELLIPSIM (standalone)
```
- No preprocessing needed

## 11. DSSIM (Direct Sequential Simulation) — gslib2 extra
```
DECLUS → HISTSMTH → GAMV(on raw data) → DSSIM → POSTSIM
```
- Works on ORIGINAL-scale data (not Gaussian)
- No NSCORE, no BACKTR

## 12. IKSIM (Indicator Kriging Simulation) — gslib2 extra
```
DECLUS → GAMV(indicator) → IKSIM → POSTIK → POSTSIM
```

## 13. FLUVSIM (Fluvial) — gslib2 extra
```
FLUVSIM (standalone, geometric parameters)
```

## 14. SGSIM_FC (Full Covariance SGSIM) — gslib2 extra
Same workflow as SGSIM (#1) but uses full covariance matrix.

---

## Common Pre/Post-Processing Programs

| Program | Purpose | When to use |
|---------|---------|-------------|
| DECLUS | Declustering weights | Always with clustered data |
| HISTSMTH | Smooth histogram | Before NSCORE (ref dist), SASIM (target) |
| NSCORE | Normal score transform | Before SGSIM, LUSIM (Gaussian methods) |
| GAMV | Experimental variogram | Before all simulation (on appropriate data) |
| VMODEL | Verify variogram model | After fitting model to GAMV output |
| BACKTR | Back-transform Gaussian→original | After SGSIM/LUSIM (if not itrans=1) |
| POSTSIM | Post-process realizations | After any simulation (E-type, prob, quantiles) |
| POSTIK | Post-process IK distributions | After SISIM, IKSIM, IK3D |
| ADDCOORD | Add x,y,z to grid output | After any gridded simulation |
| BICALIB | Calibrate soft indicators | Before SISIM_GS (Markov-Bayes) |
| TRANS | General distribution transform | Post-process to match target histogram exactly |
