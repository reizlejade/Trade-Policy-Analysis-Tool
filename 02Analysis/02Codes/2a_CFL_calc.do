* R.Platitas, May 2021
* File calculates the new tariffs under the US-PRC trade war 
* Written in Stata 15 on Windows 10


*Setting some parameters

local itpd itpd3                                          // SET the desired mapping
local baseyr=2016


timer on 1
********************************************************************************
****				Counterfactual # 1- US-PRC trade war					****
********************************************************************************

use imposedby imposedto hs tariffrate_latest if status=="active" using  "$anlysdir/01Input/us_prc_tradewar_tariffs.dta",clear 
*This file is compiled from official documents (USTR and PRC MOFCOM),third-party sources (taxfoundation.org,PIIE,news announcements etc.)


ren (imposedby imposedto hs tariffrate_latest) (iso3_d iso3_o hs_str tariff_cfl)              //to standardize variable names
replace tariff_cfl=100*tariff_cfl                                                             //to express in %

*Aggregate at HS6 level since some trade war tariffs are at HS8 and HS10 level
replace hs_str=substr(hs_str,1,6)
collapse (mean) tariff_cfl,by(iso3_d iso3_o hs_str)

*Aggregating tariffs from 6-dig HS levels into 153-ITPD sectors
*Method: Simple average
merge m:1 hs_str using "$builddir/01Input/hs_itpd_concord.dta", keepusing(`itpd') keep(match master) nogen
ren `itpd' itpd_id
collapse (mean) tariff_cfl,by(iso3_d iso3_o itpd_id)

*Make sure there are no duplicates
egen id=concat( year iso3_o iso3_d itpd_id)
duplicates drop id,force
drop id 

save "$anlysdir/01Input/cfl_1.dta", replace

timer off 1

timer list

********************************************************************************
****						Counterfactual tariffs   						****
********************************************************************************
