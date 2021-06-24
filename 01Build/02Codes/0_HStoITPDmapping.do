* R.Platitas, May 2021
* This file creates a mapping of the  
* Written in Stata 15.1 on Windows 10



/*
itpd1- resulted from three-way merging of HS-->FAOSTAT Commodity List (FCL)-->ITPD sector for Agriculture 
	and HS-->ISIC Rev.3-->ITPD sector for Mining, and Manufacturing
itpd2-improved on 'itpd1' mapping by manually filling out the sectors of unmapped HS based on product
	description and sectors of nearby products 
itpd3-improved on 'itpd' mapping by using CPC classification of products as "bridge" to HS and ISIC Rev.3
	i.e. HS-->CPC-->ISIC Rev.3-->ITPD sector for Mining, and Manufacturing
*/



********************************************************************************
****	 	            Produce hs to itpd1 mapping  		               ****
********************************************************************************

**Run R script to get the ff concordances (available via the R package called "concordance")
*a.) all hs versions i.e. hs_convrtr.dta  
*b.) 6-dig hs (all ver) to 4-dig isic (all ver) i.e. hs_isic.dta

rsource using "$builddir/02Codes/01_my_script.R",rpath($r_folder) roptions(`"--vanilla"')

cd "$builddir/01Input"
clear all


*Import concordance extracted from a PDF (appendix A in the Yotov paper)---compiled manually in MS excel

import excel "ITPD_classification.xlsx", sheet("Sheet1") firstrow clear
keep if class=="fcl"
save "$builddir/04Temp/fcl_itpd.dta",replace

import excel "ITPD_classification.xlsx", sheet("Sheet1") firstrow clear
keep if class=="isic3"

*For the 7 M&E sectors, convert 3-dig isic to 4-dig isic
*replace item_code=item_code*10 if item_code<1000    

save "$builddir/04Temp/isic3_itpd.dta",replace


*A.	Agriculture 		        		

fs FAOSTAT*.csv
local f1=`r(files)'
import delimited "`f1'",clear

keeporder itemcode domain item hs12code cpccode
keep if !mi(hs12code)

duplicates drop itemcode hs12code,force


*Separate multiple HS codes into individual rows
split hs12code,p(,) gen(hs_str)
reshape long hs_str,i(itemcode item) j(hs_count) string
keep if !mi(hs_str)
destring hs_str,gen(hs)
ren itemcode fcl


gen hs2012=hs_str
joinby hs2012 using "$builddir/04Temp/hs_convrtr.dta",_merge(mergetype)

sort fcl
gen id=_n
keep id fcl hs1992 hs1996 hs2002 hs2007 hs2012 hs2017
reshape long hs,i(id fcl) j(hsver)


ren hs hs_str
destring hs_str,gen(hs)


keeporder hs_str hs fcl
duplicates drop hs_str,force
save "$builddir/04Temp/hs_fcl.dta",replace

gen item_code=fcl
merge m:1 item_code using "$builddir/04Temp/fcl_itpd.dta",keep(match) nogen      


keeporder hs_str hs itpd_id itpd_desc broadsec
save "$builddir/04Temp/hs_itpd_agri.dta",replace


*B. Mining&Energy

use hs_str isic3 using "$builddir/04Temp/hs_isic.dta",clear
destring hs_str,gen(hs)
replace isic3=substr(isic3,1,3)
destring isic*,replace force

gen item_code=isic3
joinby item_code using "$builddir/04Temp/isic3_itpd.dta",_merge()    


keeporder hs_str hs itpd_id itpd_desc broadsec
duplicates drop hs_str,force
save "$builddir/04Temp/hs_itpd_mne.dta",replace



*C. Manufacturing 	        		

use hs_str isic3 using "$builddir/04Temp/hs_isic.dta",clear

keep if substr(isic3,1,1)!="0"
destring hs_str,gen(hs)
destring isic*,replace force

gen item_code=isic3
joinby item_code using "$builddir/04Temp/isic3_itpd.dta",_merge(mergetype)    

keeporder hs_str hs itpd_id itpd_desc broadsec
duplicates drop hs_str,force
save "$builddir/04Temp/hs_itpd_mfg.dta",replace


use "$builddir/04Temp/hs_itpd_agri.dta",clear
append using "$builddir/04Temp/hs_itpd_mne.dta"
append using "$builddir/04Temp/hs_itpd_mfg.dta"

duplicates drop hs_str,force
ren itpd_id itpd1
save "$builddir/04Temp/hs_itpd_all.dta",replace


********************************************************************************
****	 	            Produce hs to itpd2 mapping  		               ****
********************************************************************************
*Fill out unmapped HS6 codes using the prevalent sector in each HS4 
use "$builddir/04Temp/hs_desc.dta",clear
keep if length(code)==6
gen hs_str=code

merge 1:1 hs_str using "$builddir/04Temp/hs_itpd_all.dta"

keep if length(code)==6
gen hs4=substr(hs_str,1,4)
bysort hs4: egen itpd2=mode(itpd1),maxmode     

replace itpd2=itpd1 if !mi(itpd1)    //take itpd1 as best match, use itpd2 otw

keeporder hs_str itpd1 itpd2 broadsec

save "$builddir/04Temp/hs_itpd_all.dta",replace


*NOTE: 
*no HS is mapped to sectors 77-Reproduction of recorded media and 103-Casting of iron and steel because no HS are concorded to ISIC3 2230 and 2731. 

*Remaining unmapped HS are Forestry and Fisheries products which are not covered ITPD sectors




********************************************************************************
****	 	            Test out mapping 		               ****
********************************************************************************


