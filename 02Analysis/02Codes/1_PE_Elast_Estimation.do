* R.Platitas, July 2021
* File calculates the elasticities of tariffs and other gravity variables 
* Written in Stata 15 on Windows 10



********************************************************************************
****				Preparing Relevant Data Inputs           				****
********************************************************************************

*Specifications: GC-using gravity controls+imp-time,exp-time FEs;GC2-GC+control for home bias effects and domestic trade costs; FE-using imp-time,exp-time,imp-exp FEs
local models GC GC2 FE                      

*Set desired gravity variables
*(See available variables here: https://www.usitc.gov/data/gravity/dynamic_gravity_technical_documentation_v1_00_1.pdf)
local grav_exdist contiguity common_language colony_ever     
local plcy agree_fta agree_cu member_eu_joint                          
                                                                                       
*Generate repositories for elasticities and fixed effects from PPML estimation
foreach file in Elast FE{
	foreach spec in `models'{
		clear
		save "$anlysdir/04Temp/Temp_`file'_`spec'", replace emptyok
	}
}


********************************************************************************
***	               PPML estimation proper (done by sector)  	       		****
********************************************************************************

forval x=1/153{  
	*if inlist(`x',5,8,14,15,17,18,154,155,161,167,168) continue     // sectors without intra-national trade for any given year, not relevant here since you can estimate without domestic flows

*Trim MAcMap tariffs data for merging later

	use if itpd_id==`x' & year<2017 using  "$builddir/04Temp/tariff_byitpd.dta",clear
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

*Create control for home bias effect and domestic trade costs (proxied by internal distance)
gen SMCTRY=1 if iso3_d==iso3_o
replace SMCTRY=0 if SMCTRY==.
gen ln_DIST_INTRA=ln_dist*SMCTRY


*A. PPML estimation w/ Gravity variables + Imp-time and Exp-time FEs
	timer on 1
	cap ppmlhdfe trade ln_dist `grav_exdist' `plcy' ln_tar, absorb(exp_time imp_time,savefe) vce(cluster imex)
	timer off 1
	di `x'
	timer list 1
	sca def time = r(t1)
	cap gen cons = _b[_cons]
	cap outsheet year itpd_id iso3_o iso3_d *hdfe* cons using "$anlysdir/04Temp/Temp_FE_GC_`x'.csv",comma replace       
	cap regsave ln_dist `grav_exdist' `plcy' ln_tar using "$anlysdir/04Temp/Temp_Elast_GC", tstat pval ci level(95) addlabel(itpd_id, `x', time, `=scalar(time)') append	
	gen spec="GC"
	

*B. PPML estimation w/ Gravity variables + Imp-time and Exp-time FEs + controls for home-bias effects and domestic trade costs
	timer on 2
	cap ppmlhdfe trade `grav_exdist' `plcy' ln_tar SMCTRY ln_DIST_INTRA, absorb(exp_time imp_time,savefe) vce(cluster imex)
	timer off 2
	di `x'
	timer list 2
	sca def time = r(t2)
	cap gen cons = _b[_cons]
	cap outsheet year itpd_id iso3_o iso3_d *hdfe* cons using "$anlysdir/04Temp/Temp_FE_GC2_`x'.csv",comma replace       
	cap regsave `grav_exdist' `plcy' ln_tar SMCTRY ln_DIST_INTRA using "$anlysdir/04Temp/Temp_Elast_GC2", tstat pval ci level(95) addlabel(itpd_id, `x', time, `=scalar(time)') append	


*C. PPML estimation w/ Complete set of FEs
	timer on 3
	cap ppmlhdfe trade `plcy' ln_tar,absorb(exp_time imp_time imex,savefe) vce(cluster imex) 
	timer off 3
	di `x'
	timer list 3
	sca def time = r(t3)
	cap gen cons = _b[_cons]
	cap outsheet year itpd_id iso3_o iso3_d *hdfe* cons using "$anlysdir/04Temp/Temp_FE_FE_`x'.csv",comma replace   
	cap regsave `plcy' ln_tar using "$anlysdir/04Temp/Temp_Elast_FE", tstat pval ci level(95) addlabel(itpd_id, `x', time, `=scalar(time)') append	
} 


*****Compile all coeffs******
clear
save "$anlysdir/04Temp/Temp_Elast_All", replace emptyok

foreach spec in `models'{
	use "$anlysdir/04Temp/Temp_Elast_`spec'",clear
	gen model="`spec'"
	keeporder model var itpd_id coef pval N
	append using "$anlysdir/04Temp/Temp_Elast_All"
	save "$anlysdir/04Temp/Temp_Elast_All",replace 
}



////////////////////////////////////////////////////////////////////////////////
***	                GRAPHS-plots of estimated elasticities for              ****
***                      all time-varying RHS variables  	       	    	****
////////////////////////////////////////////////////////////////////////////////
graph drop _all

use "$anlysdir/04Temp/Temp_Elast_All",clear
gen sig="significant at 5%" if pval<=0.05
replace sig="not significant" if pval>0.05

reshape wide coef pval N sig,i(var itpd_id) j(model) string

foreach s in `models'{
	bysort var:egen rank`s'=rank(coef`s')
	labvars coef`s' itpd_id rank`s' "Trade elasticity-`s'" "Sector" "Industry"
}


keep if inlist(var,"agree_fta","agree_cu","member_eu_joint","ln_tar")

replace var="FTA" if var=="agree_fta"
replace var="CU" if var=="agree_cu"
replace var="EU" if var=="member_eu_joint"
replace var="Tariff" if var=="ln_tar"



foreach v in FTA CU EU Tariff{
	foreach s in `models'{
		sepscatter coef`s' rank`s' if var=="`v'",sep(sig`s') legend(size(*0.65)) saving(`v'_`s',replace) name(`v'_`s') 
	}
	grc1leg `v'_GC `v'_GC2 `v'_FE,rows(3) legendfrom(`v'_GC) title("`v'") ycommon iscale(*.7)
	graph save "$anlysdir/03Output/Elast_`v'.png",replace
}










