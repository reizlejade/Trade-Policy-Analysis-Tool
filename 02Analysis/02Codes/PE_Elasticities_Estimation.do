* R.Platitas, May 2021
* File calculates the elasticities of tariffs and other gravity variables based on .....
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

local grav_exdist contiguity common_language colony_ever agree_fta agree_cu member_eu_joint       //set desired gravity variables
                                                              ***See available variables here: https://www.usitc.gov/data/gravity/dynamic_gravity_technical_documentation_v1_00_1.pdf
                                                                                        
*==============Generate repositories for elasticities and fixed effects from PPML estimation===============*
foreach file in Elast FE{
foreach spec in FE GC{
clear
save "`anlysdir'\04Temp\Temp_`file'_`spec'", replace emptyok
}
}

forval x=1/153{  
*if inlist(`x',5,8,14,15,17,18,154,155,161,167,168) continue     // these are sectors without intranational trade

*======================Trim MAcMap tariffs data for merging later======================*

use if itpd_id==`x' & year<2017 using  "`builddir'\03Output\tariff_byitpd.dta",clear


save "`builddir'\04Temp\tariff_sec.dta",replace

use year iso3_o iso3_d itpd_id trade if itpd_id==`x' using "`builddir'\03Output\trade_byitpd.dta",clear


*==========Merge with gravity data and author-aggregated MAcMap tariffs data================*

merge 1:1 year iso3_o iso3_d using "`builddir'\03Output\grvty.dta",keepusing(distance `grav_exdist') keep(match master) nogen
merge 1:1 year iso3_o iso3_d using "`builddir'\04Temp\tariff_sec.dta",keep(match master) nogen

replace tariff=0 if iso3_o==iso3_d          // set tariff=0 for domestic flows  

gen ln_dist=ln(distance)
*gen ln_trade=ln(trade)
gen ln_tar = ln(1+tariff/100)

*==============================Create set of FEs===============================*

egen exp_time=group(iso3_o year)
egen imp_time=group(iso3_d year)
egen imex	= group(iso3_d iso3_o)

*=============================Estimation proper===============================*

*A. PPML estimation w/ Gravity variables + Imp-time and Exp-time FEs
timer on 1
cap ppmlhdfe trade ln_dist `grav_exdist' ln_tar, absorb(exp_time imp_time,savefe) vce(cluster imex) tol(1.0e-06) 
timer off 1
di `x'
timer list 1
sca def time = r(t1)
cap gen cons = _b[_cons]
cap outsheet year itpd_id iso3_o iso3_d *hdfe* cons using "`anlysdir'\04Temp\Temp_FE_GC_`x'.csv",comma        
save "`anlysdir'\04Temp\Temp_FE_GC", replace emptyok
cap regsave ln_dist `grav_exdist' ln_tar using "`anlysdir'\04Temp\Temp_Elast_GC", tstat pval ci level(95) addlabel(itpd_id, `x', time, `=scalar(time)') append	


*B. PPML estimation w/ Complete set of FEs
timer on 2
cap ppmlhdfe trade agree_fta agree_cu member_eu_joint ln_tar,absorb(exp_time imp_time imex,savefe) vce(cluster imex) tol(1.0e-06) 
timer off 2
di `x'
timer list 2
sca def time = r(t2)
cap gen cons = _b[_cons]
cap outsheet year itpd_id iso3_o iso3_d *hdfe* cons using "`anlysdir'\04Temp\Temp_FE_FE_`x'.csv",comma        
cap regsave agree_fta agree_cu member_eu_joint  ln_tar using "`anlysdir'\04Temp\Temp_Elast_FE", tstat pval ci level(95) addlabel(itpd_id, `x', time, `=scalar(time)') append	
} 



*=============================Merging all Elast+FEs===============================*
