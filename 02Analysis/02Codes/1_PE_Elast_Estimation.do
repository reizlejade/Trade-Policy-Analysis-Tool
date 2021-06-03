* R.Platitas, May 2021
* File calculates the elasticities of tariffs and other gravity variables 
* Written in Stata 14 on Windows 10



********************************************************************************
****				Preparing Relevant Data Inputs           				****
********************************************************************************

local models GC FE                      // specifications: GC-using gravity controls+imp-time,exp-time FEs; FE-using imp-time,exp-time,imp-exp FEs


*Set desired gravity variables
*(See available variables here: https://www.usitc.gov/data/gravity/dynamic_gravity_technical_documentation_v1_00_1.pdf)
local grav_exdist contiguity common_language colony_ever     
local plcy agree_fta agree_cu member_eu_joint                          
                                                                                       
*Generate repositories for elasticities and fixed effects from PPML estimation
foreach file in Elast FE{
	foreach spec in FE GC{
		clear
		save "$anlysdir/04Temp/Temp_`file'_`spec'", replace emptyok
	}
}


********************************************************************************
***	               PPML estimation proper (done by sector)  	       		****
********************************************************************************

forval x=1/153{  
	*if inlist(`x',5,8,14,15,17,18,154,155,161,167,168) continue     // sectors without intra-national trade for any given year

*Trim MAcMap tariffs data for merging later

	use if itpd_id==`x' & year<2017 using  "$builddir/03Output/tariff_byitpd.dta",clear
	save "$builddir/04Temp/tariff_sec.dta",replace


*Merge with gravity data and author-aggregated MAcMap tariffs data
	use year iso3_o iso3_d itpd_id trade if itpd_id==`x' using "$builddir/04Temp/trade_byitpd.dta",clear

	merge 1:1 year iso3_o iso3_d using "$builddir/04Temp/grvty.dta",keepusing(distance `grav_exdist' `plcy') keep(match master) nogen
	merge 1:1 year iso3_o iso3_d using "$builddir/04Temp/tariff_sec.dta",keep(match master) nogen

	replace tariff=0 if iso3_o==iso3_d          // set tariff=0 for domestic flows  

	gen ln_dist=ln(distance)
	gen ln_tar = ln(1+tariff/100)

*Create set of FEs
	egen exp_time=group(iso3_o year)
	egen imp_time=group(iso3_d year)
	egen imex	= group(iso3_d iso3_o)


*A. PPML estimation w/ Gravity variables + Imp-time and Exp-time FEs
	timer on 1
	cap ppmlhdfe trade ln_dist `grav_exdist' `plcy' ln_tar, absorb(exp_time imp_time,savefe) vce(cluster imex)
	timer off 1
	di `x'
	timer list 1
	sca def time = r(t1)
	cap gen cons = _b[_cons]
	cap outsheet year itpd_id iso3_o iso3_d *hdfe* cons using "$anlysdir/04Temp/Temp_FE_GC_`x'.csv",comma        
	cap regsave ln_dist `grav_exdist' `plcy' ln_tar using "$anlysdir/04Temp/Temp_Elast_GC", tstat pval ci level(95) addlabel(itpd_id, `x', time, `=scalar(time)') append	


*B. PPML estimation w/ Complete set of FEs
	timer on 2
	ppmlhdfe trade `plcy' ln_tar,absorb(exp_time imp_time imex,savefe) vce(cluster imex) 
	timer off 2
	di `x'
	timer list 2
	sca def time = r(t2)
	cap gen cons = _b[_cons]
	cap outsheet year itpd_id iso3_o iso3_d *hdfe* cons using "$anlysdir/04Temp/Temp_FE_FE_`x'.csv",comma    
	cap regsave `plcy' ln_tar using "$anlysdir/04Temp/Temp_Elast_FE", tstat pval ci level(95) addlabel(itpd_id, `x', time, `=scalar(time)') append	
} 


*Generate plots of estimated elasticities for all time-varying RHS variables

use var itpd_id coef pval using  "$anlysdir/04Temp/Temp_Elast_GC",clear
ren (coef pval) (coef_GC pval_GC)

merge 1:1 var itpd_id using "$anlysdir/04Temp/Temp_Elast_FE",keepusing(coef pval) nogen
merge m:1 itpd_id using "$projdir/04Misc/itpd_sec",keep(master match)nogen

ren (coef pval) (coef_FE pval_FE)

foreach s in `models'{
	gen sig_`s'="not significant" if pval_`s'>0.05
	replace sig_`s'="significant at 5%" if pval_`s'<=0.05
	replace sig_`s'="significant at 1%" if pval_`s'<=0.01

	bysort var:egen rank`s'=rank(coef_`s')
	labvars coef_`s' itpd_id rank`s' "Trade elasticity-`s'" "Sector" "Industry"
}


keep if inlist(var,"agree_fta","agree_cu","member_eu_joint","ln_tar")

replace var="FTA" if var=="agree_fta"
replace var="CU" if var=="agree_cu"
replace var="EU" if var=="member_eu_joint"
replace var="Tariff" if var=="ln_tar"


foreach v in FTA CU EU Tariff{
	foreach s in `models'{
		sepscatter coef_`s' rank`s' if var=="`v'",sep(sig_`s') legend(size(*0.65)) name(`v'_`s')
	}
	grc1leg `v'_GC `v'_FE,rows(2) legendfrom(`v'_GC) title("`v'")
	graph save "$anlysdir/03Output/Elast_`v'.png",replace
}











