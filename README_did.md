# staggered-did-replication

Replication exercise comparing heterogeneity-robust difference-in-differences estimators under staggered treatment adoption, using simulated data.

**Gabriela Villalba** | PhD Candidate in Economics, University of Sussex
`g.villalba-marecos@sussex.ac.uk`

---

## Overview

In staggered adoption designs — where units receive treatment at different points in time — the standard two-way fixed effects (TWFE) OLS estimator can be biased when treatment effects are heterogeneous across cohorts or time. This repository demonstrates the problem and implements four modern estimators that are robust to this issue.

The data are fully simulated with a known true treatment effect (ATT = 0.12 sd), which allows direct validation of each estimator's performance.

---

## Repository structure

```
staggered-did-replication/
├── 01_did_simulation.do          # DGP, OLS/IV, and CS event-study
├── 02_estimators_comparison.do   # Five-estimator comparison and combined plot
└── data/                         # Created at runtime (gitignored)
```

---

## Scripts

### `04_did_simulation.do`

Generates a synthetic panel (200 units × 9 periods) with staggered treatment adoption. An eligibility rule at baseline serves as an instrument for treatment timing. Estimates OLS and IV specifications and runs a Callaway & Sant'Anna (2021) event-study with subgroup heterogeneity analysis.

### `05_estimators_comparison.do`

Implements all five estimators on the same simulated dataset and plots them together using `event_plot` for direct comparison.

| Estimator | Package |
|---|---|
| Borusyak, Jaravel & Spiess (2021) | `did_imputation` |
| de Chaisemartin & D'Haultfoeuille (2024) | `did_multiplegt_dyn` |
| Callaway & Sant'Anna (2021) | `csdid` |
| Sun & Abraham (2021) | `eventstudyinteract` |
| TWFE OLS (benchmark) | `reghdfe` |

---

## Requirements

Stata ≥ v15. Install packages once:

```stata
ssc install csdid
ssc install did_imputation
ssc install did_multiplegt_dyn
ssc install eventstudyinteract
ssc install avar
ssc install reghdfe
ssc install event_plot
ssc install coefplot
```

Run `04_did_simulation.do` first, then `05_estimators_comparison.do`.
