* R.Platitas, May 2021
* File calculates the PE and GE counterfactual
* Written in Stata 15 on Windows 10


********************************************************************************
****	Calculate tariffs under Counterfactual # 1- US-PRC trade war     *******
********************************************************************************

*do "$anlysdir/02Codes/2a_CFL_calc.do"                        // use this intermediate Do file to add other counterfactuals



********************************************************************************
***	                        Square the Dataset  	       	               	****
********************************************************************************

*do "$anlysdir/02Codes/2b_Squaring_Trade_Flows.do"                       // use this intermediate Do file to maximize domestic flows in base year


********************************************************************************
****				        	Assemble the data		    		 		****
********************************************************************************

local baseyr=2016                                        // set base year
local models GC FE                                       // specifications: GC-using gravity controls+imp-time,exp-time FEs; FE-using imp-time,exp-time,imp-exp FEs

use year iso3_o iso3_d itpd_id trade if year==`baseyr' using "$builddir/04Temp/trade_byitpd.dta",clear
merge 1:1 year iso3_o iso3_d itpd_id using "$anlysdir/04Temp/Temp_SqrdData.dta",keepusing(trade_sq) nogen

merge 1:1 year iso3_o iso3_d itpd_id using "$builddir/04Temp/tariff_byitpd.dta",keepusing(tariff) keep(match master) nogen
merge 1:1 iso3_o iso3_d itpd_id using "$anlysdir/01Input/cfl_1.dta",keepusing(tariff_cfl) nogen

ren tariff tariff_bline

*Resolve cases where tariff_cfl<tariff_bline
replace tariff_cfl=tariff_bline if !mi(tariff_cfl)& tariff_cfl<tariff_bline 
       
save  "$anlysdir/04Temp/Temp_PrepData_Baseline",replace

use if var=="Tariff" using "D:/07 Trade Policy Analysis tool/02Analysis/03Output/Elast_Estimates",clear
keeporder itpd_id coef* pval*

save "$anlysdir/04Temp/Temp_PrepData_BetaCoefs",replace

********************************************************************************
****				         Estimate PE effects    		            	****
********************************************************************************

use "$anlysdir/04Temp/Temp_PrepData_Baseline",clear

merge m:1 itpd_id using "$anlysdir/04Temp/Temp_PrepData_BetaCoefs",keep(match master) nogen

gen ln_tar = ln(1+tariff_bline/100)

egen exp_sec=concat(iso3_o itpd_id)
egen imp_sec=concat(iso3_d itpd_id)

foreach s in `models'{
	gen beta_treatment_`s'= 0
	replace beta_treatment_`s'=coef_`s' * (ln(1.+ tariff_cfl / 100) - ln_tar) 
	replace beta_treatment_`s'=0 if coef_`s'>0 | pval_`s'>0.05                      //drops the counterfactuals produced by elasticities that are either not significant or incorrectly signed
	replace beta_treatment_`s'=0 if mi(beta_treatment_`s')                      

	gen trade_cfl_`s'= trade * (((1+tariff_cfl/100)/(1+tariff_bline/100))^coef_`s') if pval_`s'<=0.05 & coef_`s'<0
	replace trade_cfl_`s'=trade if mi(trade_cfl_`s')
	
	gen d_trade_PEeffect_`s'=100*((trade_cfl_`s'/trade)-1)
}

save "$anlysdir/04Temp/Temp_PE_CFL_BetaTreatment",replace


********************************************************************************
****				         Estimate GE effects    		            	****
********************************************************************************
use if !mi(trade_sq) using "$anlysdir/04Temp/Temp_PE_CFL_BetaTreatment",clear
replace trade=trade_sq if mi(trade)        // picks up the extrapolated domestic flows and use zeros for missing bilaterals


local models GC FE
foreach s in `models'{
gen d_flow_`s'=0
gen d_welfare_`s'=0
forval i=1/153{
if inlist(`i',5,8,14,15,17,18,154,155,161,167,168) continue     // sectors without intra-national trade for any given year
timer on 1
	ge_gravity exp_sec imp_sec trade beta_treatment_`s' if itpd_id==`i', theta(4) gen_w(welfare_`s') gen_X(flow_`s')   

	* Gen trade & welfare impacts 
	replace d_flow_`s'= flow_`s' - trade if itpd_id==`i'
	replace d_welfare_`s'= (welfare_`s') * 100 - 100 if itpd_id==`i'	
	
timer off 1

di "`s'_`i':" 
timer list 1
}
}

*local currdate: di %tdDNCY daily("$S_DATE", "DMY")          // to keep track when the results are generated
keeporder itpd_id iso3* d_*
save "$anlysdir/03Output/CFL_results",replace




