# Trade Policy Analysis Tool
##### Author: Reizle Platitas  (April 2021) 
###### [GitHub][myGH]  | [Project Folder][maindir] 
---
#### About
_Objectives_
- To produce a tool (in Stata/R) that accommodates analysis of various trade policies' impact on trade flows (PE) and welfare(GE) using the structural gravity-general equilibrium framework
- To quantify impact of counterfactual scenarios such as new trade agreements, impending trade disputes (tariffs and/or NTMs), supply chain bottlenecks etc.

_Value-add_
- more disaggregated analysis using new data i.e. ITPD (170 sectors in Agriculture, Mining & Energy, Manufacturing, Services),
- cover more DMCs
- offers flexibility that allows users to formulate their own counterfactuals as long as it can be translated into tariff equivalents

### 	Navigating the Project Folder
#### a. [Master.do][maindir]
The do file that runs the entire analysis starting from building the data (calling on codes from **01Build**) and performing the PE and GE calculations (calling codes from **02Analysis**).

#### b. 01Build
This folder transforms, merges, and prepares data into clean data files to be used by  **02Analysis**.
| Sub-folder   | What's inside |
| ----------- | ----------- |
| _01Input_     |  data downloaded from USITC (ITPD and DGD) and ITC MacMap, required concordances file |
| _02Codes_   |  `0_HS_to_ITPD_mapping.do` maps HS codes to ITPD sectors; `01_HS_to_ISIC_concordance.R` converts HS codes to ISIC codes;  `1_Data_Preparation.do` prepares trade + gravity + tariff data that are exported to **02Analysis>01Input**   |
| _03Output_   | ....  |
| _04Temp_   | respository for temporary files, will automatically wipe out after the entire data build is done |


#### c. 02Analysis
This folder performs the analysis proper.

| Sub-folder   | What's inside |
| ----------- | ----------- |
| _01Input_     |  datasets prepared in **01Build**  |
| _02Codes_   |  `1_PE_Elast_Estimation.do` estimates trade elasticities by ITPD sector (153 sectors); `2_PE_GE_Counterfactuals.do` calculates PE and GE effects of counterfactuals; `2a_CFL_calc.do` prepares the counterfactual tariffs;`2b_Squaring_Trade_Flows.do` extrapolates domestic flows ; `3_Graphs.do`, `3a_Graphs Diagnostics` and `4_Tables.do` produces graphs and tables to present results and other necessary background information|
| _03Output_   | charts,output files, tables  |
| _04Temp_   | respository for temporary files, will automatically clear after the entire analysis is done |
#### d. 03Documentation
This folder contains reference papers and a complete guide to the data and methodology. 


### General steps	of the analysis
1. Aggregation of tariff data from product-level to sector-level 
- 5000+ products ->153 sectors
- to make it compatible with the 153 goods sectors in the ITPD trade data

2. Estimation of Elasticities
- Estimate trade elasticities for EACH sector with respect to policy variable(s) of interest e.g. RTAs, bilateral tariffs, export subsidies. 

3. Perform counterfactuals
- Simulate the impact on trade and welfare under various quantifiable scenarios



### 	For more info
Please see this [full guide][fullguidedoc].



[myGH]:https://github.com/reizlejade/Trade-Policy-Analysis-Tool
[maindir]:https://asiandevbank.sharepoint.com/teams/org_ermr/ADO/2022/ADO/Part%20I/External%20Sector/Reizle/Trade%20Policy%20Analysis%20Tool
[fullguidedoc]:https://asiandevbank.sharepoint.com/:w:/r/teams/org_ermr/ADO/2022/ADO/Part%20I/External%20Sector/Reizle/Trade%20Policy%20Analysis%20Tool/03Documentation/TPAtool_Full%20Guide.docx?d=w1405292295e04cefb2b2a5b8fd0d4eb2&csf=1&web=1&e=vdqUbe
