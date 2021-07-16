* R.Platitas, May 2021
* This file maps Harmonized System (HS) codes to International Trade & Production Database (ITPD) classification


/*
itpd1- resulted from three-way merging of HS-->FAOSTAT Commodity List (FCL)-->ITPD sector for Agriculture 
	and HS-->ISIC Rev.3-->ITPD sector for Mining, and Manufacturing
itpd2-improved on 'itpd1' mapping by manually filling out the sectors of unmapped HS based on product
	description and sectors of nearby products 
itpd3-improved on 'itpd' mapping by using CPC classification of products as "bridge" to HS and ISIC Rev.3
	i.e. HS-->CPC-->ISIC Rev.3-->ITPD sector for Mining, and Manufacturing
*/


********************************************************************************
****																		****
****					 Produce HS-to-ITPD1 Mapping  						****
****																		****
********************************************************************************

********************************************************************************
****	 	           			Preliminary Steps 		       				****
********************************************************************************

**Run R script to get the ff concordances (available via the R package called "concordance")
*a.) all hs versions i.e. hs_convrtr.dta  
*b.) 6-dig hs (all ver) to 4-dig isic (all ver) i.e. hs_isic.dta
* @Reizle: Please rename 01_my_script.R with a more explicit name
rsource using "$builddir/02Codes/01_my_script.R",rpath($r_folder) roptions(`"--vanilla"')

* Set working directory to the 'Input' folder
cd "$builddir/01Input"
clear all

*Import concordance extracted from a PDF (appendix A, Yotov's paper)---compiled manually in Excel
import excel "ITPD_classification.xlsx", sheet("Sheet1") firstrow clear
keep if class=="fcl"

* Save 'fcl' >>>> @Reizle: What does 'FCL' stand for?
save "$builddir/04Temp/fcl_itpd.dta",replace

* Save ISIC 3
import excel "ITPD_classification.xlsx", sheet("Sheet1") firstrow clear
keep if class=="isic3"

* For the 7 Manufacturing and Energy (M&E) sectors, convert 3-digit ISIC to 4-digit ISIC codes
* replace item_code=item_code*10 if item_code<1000    

save "$builddir/04Temp/isic3_itpd.dta",replace


********************************************************************************
****	 	           			A.	Agriculture 		       				****
********************************************************************************

* Load FAO classification @Reizle: Please indicate source (publication reference and/or url)
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

* Merge (joinby) FAO classification with ITPD-HS correspondance table generated via R)
joinby hs2012 using "$builddir/04Temp/hs_convrtr.dta",_merge(mergetype)

sort fcl
gen id=_n
keep id fcl hs1992 hs1996 hs2002 hs2007 hs2012 hs2017
reshape long hs,i(id fcl) j(hsver)
ren hs hs_str
destring hs_str,gen(hs)

* @Reizle: Please explain here what hs_fcl.dta contains
keeporder hs_str hs fcl
duplicates drop hs_str,force
save "$builddir/04Temp/hs_fcl.dta",replace

* @Reizle: Please explain here what fcl_itpd.dta contains
gen item_code=fcl
merge m:1 item_code using "$builddir/04Temp/fcl_itpd.dta",keep(match) nogen

* Save HS-to-ITPD1 mapping for Agriculture
keeporder hs_str hs itpd_id itpd_desc broadsec
save "$builddir/04Temp/hs_itpd_agri.dta",replace


********************************************************************************
****	 	           		B. Mining & Energy			       				****
********************************************************************************

* @Reizle: Please explain here what hs_isic.dta contains and where it comes from
use hs_str isic3 using "$builddir/04Temp/hs_isic.dta",clear
destring hs_str,gen(hs)
replace isic3=substr(isic3,1,3)
destring isic*,replace force
gen item_code=isic3

* Merge (joinby) XXXXX [@Reizle: Please explain what is the master data] with XXXXX [@Reizle: Please explain what is the using data]
joinby item_code using "$builddir/04Temp/isic3_itpd.dta",_merge()    

* Save HS-to-ITPD1 mapping for Mining & Energy
keeporder hs_str hs itpd_id itpd_desc broadsec
duplicates drop hs_str,force
save "$builddir/04Temp/hs_itpd_mne.dta",replace


********************************************************************************
****	 	           			C. Manufacturing		       				****
********************************************************************************
use hs_str isic3 using "$builddir/04Temp/hs_isic.dta",clear

keep if substr(isic3,1,1)!="0"
destring hs_str,gen(hs)
destring isic*,replace force

gen item_code=isic3
joinby item_code using "$builddir/04Temp/isic3_itpd.dta",_merge(mergetype)    

* Save HS-to-ITPD1 mapping for Manufacturing
keeporder hs_str hs itpd_id itpd_desc broadsec
duplicates drop hs_str,force
save "$builddir/04Temp/hs_itpd_mfg.dta",replace


********************************************************************************
****		Merge HS-to-ITPD1 Mapping for Agri + Mining & Energy + Manuf	****
********************************************************************************
use "$builddir/04Temp/hs_itpd_agri.dta",clear
append using "$builddir/04Temp/hs_itpd_mne.dta"
append using "$builddir/04Temp/hs_itpd_mfg.dta"
duplicates drop hs_str,force
ren itpd_id itpd1

* Save HS-to-ITPD1 mapping for all products
save "$builddir/04Temp/hs_itpd1_all.dta",replace



********************************************************************************
****																		****
****				Fill HS-to-ITPD1 Mapping Gaps with HS-to-ITPD2 			****
****				@Reizle: Is this code section title accurate?			****
****																		****
********************************************************************************

* Fill out unmapped HS6 codes using the prevalent sector in each HS4 
* @Reizle: Please explain how 'prevalent' sectors are determined
* @Reizle: Please explain here what hs_desc.dta contains and where it comes from
use "$builddir/04Temp/hs_desc.dta",clear
keep if length(code)==6
gen hs_str=code

* Merge XXXXX [@Reizle: Please explain what is the master data] with HS-to-ITPD1 Mapping (generated above)
merge 1:1 hs_str using "$builddir/04Temp/hs_itpd1_all.dta"
keep if length(code)==6
gen hs4=substr(hs_str,1,4)
bysort hs4: egen itpd2=mode(itpd1),maxmode     

* Take ITPD1 as best match, use ITPD2 otherwise
replace itpd2=itpd1 if !mi(itpd1)

* Save HS-to-ITPD matching file (to-ITPD1 when available, to-ITPD2 otherwise @Reizle: Is this statement accurate?)
keeporder hs_str itpd1 itpd2 broadsec
save "$builddir/04Temp/hs_itpd_all.dta",replace


* NOTES: 
* 1 - Mo HS is mapped to sectors 77-Reproduction of recorded media and 103-Casting of iron and steel because no HS are concorded to ISIC3 2230 and 2731. 
* 2 - Remaining unmapped HS codes are Forestry and Fisheries products which are not covered ITPD sectors

