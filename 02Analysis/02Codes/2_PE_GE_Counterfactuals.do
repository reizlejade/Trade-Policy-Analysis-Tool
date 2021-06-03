* R.Platitas, May 2021
* File calculates the GE counterfactual
* Written in Stata 14 on Windows 10


********************************************************************************
****	Calculate tariffs under Counterfactual # 1- US-PRC trade war     *******
********************************************************************************

do "$anlysdir/02Codes/2a_CFL_calc.do"                        // use this intermediate do file to add other counterfactuals


********************************************************************************
****				        	Preliminaries		    		 			****
********************************************************************************

local baseyr=2016                                        // set base year
local models GC FE                                       // specifications: GC-using gravity controls+imp-time,exp-time FEs; FE-using imp-time,exp-time,imp-exp FEs

use year iso3_o iso3_d itpd_id trade if year==`baseyr' using "$builddir/04Temp/trade_byitpd.dta",clear

merge 1:1 year iso3_o iso3_d itpd_id using "$builddir/04Temp/tariff_byitpd.dta",keepusing(tariff) keep(match master) nogen
merge 1:1 year iso3_o iso3_d itpd_id using "$anlysdir/01Input/cfl_1.dta",keepusing(tariff_cfl) keep(match master) nogen

ren tariff tariff_bline
save  "$anlysdir/04Temp/Temp_PrepData_Baseline",replace

use if var=="Tariff" using "D:/07 Trade Policy Analysis tool/02Analysis/03Output/Elast_Estimates",clear
keeporder itpd_id coef* pval*

save "$anlysdir/04Temp/Temp_PrepData_BetaCoefs",replace

********************************************************************************
****				         Estimate PE effects    		            	****
********************************************************************************

use "$anlysdir/04Temp/Temp_PrepData_Baseline",clear

merge m:1 itpd_id using "$anlysdir/04Temp/Temp_PrepData_BetaCoefs",keep(match master) nogen

gen ln_tar = ln(1+tariff/100)

egen exp_sec=concat(iso3_o itpd_id)
egen imp_sec=concat(iso3_d itpd_id)

foreach s in `models'{
	gen beta_treatment_`s'= 0
	replace beta_treatment_`s'=coef_`s' * (ln(1.+ tariff_cfl / 100) - ln_tar) 
	replace beta_treatment_`s'=0 if coef_`s'>0 | pval_`s'>0.05                      //this drops the counterfactuals produced by elasticities that are either not significant or incorrectly signed
	replace beta_treatment_`s'=0 if mi(beta_treatment_`s')                       //this drops the counterfactuals produced by elasticities that are either not significant or incorrectly signed

	gen trade_cfl_`s'= trade * (((1+tariff_cfl/100)/(1+tariff/100))^coef_`s') if pval_`s'<=0.05 & coef_`s'<0
	replace trade_cfl_`s'=trade if mi(trade_cfl_`s')

********************************************************************************
****				         Estimate GE effects    		            	****
********************************************************************************
	
*[Add here code bloc that A. fill in intra-national flows using external trade GR/internal trade GR ratio, B. square the data]

ge_gravity exp_sec imp_sec trade beta_treatment_`s', theta(4) gen_w(welfare_`s') gen_X(flow_`s')   

* Gen trade & welfare impacts 
gen d_flow_`s'= flow_`s' - flow
gen d_welfare_`s'= (welfare_`s') * 100 - 100

}









