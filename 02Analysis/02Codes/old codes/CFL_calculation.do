
* R.Platitas, May 2021
* File calculates the new tariffs under the US-PRC trade war 
* Written in Stata 15 on Windows 10

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

*Setting paths

local projdir "D:\07 Trade Policy Analysis tool"
local builddir "`projdir'\01Build"
local anlysdir "`projdir'\02Analysis"      

cd "`builddir'\01Input"

*Setting some parameters

local itpd itpd3                                          // SET the desired mapping
local baseyr=2017


timer on 3


fs bulkdownload*.zip    

foreach f in `r(files)'{    
unzipfile "`f'",replace                                         //NOTE: These are large files >4gb which can only be unzipped by Stata 15.1 or newer. 
}

********************************************************************************
****						Build baseline tariffs							****
********************************************************************************

tempfile masterfile
save `masterfile',replace empty

local baseyr=2017
fs *`baseyr'*agr.txt
foreach f in `r(files)'{

import delimited "`f'",clear

rename (*) (v#) , addnumber
keep v1-v8
rename (v1 v2 v3 v4 v5 v6 v7 v8) (nomencode iso_d_num year hs6 tarlinect agr iso_o_num ave)


*Obtain effectively bilateral applied rate by getting the minimum among all preferential and MFN rates per year-imp-exp-hs6
collapse (min) tariff_bline=ave,by(year iso_o_num iso_d_num  hs6)  
replace tariff_bline=100*tariff_bline   // to express in %

tostring hs6,gen(hs_str)
replace hs_str="0"+hs_str if length(hs_str)==5

merge m:1 hs_str using "`projdir'\04Misc\hs_itpd_concord.dta",keep(match) nogen 

gen ctrycode=iso_o_num
merge m:1 ctrycode using "`projdir'\04Misc\baci_iso.dta",keepusing(iso) keep(match) nogen
ren iso iso3_o
replace ctrycode=iso_d_num
merge m:1 ctrycode using "`projdir'\04Misc\baci_iso.dta",keepusing(iso) keep(match) nogen
ren iso iso3_d



********************************************************************************
****				Counterfactual # 1- US-PRC trade war					****
********************************************************************************


merge 1:1 iso3_o iso3_d hs_str using "`anlysdir'\01Input\cfl2.dta", keep(match master) 

gen tariff_cfl=tariff_bline
replace tariff_cfl=tariff if _merge==3


*Aggregating tariffs from 6-dig HS levels into 153-ITPD sectors
*Method: Simple average
collapse (mean) tariff_bline tariff_cfl,by( year iso3_o iso3_d `itpd')

ren `itpd' itpd_id


egen id=concat( year iso3_o iso3_d itpd_id)
duplicates drop id,force
drop id 

local fname `f'
di `"`fname'"'

append using  `masterfile'
save `masterfile', replace
erase `f'   
}

save "`anlysdir'\03Output\tariff_baseline.dta",replace

fs *.txt
foreach a in `r(files)'{
erase `a'                                                      //Delete misc files
} 


timer off 3

timer list

********************************************************************************
****						Counterfactual tariffs   						****
********************************************************************************
