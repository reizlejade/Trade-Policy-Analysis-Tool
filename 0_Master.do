* R.Platitas, June 2021
* Written in Stata 15.1 on Windows 10


********************************************************************************
****						Install Required Packages						****
********************************************************************************

* Un-comment to run and install, when running this program for the first time
/*
findit grc1leg 				// Manually download and install
ssc inst zipsave
ssc inst ppml
ssc inst ppmlhdfe
ssc inst hdfe
ssc inst regsave
ssc inst reghdfe
ssc inst ftools
ssc inst keeporder
ssc inst distinct
ssc inst gtools
ssc inst labutil
ssc inst labutil2
ssc inst sepscatter
ssc install rsource
net install readhtml, from(https://ssc.wisc.edu/sscc/stata/)
*/


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


********************************************************************************
****							Set Folder Paths							****
********************************************************************************

* Set project folder
dis "`c(username)'" // Display your computer name + add it following the pattern below
if "`c(username)'"=="h83" 		global projdir 		"/Users/h83/Desktop/Asian Development Bank/Reizle Jade C. Platitas - ERMR_Trade Policy Analysis Tool"
if "`c(username)'"=="rjcpl" 	global projdir 		"D:/07 Trade Policy Analysis tool"

* Set directory for building the data
global builddir "$projdir/01Build"

* Set directory for analyzing the data
global anlysdir "$projdir/02Analysis"

* Set R path to be used in building HS to ITPD concordance in 0_HS_to_ITPD_mapping.do
if "`c(username)'"=="h83" 		global r_folder 	`"/Applications/R.app"'
if "`c(username)'"=="rjcpl" 	global r_folder 	`"C:/Program Files/R/R-4.0.2/bin/R.exe"'


********************************************************************************
****								Run Do Files							****
********************************************************************************


* Run R script to get the HS-to-ITPF concordance (using R package 'concordance'')
* a) all HS versions i.e. hs_convrtr.dta  
* b) 6-digit HS (all versions) to 4-digit ISIC (all versions) i.e. hs_isic.dta
rsource using "$builddir/02Codes/01_HS_to_ISIC_concordance.R",rpath($r_folder) roptions(`"--vanilla"')


* 0 - Generate the HS6-to-ITPD sectors mapping         
do "$builddir/02Codes/0_HS_to_ITPD_mapping.do"


* 1 - Prepare trade + gravity + tariff data
do "$builddir/02Codes/1_Data_Preparation.do"


	* Note from Jules, 4 Aug. 2021 > I have reviewed & commented the two do files above
	* but I haven't tackled the 3 remaining yet.


* 2 - Estimate trade elasticities by ITPD sector (153 sectors)
do "$anlysdir/02Codes/1_PE_Elast_Estimation.do"


* 3 - Calculate PE and GE effects of counterfactuals
do "$anlysdir/02Codes/2_PE_GE_Counterfactuals.do"    


* 4 - Produce graphs to present results of counterfactuals  analysis
do "$anlysdir/02Codes/3_Graphs.do"

