* R.Platitas, May 2021
* This file maps Harmonized System (HS) codes to International Trade & Production Database (ITPD) classification
* Written in Stata 15.1 on Windows 10, tested on MacOS Catalina (4 Aug. 2021)



********************************************************************************
****						Produce HS-to-ITPD1 mapping  		       		****
********************************************************************************

** Run R script manually to get the ff concordances (available via the R package called "concordance")
* a.) all hs versions i.e. hs_convrtr.dta  
* b.) 6-dig hs (all ver) to 4-dig isic (all ver) i.e. hs_isic.dta
*rsource using "$builddir/02Codes/01_HS_to_ISIC_concordance.R",rpath($r_folder) roptions(`"--vanilla"')


* Set working directory
clear all
cd "$builddir/01Input"


* A. Import concordance from appendix A in Yotov's paper (.pdf data manually compiled in Excel)

* Import (FAOSTAT Commodity List (FCL)) 'fcl' product classificationfor agriculture products 
import excel "ITPD_classification.xlsx", sheet("Sheet1") firstrow clear
keep if class=="fcl"
save "$builddir/04Temp/fcl_itpd.dta",replace

* Import ISIC3 product classification
import excel "ITPD_classification.xlsx", sheet("Sheet1") firstrow clear
keep if class=="isic3"
*For the 7 Mining & Energy sectors, convert 3-digit ISIC to 4-digit ISIC
*replace item_code = item_code * 10 if item_code<1000    
save "$builddir/04Temp/isic3_itpd.dta",replace


* B.	Agriculture

* Load FAO classification (downloaded from:http://www.fao.org/faostat/en/#definitions)
fs FAOSTAT*.csv
local f1=`r(files)'
import delimited "`f1'",clear
keeporder itemcode domain item hs12code cpccode
keep if !mi(hs12code)
duplicates drop itemcode hs12code,force

* Separate multiple HS codes into individual rows
split hs12code,p(,) gen(hs_str)
reshape long hs_str,i(itemcode item) j(hs_count) string
keep if !mi(hs_str)
destring hs_str,gen(hs)
ren itemcode fcl
gen hs2012=hs_str

* Merge HS 2012 classification (from FAO) w/ HS matching file (allows converting to any HS version)
joinby hs2012 using "$builddir/04Temp/hs_convrtr.dta",_merge(mergetype)

* Reshape long to have each 'fcl' matched w/ product codes from each HS version
sort fcl
gen id=_n
keep id fcl hs1992 hs1996 hs2002 hs2007 hs2012 hs2017
reshape long hs,i(id fcl) j(hsver)

* Keep and save 'fcl'–HS matching file
ren hs hs_str
destring hs_str,gen(hs)
keeporder hs_str hs fcl
duplicates drop hs_str,force
save "$builddir/04Temp/hs_fcl.dta",replace

*Concord HS codes to ITPD sectors via FCL codes using fcl_itpd.dta sourced from ITPD documentation paper (https://usitc.gov/publications/332/working_papers/itpd-e_usitc_wp.pdf)
gen item_code=fcl
merge m:1 item_code using "$builddir/04Temp/fcl_itpd.dta",keep(match) nogen     

* Save HS-to-ITPD1 mapping for Agriculture
keeporder hs_str hs itpd_id itpd_desc broadsec
save "$builddir/04Temp/hs_itpd_agri.dta",replace


* C. Mining & Energy

* Extract HS-to-ISIC matching (generated by the R script)
use hs_str isic3 using "$builddir/04Temp/hs_isic.dta",clear
destring hs_str,gen(hs)
replace isic3=substr(isic3,1,3)
destring isic*,replace force
gen item_code=isic3

* Merge HS-to-ISIC matching w/ ISIC–ITPD codes matching data 
joinby item_code using "$builddir/04Temp/isic3_itpd.dta",_merge()

* Save HS-to-ITPD1 mapping for Mining & Energy
keeporder hs_str hs itpd_id itpd_desc broadsec
duplicates drop hs_str,force
save "$builddir/04Temp/hs_itpd_mne.dta",replace


* D. Manufacturing 	        		

* Extract HS-to-ISIC matching (generated by the R script)
use hs_str isic3 using "$builddir/04Temp/hs_isic.dta",clear
keep if substr(isic3,1,1)!="0"
destring hs_str,gen(hs)
destring isic*,replace force
gen item_code=isic3

* Merge HS-to-ISIC matching w/ ISIC–ITPD codes matching data 
joinby item_code using "$builddir/04Temp/isic3_itpd.dta",_merge(mergetype)    

* Save HS-to-ITPD1 mapping for Manufacturing
keeporder hs_str hs itpd_id itpd_desc broadsec
duplicates drop hs_str,force
save "$builddir/04Temp/hs_itpd_mfg.dta",replace


* E. Merge HS-to-ITPD codes matching for agriculture, mining & energy, and manufacturing
use "$builddir/04Temp/hs_itpd_agri.dta",clear
append using "$builddir/04Temp/hs_itpd_mne.dta"
append using "$builddir/04Temp/hs_itpd_mfg.dta"
duplicates drop hs_str,force
ren itpd_id itpd1
save "$builddir/04Temp/hs_itpd_all_1.dta",replace


********************************************************************************
****					Produce HS-to-ITPD2 mapping							****
********************************************************************************

* Extract HS 6-digit product codes
use "$builddir/04Temp/hs_desc.dta",clear
keep code
keep if length(code)==6
ren code hs_str

* Merge HS 6 digit codes w/ ITPD1 & ITPD2 codes
merge 1:1 hs_str using "$builddir/04Temp/hs_itpd_all_1.dta"
keep if length(hs_str)==6

* Extract HS 4-digit codes corresponding to each 6-digit code
gen hs4=substr(hs_str,1,4)
bysort hs4: egen itpd2=mode(itpd1),maxmode     

* Take ITPD1 as best match, use ITPD2 otherwise
replace itpd2=itpd1 if !mi(itpd1)
keeporder hs_str itpd1 itpd2 broadsec
save "$builddir/04Temp/hs_itpd_all.dta",replace


* Notes 
* 	No HS is mapped to sectors 77-Reproduction of recorded media and 103-Casting of iron and steel because no HS are concorded to ISIC3 2230 and 2731. 
* 	Remaining unmapped HS are Forestry and Fisheries products which are not covered ITPD sectors
