# staggered-did-replication

Replication exercise comparing heterogeneity-robust difference-in-differences estimators under staggered treatment adoption.

**Gabriela Villalba** | PhD Candidate in Economics, University of Sussex
`g.villalba-marecos@sussex.ac.uk`

---

## Overview

In staggered adoption designs — where units receive treatment at different points in time — the standard two-way fixed effects (TWFE) OLS estimator can be biased when treatment effects are heterogeneous across cohorts or time. This exercise implements and compares four modern estimators that are robust to this issue, alongside TWFE as a benchmark.

The empirical setting follows Callaway & Sant'Anna (2021): US counties observed 2001–2007, where treatment is the adoption of a state-level minimum wage increase above the federal floor and the outcome is log county-level teen employment. The dataset (`mpdta`) is publicly available and ships with the `csdid` Stata package.

---

## Script

### `01_did_staggered_minimumwage.do`

Loads the public dataset directly from GitHub, runs all five estimators, and produces individual and combined event-study plots.

| Estimator | Method | Package |
|---|---|---|
| Borusyak, Jaravel & Spiess (2021) | Imputation | `did_imputation` |
| de Chaisemartin & D'Haultfoeuille (2024) | First-difference | `did_multiplegt_dyn` |
| Callaway & Sant'Anna (2021) | Group-time ATTs | `csdid` |
| Sun & Abraham (2021) | Interaction-weighted | `eventstudyinteract` |
| TWFE OLS (benchmark) | Two-way FE | `reghdfe` |

---

## Reference

Callaway, B. & Sant'Anna, P. (2021). Difference-in-differences with multiple time periods. *Journal of Econometrics*, 225(2), 200–230.

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

The dataset is loaded directly from GitHub — no manual download needed.
