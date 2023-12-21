* create TFL dataset for Table 14-3.01 from PDF report-tlf-pilot3 *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname ADAM "&mypath.\ORIGADAM"; 
libname TFL "&mypath.\TFL datasets"; 

proc datasets library=work memtype=data kill nolist;
run;
quit;

DM "out;clear;log;clear;";


***----------------***;
*** Bring in data  ***;
***----------------***;
proc sort data= adam.adadas(where=(anl01fl="Y" and paramcd="ACTOT" and avisitn in(0 24))) out=ad01;
  by usubjid;
run;

proc sort data= adam.adsl(where=(efffl="Y")) out=sl01;
  by usubjid;
run;

data tb01;
  merge sl01(in=a)
        ad01(in=b);
  by usubjid;
  if a;
run;

proc sort data=tb01;
  by trt01pn avisitn;
run;

proc sort data=tb01(keep=usubjid trt01p: avisit: aval chg ablfl anl01fl base sitegr1 efffl) out=tb02;
  by trt01pn avisitn;
run;

***----------------***;
***      Big N     ***;
***----------------***;
proc freq data=sl01 noprint;
  table trt01pn*trt01p / out=bign(drop= percent);
run;

proc freq data=tb01 noprint;
  table trt01pn*trt01p*avisitn*avisit / out=smalln(drop= percent);
run;

***-----------------------------------***;
***  placing bign on output dataset   ***;
***-----------------------------------***;
data tb03a;
  merge tb02(in=a drop=avisit avisitn aval chg anl01fl sitegr1 base ablfl)
        bign(in=b);
  by trt01pn;
  if a;
  SRCDOM="ADSL";
  SRCVAR="EFFFL";
  srcvlabl="Efficacy Population Flag";
  rename count=T_N;
run;

***------------------***;
***  Summary Stats   ***;
***------------------***;
**Baseline and Week 24 Summary stats**;
proc means data=tb01 noprint;
  by trt01pn avisitn ;
  var aval;
  output out=st02(DROP= _TYPE_ _FREQ_) n=T_N mean=T_MEAN stddev=T_SD median=T_MEDIAN min=T_MIN max=T_MAX;
run; 

**Change from Baseline Summary stats**;
proc means data=tb01(where=(avisitn>0)) noprint;
  by trt01pn ;
  var chg;
  output out=st03(DROP= _TYPE_ _FREQ_) n=T_N mean=T_MEAN stddev=T_SD median=T_MEDIAN min=T_MIN max=T_MAX ;
run; 

***-----------------------------------------***;
***  placing summ stats on output dataset   ***;
***-----------------------------------------***;
data tb03b;
  merge tb02(in=a drop=chg sitegr1)
		st02(in=b);
  by trt01pn avisitn;
  if b;
  if avisitn=0 then do;
    SRCVAR="BASE";
    srcvlabl="Baseline Value";
	AVAL=.;
	ordvar=2;
  end;
  else do;
    SRCVAR="AVAL";
	srcvlabl="Analysis Value";
	Base=.;
    ordvar=3;
  end;
  T_SD=round(T_SD,0.01);
  format T_SD 5.2;
  T_MEAN=round(T_MEAN,0.1);
  T_MIN=round(T_MIN, 1);
  T_MAX=round(T_MAX, 1);
  SRCDOM="ADADAS";
run;

data tb03c;
  merge tb02(in=a Where=(ablfl^="Y") drop=sitegr1 aval base)
        st03(in=b);
  by trt01pn;
  if b;
  T_SD=round(T_SD,0.01);
  format T_SD 5.2;
  T_MEAN=round(T_MEAN,0.1);
  T_MIN=round(T_MIN, 1);
  T_MAX=round(T_MAX, 1);
  SRCVAR="CHG";	
  srcvlabl="Change from Baseline";
  SRCDOM="ADADAS";
run;

***-----------------------------***;
***  P-value CHG from BL        ***;
***-----------------------------***;
* ancova *; 
* [1] Based on Analysis of covariance (ANCOVA) model with treatment and site group as factors and baseline
      value as a covariate. *;
* [2] Test for a non-zero coefficient for treatment (dose) as a continuous variable *;

ods select none;
proc glm data=tb01(where=(avisitn=24));
  class sitegr1;
  model chg=trt01pn sitegr1 base / solution;
  ods output ModelANOVA=ModelANOVA (where=(HypothesisType=3 and source='TRT01PN')) /* p-Value Type III Model Anova */
  ;
run;
quit;
ods select all;

data chg01;
  set modelanova(in=a)
      modelanova(in=b)
      modelanova(in=c);
  if a then trt01pn=0;
  else if b then trt01pn=54;
  else if c then trt01pn=81;
  T_PVALUE=round(probf,0.001);
  keep T_PVALUE trt01pn;
run;

data tb03d;
  merge tb02(in=a where=(avisitn=24) drop=aval)
        chg01(in=b);
  by trt01pn;
  if b;
  SRCVAR="CHG/BASE/TRT01PN/SITEGR1";	
  srcvlabl="Variables used in ANCOVA(Dose Response)";
  SRCDOM="ADADAS";
run;

***-----------------------------***;
***  P-value Xan-Placebo        ***;
***-----------------------------***;
data p01;
  set tb01;
  if trt01pn=0 then trt01pn=99;
run;

* ancova *; 
* [1] Based on Analysis of covariance (ANCOVA) model with treatment and site group as factors and baseline
      value as a covariate. *;
* [3] Pairwise comparison with treatment as a categorical variable: p-values without adjustment for multiplePairwise 
      comparison with treatment as a categorical variable: p-values without adjustment for multiplecomparisons. *;

ods graphics on;
**base is the covariate**;
proc glm data=p01 ;
  class trt01pn sitegr1;
  model chg = trt01pn sitegr1 base / solution;
      lsmeans trt01pn sitegr1/pdiff stderr cl;
	  ods output lsmeancl=lsmeancl                     /* LS mean (95% CI) for each trt            */
                 lsmeandiffcl=lsmeandiffcl             /* Diff in LS mean (95% CI) Xan vs Placebo  */ 
                 ParameterEstimates=ParameterEstimates /* p-Value Xan vs Placebo                   */
			     ;
run;
quit;
ods graphics off;

data pval01;
  set lsmeandiffcl(where=(trt01pn^=. and j=3));
  if trt01pn=99 then trt01pn=0;
  T_LSMEANDIFFUCI=round(uppercl,0.1);
  T_LSMEANDIFFLCI=round(lowercl,0.1); 
  T_LSMEANDIFF=round(difference,0.1);
  keep trt01pn T_LSMEANDIFFUCI T_LSMEANDIFFLCI T_LSMEANDIFF;
run;

data pval01a;
  set pval01(in=a where=(trt01pn=54))
      pval01(in=b where=(trt01pn=54));
      if a then trt01pn=0;
run;

data pval01b;
  set pval01(in=a where=(trt01pn=81))
      pval01(in=b where=(trt01pn=81));
      if a then trt01pn=0;
run;

data pval02;
  set parameterestimates(where=(index(parameter,"TRT") and stderr^=.));
  trt01pn=input(substr(parameter,8),8.);
  T_LSMEANDIFFSE=round(stderr, 0.01);
  T_PVALUE=round(probt,0.001);
  keep trt01pn T_LSMEANDIFFSE T_PVALUE;
run;

data pval02a;
  set pval02(in=a where=(trt01pn=54))
      pval02(in=b where=(trt01pn=54));
      if a then trt01pn=0;
run;

data pval02b;
  set pval02(in=a where=(trt01pn=81))
      pval02(in=b where=(trt01pn=81));
      if a then trt01pn=0;
run;


data tb03e;
  merge tb02(in=a where=(avisitn>0 and trt01pn^=81) drop=aval)
        pval01a(in=b)
        pval02a(in=c);
  by trt01pn;
  if a;
  SRCVAR="CHG/TRT01PN/SITEGR1/BASE";	
  srcvlabl="Variables used in Pairwise Comparison(Xan Low - Placebo)";
  SRCDOM="ADADAS";
run;

data tb03f;
  merge tb02(in=a where=(avisitn>0 and trt01pn^=54) drop=aval)
        pval01b(in=b)
        pval02b(in=c);
  by trt01pn;
  if a;
  SRCVAR="CHG/TRT01PN/SITEGR1/BASE";	
  srcvlabl="Variables used in Pairwise Comparison(Xan High - Placebo)";
  SRCDOM="ADADAS";
run;


***-----------------------------***;
***  P-value Xan high-xan low   ***;
***-----------------------------***;
* ancova *; 
* [1] Based on Analysis of covariance (ANCOVA) model with treatment and site group as factors and baseline
      value as a covariate. *;
* [3] Pairwise comparison with treatment as a categorical variable: p-values without adjustment for multiplePairwise 
      comparison with treatment as a categorical variable: p-values without adjustment for multiplecomparisons. *;
ods graphics on;
**base is the covariate**;
proc glm data=tb01(where=(avisitn=24)) ;
  class trt01pn sitegr1;
  model chg = trt01pn sitegr1 base / solution;
      lsmeans trt01pn /pdiff stderr cl;
	  ods output lsmeancl=lsmeancl01                     /* LS mean (95% CI) for each trt                  */
                 lsmeandiffcl=lsmeandiffcl01             /* Diff in LS mean (95% CI) High Dose vs low dose */
                 ParameterEstimates=ParameterEstimates01 /* p-Value High Dose vs low dose                  */
			     ;
run;
quit;
ods graphics off;

data hilo01;
  set lsmeandiffcl01(where=(trt01pn^=0 and j=3));
  **switching uci and lci due to stats program output;
  T_LSMEANDIFFUCI=round((lowercl*-1),0.1);
  T_LSMEANDIFFLCI=round((uppercl*-1),0.1); 
  T_LSMEANDIFF=round((difference*-1),0.01);
  trt01pn=81; *setting to high dose trt value*;
  keep trt01pn T_LSMEANDIFFLCI T_LSMEANDIFFUCI T_LSMEANDIFF;
run;

data hilo01a;
  set hilo01(in=a)
      hilo01(in=b);
  if a then trt01pn=54;
run;

data hilo02;
  set parameterestimates01(where=(index(parameter,"54") and stderr^=.));
  trt01pn=81; *setting to high dose trt value*;
  T_LSMEANDIFFSE=round(stderr, 0.01);
  T_PVALUE=round(probt,0.001);
  keep trt01pn T_LSMEANDIFFSE T_PVALUE;
run;

data hilo02a;
  set hilo02(in=a)
      hilo02(in=b);
  if a then trt01pn=54;
run;

data tb03g;
  length SRCVAR $25;
  merge tb02(in=a where=(avisitn>0) drop=aval)
        hilo01a(in=b)
        hilo02a(in=c);
  by trt01pn;
  if a and c;
  SRCVAR="CHG/TRT01PN/SITEGR1/BASE";	
  srcvlabl="Variables used in Pairwise Comparison(Xan High - Xan Low)";
  SRCDOM="ADADAS";
run;

***--------------------------------------***;
***  Setting datasets into final output  ***;
***--------------------------------------***;
data tb04;
  length ordvar 8 SRCVAR $25 SRCVLABL $65 SRCDOM $10;
  set tb03a(in=a)
      tb03b(in=b)
	  tb03c(in=c)
	  tb03d(in=d)
	  tb03e(in=e)
  	  tb03f(in=f)
      tb03g(in=g);
  if a then ORDVAR=1;
  else if c then ORDVAR=4;
  else if d then ORDVAR=5;
  else if e then ORDVAR=6;
  else if f then ORDVAR=7;
  else if g then ORDVAR=8;
  label srcdom='Source Data'
        srcvar='Source Variable'
        srcvlabl='Source Variable Label';
run;

proc sql noprint; 
  create table tb05 as
  select ordvar, trt01pn, trt01p, avisitn, avisit, sitegr1, usubjid, srcdom, srcvar, srcvlabl, aval, base, chg, efffl, ablfl, ANL01FL, 
         t_n, t_mean, t_sd, t_median, t_min, t_max, t_pvalue, t_lsmeandiff, t_LSMEANDIFFSE, t_lsmeandifflci, t_lsmeandiffuci
  from tb04
  order by ordvar, trt01pn, trt01p;
quit; 

proc sort data=tb05 out=tfl.T14_3_01_map(label="Table 14_3_01 - Adascog");
  by ordvar trt01pn trt01p;
run;
