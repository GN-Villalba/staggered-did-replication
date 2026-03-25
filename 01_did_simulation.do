/*******************************************************************************
* 04_did_simulation.do
* ─────────────────────────────────────────────────────────────────────────────
* Replication exercise: staggered difference-in-differences with simulated data.
*
* Demonstrates a complete workflow for a staggered adoption design:
*   (i)  data-generating process with a known true treatment effect
*   (ii) OLS and IV estimation (standard and with controls)
*   (iii) Callaway & Sant'Anna (2021) event-study
*   (iv) heterogeneity analysis by subgroup (public vs. private institutions)
*
* Design
* ------
* - 200 units (programmes) nested in 80 institutions, observed over 9 periods
* - Staggered treatment: units adopt treatment in different periods
* - Eligibility rule (>=4 cohorts at baseline) serves as instrument
* - Outcome standardised at period level (z-score)
* - True ATT = 0.12 sd (hard-coded in DGP for validation)
*
* Author  : Gabriela Villalba (g.villalba-marecos@sussex.ac.uk)
* Updated : March 2026
*
* Required packages (install once):
*   ssc install csdid
*   ssc install coefplot
*******************************************************************************/

clear all
set more off
set seed 12345
version 17

*──────────────────────────────────────────────────────────────────────────────
* 0. Simulation parameters
*──────────────────────────────────────────────────────────────────────────────

local N_prog      = 200    // number of programmes
local N_hei       = 80     // number of higher education institutions
local N_years     = 9      // calendar years: 2012–2020
local cohort_size = 100    // students per programme-year cell

*──────────────────────────────────────────────────────────────────────────────
* 1. Programme-level base dataset
*──────────────────────────────────────────────────────────────────────────────

set obs `N_prog'
gen prog_id = _n

* Assign each programme to an institution
gen hei_id = ceil(runiform() * `N_hei')

* Programme maturity: number of cohorts already running by 2015
gen cohorts_2015 = round(rnormal(4, 1.5))
replace cohorts_2015 = 0 if cohorts_2015 < 0

* Eligibility instrument: mature programmes (>=4 cohorts) are eligible
* for early accreditation — discontinuity around the 4-cohort threshold
gen eligible = (cohorts_2015 >= 4)
label var eligible "Eligible for accreditation (>=4 cohorts by 2015)"

* Staggered treatment year
* -- Eligible programmes accredit 2016–2018 (early adopters)
* -- 30% of ineligible programmes accredit 2019–2020 (late adopters)
gen treat_year = .
replace treat_year = 2016 + floor(3 * runiform()) if eligible == 1
replace treat_year = 2019 + floor(2 * runiform()) ///
    if eligible == 0 & runiform() < 0.30

tempfile prog
save `prog', replace

*──────────────────────────────────────────────────────────────────────────────
* 2. Expand to programme-year panel
*──────────────────────────────────────────────────────────────────────────────

use `prog', clear

expand `N_years'
bys prog_id: gen year = 2011 + _n    // 2012–2020
label var year "Calendar year"

* Accreditation status: 1 from treat_year onwards
gen accredited = (year >= treat_year) if treat_year < .
replace accredited = 0 if missing(accredited)
label var accredited "Programme is accredited"

tempfile pan_prog
save `pan_prog', replace

*──────────────────────────────────────────────────────────────────────────────
* 3. Expand to student level
*──────────────────────────────────────────────────────────────────────────────

use `pan_prog', clear

expand `cohort_size'
bys prog_id year: gen stud_in_cohort = _n
gen id = _n
label var id "Student identifier"

* Student characteristics
gen female = (runiform() < 0.60)
label define sex 0 "Male" 1 "Female"
label values female sex
label var female "Female"

gen ses = rnormal(0, 1)
label var ses "Socioeconomic index (standardised)"

* Prior ability: standardised Saber 11 entrance score
gen saber11_raw = rnormal(0, 1)
bys year: egen z_saber11 = std(saber11_raw)
label var z_saber11 "Saber 11 score (z-score, standardised by year)"

*──────────────────────────────────────────────────────────────────────────────
* 4. Outcome: Saber Pro exit score
*    DGP: true accreditation effect = 0.12 sd
*──────────────────────────────────────────────────────────────────────────────

gen u = rnormal(0, 1)

gen saberpro_latent = 0.12 * accredited  ///  true ATT
                    + 0.60 * z_saber11   ///  ability persistence
                    + 0.05 * ses         ///  socioeconomic gradient
                    + 0.03 * female      ///  gender gap
                    + u

bys year: egen z_saberpro = std(saberpro_latent)
label var z_saberpro "Saber Pro score (z-score, standardised by year)"

*──────────────────────────────────────────────────────────────────────────────
* 5. Institution type (public/private) — assigned at HEI level
*──────────────────────────────────────────────────────────────────────────────

preserve
    keep hei_id
    duplicates drop
    gen public = (runiform() < 0.4)    // ~40% public institutions
    tempfile heitype
    save `heitype'
restore

merge m:1 hei_id using `heitype', nogen
label define pub 0 "Private" 1 "Public"
label values public pub
label var public "Public institution"

save "data/HQA_simulated.dta", replace

*──────────────────────────────────────────────────────────────────────────────
* 6. OLS and IV estimates (replicates Table 2 structure)
*──────────────────────────────────────────────────────────────────────────────

* (1) OLS — no controls
reg z_saberpro accredited i.hei_id i.year, cluster(prog_id)
estimates store OLS1

* (2) IV — no controls
* First stage: eligible predicts accredited conditional on year/HEI FE
ivregress 2sls z_saberpro (accredited = eligible) ///
    i.hei_id i.year, cluster(prog_id)
estimates store IV2

* (3) OLS — with student controls
reg z_saberpro accredited z_saber11 female ses ///
    i.hei_id i.year, cluster(prog_id)
estimates store OLS3

* (4) IV — with student controls
ivregress 2sls z_saberpro z_saber11 female ses ///
    (accredited = eligible) ///
    i.hei_id i.year, cluster(prog_id)
estimates store IV4

* Display table (requires estout: ssc install estout)
* esttab OLS1 IV2 OLS3 IV4,                ///
*     b(%6.3f) se(%6.3f)                   ///
*     star(* 0.10 ** 0.05 *** 0.01)        ///
*     label compress

*──────────────────────────────────────────────────────────────────────────────
* 7. Callaway & Sant'Anna (2021) event-study — all programmes
*    Requires: ssc install csdid
*──────────────────────────────────────────────────────────────────────────────

preserve
    * Collapse to programme-year for event-study estimation
    collapse (mean) z_saberpro, by(prog_id year treat_year)

    gen gvar = treat_year
    replace gvar = . if missing(gvar)    // never-treated: gvar = .
    label var gvar "First treatment year (notyet identification)"

    tsset prog_id year

    csdid z_saberpro, ivar(prog_id) time(year) gvar(gvar) notyet

    estat event, estore(ES_all)

    coefplot ES_all,                                          ///
        keep(Tm* Tp*)                                        ///
        vertical                                             ///
        msymbol(O) msize(small) mcolor(black)                ///
        ciopts(recast(rcap) lcolor(black) lwidth(thin))      ///
        yline(0, lcolor(black) lwidth(vthin))                ///
        xline(7, lpattern(dash) lcolor(gs8))                 ///
        xlabel(, labsize(small) nogrid)                      ///
        ylabel(, angle(horizontal) nogrid)                   ///
        xtitle("Event time", size(small))                    ///
        ytitle("ATT on z(Saber Pro)", size(small))           ///
        title("Event-study ATT — all programmes", size(medsmall)) ///
        graphregion(color(white)) bgcolor(white)
restore

*──────────────────────────────────────────────────────────────────────────────
* 8. Heterogeneity by institution type: public vs. private
*──────────────────────────────────────────────────────────────────────────────

* --- 8a. Public institutions ---
preserve
    keep if public == 1
    collapse (mean) z_saberpro, by(prog_id year treat_year)
    gen gvar = treat_year
    tsset prog_id year
    csdid z_saberpro, ivar(prog_id) time(year) gvar(gvar) notyet
    estat event, estore(ES_public)
restore

* --- 8b. Private institutions ---
preserve
    keep if public == 0
    collapse (mean) z_saberpro, by(prog_id year treat_year)
    gen gvar = treat_year
    tsset prog_id year
    csdid z_saberpro, ivar(prog_id) time(year) gvar(gvar) notyet
    estat event, estore(ES_private)
restore

* --- 8c. Combined plot ---
coefplot                                                          ///
    (ES_public,  keep(Tm* Tp*) label("Public"))                  ///
    (ES_private, keep(Tm* Tp*) label("Private")),                ///
    vertical                                                      ///
    msymbol(O) msize(small)                                       ///
    ciopts(recast(rcap) lwidth(thin))                             ///
    yline(0, lcolor(black) lwidth(vthin))                         ///
    xlabel(, labsize(small) nogrid)                               ///
    ylabel(, angle(horizontal) nogrid)                            ///
    xtitle("Event time", size(small))                             ///
    ytitle("ATT on z(Saber Pro)", size(small))                    ///
    title("Event-study ATT by institution type", size(medsmall))  ///
    legend(pos(6) ring(0) col(1))                                 ///
    graphregion(color(white)) bgcolor(white)                      ///
    scheme(s1mono)

graph export "output/fig_eventstudy_public_private.pdf", replace
graph export "output/fig_eventstudy_public_private.png", replace width(2000)

/*******************************************************************************
* End of script
*******************************************************************************/
