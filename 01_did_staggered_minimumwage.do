/*******************************************************************************
* 01_did_staggered_minimumwage.do
* ─────────────────────────────────────────────────────────────────────────────
* Replication exercise: heterogeneity-robust DiD estimators under staggered
* adoption, using the minimum wage and employment dataset from
* Callaway & Sant'Anna (2021).
*
* Setting
* -------
* US counties observed 2001–2007. Treatment is the adoption of a state-level
* minimum wage increase above the federal floor. Outcome is log county-level
* teen employment. Counties in states that never raised the minimum wage
* serve as the comparison group.
*
* This dataset ships with the csdid package (Stata) and is the empirical
* application used in the original Callaway & Sant'Anna (2021) paper.
*
* Estimators compared
* -------------------
* 1. Borusyak, Jaravel & Spiess (2021)        — did_imputation
* 2. de Chaisemartin & D'Haultfoeuille (2024)  — did_multiplegt_dyn
* 3. Callaway & Sant'Anna (2021)               — csdid
* 4. Sun & Abraham (2021)                      — eventstudyinteract
* 5. TWFE OLS (benchmark)                      — reghdfe
*
* Reference
* ---------
* Callaway, B. & Sant'Anna, P. (2021). Difference-in-differences with
* multiple time periods. Journal of Econometrics, 225(2), 200–230.
*
* Author  : Gabriela Villalba (g.villalba-marecos@sussex.ac.uk)
* Updated : March 2026
*
* Required packages (install once):
*   ssc install csdid
*   ssc install did_imputation
*   ssc install did_multiplegt_dyn
*   ssc install eventstudyinteract
*   ssc install avar
*   ssc install reghdfe
*   ssc install event_plot
*   ssc install coefplot
*******************************************************************************/

clear all
set more off
version 17

*──────────────────────────────────────────────────────────────────────────────
* 1. Load data
*    mpdta ships with csdid — no download needed after: ssc install csdid
*──────────────────────────────────────────────────────────────────────────────

use "https://raw.githubusercontent.com/friosavila/csdid/main/test/mpdta.dta", clear

* Key variables:
*   countyreal  — county identifier
*   year        — calendar year (2001–2007)
*   first_treat — year of first minimum wage increase (0 = never treated)
*   lemp        — log teen employment (outcome)
*   lpop        — log county population (control)

label var countyreal  "County identifier"
label var year        "Calendar year"
label var first_treat "First year of minimum wage increase (0 = never treated)"
label var lemp        "Log teen employment"
label var lpop        "Log county population"

* Quick look
describe
summarize
tabulate first_treat

*──────────────────────────────────────────────────────────────────────────────
* 2. Panel setup
*──────────────────────────────────────────────────────────────────────────────

xtset countyreal year

* Post-treatment indicator (for did_multiplegt_dyn)
gen D = (year >= first_treat) if first_treat > 0
replace D = 0 if missing(D)
label var D "Treated (year >= first_treat)"

* Relative time to treatment
gen K = year - first_treat if first_treat > 0
label var K "Years relative to first minimum wage increase"

*──────────────────────────────────────────────────────────────────────────────
* 3. Borusyak, Jaravel & Spiess (2021)
*    Imputation estimator — efficient under parallel trends
*──────────────────────────────────────────────────────────────────────────────

* Recode never-treated to missing (did_imputation convention)
gen Ei = first_treat
replace Ei = . if first_treat == 0

did_imputation lemp countyreal year Ei, allhorizons pretrend(3)

event_plot, default_look                                      ///
    graph_opt(                                                ///
        title("Borusyak et al. (2021)", size(medsmall))       ///
        xtitle("Years since minimum wage increase")           ///
        ytitle("Effect on log teen employment")               ///
        xlabel(-3(1)3)                                        ///
        yline(0, lcolor(gs8))                                 ///
        graphregion(color(white)) bgcolor(white))

estimates store bjs

*──────────────────────────────────────────────────────────────────────────────
* 4. de Chaisemartin & D'Haultfoeuille (2024)
*    First-difference approach — robust to heterogeneous effects
*──────────────────────────────────────────────────────────────────────────────

did_multiplegt_dyn lemp countyreal year D, ///
    effects(3) placebo(3)                  ///
    cluster(countyreal)

event_plot e(estimates)#e(variances), default_look            ///
    stub_lag(Effect_#) stub_lead(Placebo_#) together          ///
    graph_opt(                                                ///
        title("de Chaisemartin & D'Haultfoeuille (2024)", size(medsmall)) ///
        xtitle("Years since minimum wage increase")           ///
        ytitle("Effect on log teen employment")               ///
        xlabel(-3(1)3)                                        ///
        yline(0, lcolor(gs8))                                 ///
        graphregion(color(white)) bgcolor(white))

matrix dcdh_b = e(estimates)
matrix dcdh_v = e(variances)

*──────────────────────────────────────────────────────────────────────────────
* 5. Callaway & Sant'Anna (2021)
*    Group-time ATTs — original application for this dataset
*──────────────────────────────────────────────────────────────────────────────

* gvar = first_treat; 0 = never treated (csdid convention)
csdid lemp lpop, ivar(countyreal) time(year) gvar(first_treat) notyet

estat event, estore(cs)

event_plot cs, default_look                                   ///
    stub_lag(Tp#) stub_lead(Tm#) together                     ///
    graph_opt(                                                ///
        title("Callaway & Sant'Anna (2021)", size(medsmall))  ///
        xtitle("Years since minimum wage increase")           ///
        ytitle("Effect on log teen employment")               ///
        xlabel(-3(1)3)                                        ///
        yline(0, lcolor(gs8))                                 ///
        graphregion(color(white)) bgcolor(white))

*──────────────────────────────────────────────────────────────────────────────
* 6. Sun & Abraham (2021)
*    Interaction-weighted estimator — last cohort as clean control
*──────────────────────────────────────────────────────────────────────────────

* Control cohort: last-treated or never-treated
summ Ei
gen lastcohort = (Ei == r(max)) | missing(Ei)

* Lag indicators (post: K = 0,1,2,3)
forvalues l = 0/3 {
    gen L`l'event = (K == `l') & !missing(K)
}

* Lead indicators (pre: K = -1,...,-4); K = -1 normalised out
forvalues l = 1/4 {
    gen F`l'event = (K == -`l') & !missing(K)
}
drop F1event    // normalisation: omit K = -1

eventstudyinteract lemp L*event F*event,   ///
    vce(cluster countyreal)                ///
    absorb(countyreal year)                ///
    cohort(Ei) control_cohort(lastcohort)

event_plot e(b_iw)#e(V_iw), default_look  ///
    stub_lag(L#event) stub_lead(F#event) together ///
    graph_opt(                                     ///
        title("Sun & Abraham (2021)", size(medsmall)) ///
        xtitle("Years since minimum wage increase")   ///
        ytitle("Effect on log teen employment")       ///
        xlabel(-4(1)3)                               ///
        yline(0, lcolor(gs8))                        ///
        graphregion(color(white)) bgcolor(white))

matrix sa_b = e(b_iw)
matrix sa_v = e(V_iw)

*──────────────────────────────────────────────────────────────────────────────
* 7. TWFE OLS benchmark (reghdfe with leads & lags)
*    May be biased under heterogeneous treatment effects
*──────────────────────────────────────────────────────────────────────────────

reghdfe lemp F*event L*event, absorb(countyreal year) cluster(countyreal)

event_plot, default_look                        ///
    stub_lag(L#event) stub_lead(F#event) together ///
    graph_opt(                                    ///
        title("TWFE OLS", size(medsmall))         ///
        xtitle("Years since minimum wage increase") ///
        ytitle("OLS coefficients")                ///
        xlabel(-4(1)3)                            ///
        yline(0, lcolor(gs8))                     ///
        graphregion(color(white)) bgcolor(white))

estimates store ols

*──────────────────────────────────────────────────────────────────────────────
* 8. Combined plot — all five estimators
*──────────────────────────────────────────────────────────────────────────────

event_plot              ///
    bjs                 ///  Borusyak et al.
    dcdh_b#dcdh_v       ///  de Chaisemartin & D'Haultfoeuille
    cs                  ///  Callaway & Sant'Anna
    sa_b#sa_v           ///  Sun & Abraham
    ols,                ///  TWFE OLS
    stub_lag(tau# Effect_# Tp# L#event L#event)     ///
    stub_lead(pre# Placebo_# Tm# F#event F#event)   ///
    plottype(scatter) ciplottype(rcap)               ///
    together                                         ///
    perturb(-0.30(0.15)0.30)                         ///
    trimlead(3)                                      ///
    noautolegend                                     ///
    graph_opt(                                                              ///
        title("Effect of minimum wage on teen employment: five estimators", ///
              size(medlarge))                                               ///
        xtitle("Years since minimum wage increase")                         ///
        ytitle("Effect on log teen employment")                             ///
        xlabel(-3(1)3)                                                      ///
        legend(order(                                                        ///
            1 "Borusyak et al. (2021)"                                      ///
            3 "de Chaisemartin & D'Haultfoeuille (2024)"                    ///
            5 "Callaway & Sant'Anna (2021)"                                 ///
            7 "Sun & Abraham (2021)"                                        ///
            9 "TWFE OLS")                                                   ///
            rows(3) region(style(none)))                                    ///
        xline(-0.5, lcolor(gs8) lpattern(dash))                             ///
        yline(0, lcolor(gs8))                                               ///
        graphregion(color(white)) bgcolor(white))                           ///
    lag_opt1(msymbol(Oh))   ///  Borusyak
    lag_opt2(msymbol(Th))   ///  de Chaisemartin
    lag_opt3(msymbol(Dh))   ///  Callaway & Sant'Anna
    lag_opt4(msymbol(Sh))   ///  Sun & Abraham
    lag_opt5(msymbol(+))        //  TWFE OLS

graph export "fig_five_estimators_minwage.png", replace width(2400)

/*******************************************************************************
* End of script
*******************************************************************************/
