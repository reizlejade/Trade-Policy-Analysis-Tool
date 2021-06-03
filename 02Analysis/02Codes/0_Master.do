* R.Platitas, June 2021
* Master file ... 
* Written in Stata 15.1 on Windows 10

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
ssc inst gtools
ssc inst labutil
ssc inst labutil2
ssc inst sepscatter
*/

********************************************************************************
****							Set Folder Paths							****
********************************************************************************

* Set project folder
dis "`c(username)'" // Display your computer name + add it following the pattern below
if "`c(username)'"=="..." 		global projdir 		"..."         //@jules: Pls add yours here
if "`c(username)'"=="rjcpl" 	global projdir 		"D:/07 Trade Policy Analysis tool"


*Set 2nd level folders
global builddir "$projdir/01Build"                 // high-level directory for Building the data
global anlysdir "$projdir/02Analysis"              // high-level directory for Analysis proper


********************************************************************************
****								Run Do Files							****
********************************************************************************

* 0 - Generate the HS6 to ITPD sectors mapping         //@jules: I am still cleaning this,I will upload as s
do "$builddir/02Codes/0_HStoITPDmapping.do"

* 1 - Prepare merged trade,gravity and tariff data
do "$builddir/02Codes/1_DataPrep.do"

* 2 - Estimate trade elasticities by ITPD sector (153 sectors)
do "$anlysdir/02Codes/1_PE_Elast_Estimation.do"


* 3 - Calculate PE and GE effects of counterfactuals
do "$anlysdir/02Codes/2_PE_GE_Counterfactuals.do"    //@jules: still finalizing this as well, doing some unit testing









