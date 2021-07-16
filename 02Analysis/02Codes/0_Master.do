* R.Platitas, July 2021
* Master file
* Written in Stata 15.1 on Windows 10 > Tested on MacOS Catalina (16 Jul. 2021)


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


/* Required Packages: un-comment to run and install if first time using this program
findit grc1leg 										// Manually download and install
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
ssc inst gtools
ssc inst labutil
ssc inst labutil2
ssc inst sepscatter
ssc install rsource
ssc install asgen
*/


********************************************************************************
****							Set Folder Paths							****
********************************************************************************

* Set project folder
dis "`c(username)'" // Display your computer name + add it following the pattern below
if "`c(username)'"=="h83" 		global projdir 		"/Users/h83/Desktop/Asian Development Bank/Reizle Jade C. Platitas - ERMR_Trade Policy Analysis Tool"
if "`c(username)'"=="rjcpl" 	global projdir 		"D:/07 Trade Policy Analysis tool"

* Set 2nd level folders
global builddir "$projdir/01Build"                 // high-level directory for Building the data
global anlysdir "$projdir/02Analysis"              // high-level directory for Analysis proper

* Set the R path to be used in building HS to ITPD concordance in 0_HStoITPDmapping.do
if "`c(username)'"=="h83" 		global r_folder 	`"/usr/local/bin/R"'
if "`c(username)'"=="rjcpl" 	global r_folder 	`"C:/Program Files/R/R-4.0.2/bin/R.exe"'


********************************************************************************
****					Run Do Files – Data Preparation						****
********************************************************************************

* 1 - Generate the HS6 to ITPD sectors mapping         
do "$builddir/02Codes/1_HS_to_ITPD_mapping.do"


* 2 - Prepare merged trade,gravity and tariff data
do "$builddir/02Codes/2_Data_Preparation.do"


********************************************************************************
****						Run Do Files – Analysis							****
********************************************************************************

* 1 - Estimate trade elasticities by ITPD sector (153 sectors)
do "$anlysdir/02Codes/1_PE_Elast_Estimation.do"


* 2 - Calculate PE and GE effects of counterfactuals
do "$anlysdir/02Codes/2_PE_GE_Counterfactuals.do"    


* 3 - Produce graphs to present results of counterfactuals  analysis
do "$anlysdir/02Codes/3_Graphs.do"

