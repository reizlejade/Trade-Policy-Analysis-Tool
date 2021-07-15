* R.Platitas, May 2021
* File calculates the GE counterfactual
* Written in Stata 14 on Windows 10

********************************************************************************
****						Preliminary Settings							****
********************************************************************************
clear all
version 15.1
cap log close
set more off, perm
set mem 1g
set matsize 11000, perm
set maxvar 32767
set type double
macro drop _all
graph drop _all
timer clear


local projdir "D:\07 Trade Policy Analysis tool"         // central directory
local builddir "`projdir'\01Build"                        // high-level directory for Building the data
local anlysdir "`projdir'\02Analysis"                     // high-level directory for Analysis proper


local baseyr=2016

use year iso3_o iso3_d itpd_id trade if year==`baseyr' using "`builddir'\03Output\trade_byitpd.dta",clear

merge 1:1 year iso3_o iso3_d itpd_id using "`builddir'\03Output\tariff_byitpd.dta",keepusing(tariff) keep(match master) nogen
merge 1:1 year iso3_o iso3_d itpd_id using "`anlysdir'\03Output\tariff_cfl.dta",keepusing(tariff_cfl) keep(match master) nogen

save  "`anlysdir'\04Temp\Temp_PrepData_Baseline",replace

use if var=="Tariff" using "D:\07 Trade Policy Analysis tool\02Analysis\03Output\Elast_Estimates",clear
keeporder itpd_id coef* pval*
save "`anlysdir'\04Temp\Temp_PrepData_BetaCoefs",replace

use "`anlysdir'\04Temp\Temp_PrepData_Baseline",clear

merge m:1 itpd_id using "`anlysdir'\04Temp\Temp_PrepData_BetaCoefs",keep(match master) nogen

gen ln_tar = ln(1+tariff/100)

*Perform GE analysis counterfactual

egen exp_sec=concat(iso3_o itpd_id)
egen imp_sec=concat(iso3_d itpd_id)


foreach s in GC FE{

gen beta_treatment_`s'= 0
replace beta_treatment_`s'=coef_`s' * (ln(1.+ tariff_cfl / 100) - ln_tar) 
replace beta_treatment_`s'=0 if coef_`s'>0 | pval_`s'>0.05                        //this drops the counterfactuals produced by elasticities that are either not significant or incorrectly signed
replace beta_treatment_`s'=0 if mi(beta_treatment_`s')                       //this drops the counterfactuals produced by elasticities that are either not significant or incorrectly signed

ge_gravity exp_sec imp_sec trade beta_treatment_`s', theta(4) gen_w(welfare_`s') gen_X(flow_`s')   

* Gen trade & welfare impacts 
gen d_flow_`s'= flow_`s' - flow
gen d_welfare_`s'= (welfare_`s') * 100 - 100

}









