* create TFL dataset for Table 14-3.02 from PDF report-tlf-pilot3 *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname ADAM "&mypath.\ORIGADAM"; 
libname TFL "&mypath.\TFL datasets"; 


* get baseline records *;
proc sort data=adam.adlbc (where=(paramcd='GLUC' and trtpn in (0,81) and ablfl='Y'))
           out=baserecs (keep=trtp: usubjid base param: ablfl); 
  by trtpn trtp;
run; 

* get week 20 records *; 
proc sort data=adam.adlbc (where=(paramcd='GLUC' and trtpn in (0,81) and avisitn=20))
           out=wk20 (keep=trtp: usubjid aval chg base param: ); 
  by trtpn trtp;
run; 

* summary stats *;
proc means data=baserecs noprint; 
  by trtpn trtp;
  var base;
  output out=basestat(drop=_:) n=n mean=mean std=sd;
run; 

proc means data=wk20 noprint; 
  by trtpn trtp;
  var aval;
  output out=wk20stat(drop=_:) n=n mean=mean std=sd;
run; 

proc means data=wk20 noprint; 
  by trtpn trtp;
  var chg;
  output out=chgstat(drop=_:) n=n mean=mean std=sd;
run; 

* Pairwise comparison - LS means / CIs / p-value / Root MSE   *;
* change value of Placebo TRTPN to 99 for pairwise comparison *;
data wk20a;
  set wk20;
  if trtpn=0 then trtpn=99;  
run; 

proc sort data=wk20a;
  by trtpn trtp;
run; 

ods select none;

proc glm data=wk20a;
  class trtpn;
  model chg=trtpn base / solution;
  lsmeans trtpn / pdiff cl;
  ods output lsmeancl=lsmeancl                     /* LS mean (95% CI) for each trt                 */
             lsmeandiffcl=lsmeandiffcl             /* Diff in LS mean (95% CI) High Dose vs Placebo */
             FitStatistics=FitStatistics           /* Root Mean Squared Error High Dose vs Placebo  */
             ParameterEstimates=ParameterEstimates /* p-Value High Dose vs Placebo                  */
			 ;
run;
quit;

ods select all;

* convert TRTPN back to numeric and original value for PLACEBO *; 
data lsmeancl2 (rename=(_trtpn=trtpn));
  set lsmeancl;
  if trtpn='99' then trtpn='0';
  _trtpn=input(trtpn,8.);  
  drop trtpn;
run; 

proc sort data=lsmeancl2;
  by trtpn;
run; 

* create extra record for merge with subject level data *; 
data lsmeandiffcl2;
  set lsmeandiffcl(in=a)
      lsmeandiffcl(in=b);
  if a then trtpn=_trtpn;  
  drop effect dependent i j _trtpn;
run; 

proc sort data=lsmeandiffcl2;
  by trtpn;
run; 

data parameterestimates2;
  set parameterestimates (in=a where=(index(parameter,'81')>0))
      parameterestimates (in=b where=(index(parameter,'81')>0));
  if a then trtpn=81;
  else if b then trtpn=99;
  keep trtpn probt;
run; 

data fitstatistics2;
  set fitstatistics (in=a)
      fitstatistics (in=b);
  if a then trtpn=81;
  else if b then trtpn=99;
  keep trtpn rootmse;
run; 

* merge results with subject level records *; 

data _base;  
  merge baserecs(in=a)
        basestat(in=b);
  by trtpn trtp;
  if a; 
  length T_N T_MEAN T_SD 8. SRCDOM $5 SRCVAR $14 SRCVLABL $37;
  t_n=n;
  t_mean=round(mean,0.1);
  t_sd=round(sd,0.01);
  srcdom='ADLBC';
  srcvar='BASE';
  srcvlabl='Baseline Value';
  drop n mean sd;
run; 

data _wk20;  
  merge wk20(in=a drop=base chg)
        wk20stat(in=b);
  by trtpn trtp;
  if a; 
  length T_N T_MEAN T_SD 8. SRCDOM $5 SRCVAR $14 SRCVLABL $37;
  t_n=n;
  t_mean=round(mean,0.1);
  t_sd=round(sd,0.01);
  srcdom='ADLBC';
  srcvar='AVAL';
  srcvlabl='Analysis Value';
  drop n mean sd;
run; 

data _chg;  
  merge wk20(in=a drop=aval base)
        chgstat(in=b)
		lsmeancl2(in=c drop=effect dependent);
  by trtpn;
  if a; 
  length T_N T_MEAN T_SD T_LSMEAN T_LSMEANLCI T_LSMEANUCI 8. SRCDOM $5 SRCVAR $14 SRCVLABL $37;
  t_n=n;
  t_mean=round(mean,0.1);
  t_sd=round(sd,0.01);
  t_lsmean=round(lsmean,0.01);
  t_lsmeanlci=round(lowercl,0.01);
  t_lsmeanuci=round(uppercl,0.01);
  srcdom='ADLBC';
  srcvar='CHG';
  srcvlabl='Change from Baseline';
  drop n mean sd lsmean lowercl uppercl;
run; 

data _pairwise;  
  merge wk20a(in=a drop=aval)        
		lsmeandiffcl2(in=b)	
		parameterestimates2(in=c)
		fitstatistics2(in=d);
  by trtpn;
  if a; 
  length T_LSMEANDIFF T_LSMEANDIFFLCI T_LSMEANDIFFUCI T_PVALUE T_ROOTMSE 8. SRCDOM $5 SRCVAR $14 SRCVLABL $37;
  t_lsmeandiff=round(difference,0.01);
  t_lsmeandifflci=round(lowercl,0.01);
  t_lsmeandiffuci=round(uppercl,0.01);
  t_pvalue=round(probt,0.001);
  t_rootmse=round(rootmse,0.01);
  srcdom='ADLBC';
  srcvar='CHG/BASE/TRTPN';
  srcvlabl='Variables used in Pairwise Comparison';
  drop difference lowercl uppercl probt rootmse;
run; 

data all;
  set _base (in=a)
      _wk20 (in=b)
      _chg  (in=c)
	  _pairwise (in=d);
  if a then ordvar=1;
  else if b then ordvar=2;
  else if c then ordvar=3;
  else if d then ordvar=4;
  label srcdom='Source Data'
        srcvar='Source Variable'
        srcvlabl='Source Variable Label';
run;  
 
proc sql noprint; 
  create table gluc_map as
  select ordvar, trtpn, trtp, usubjid, srcdom, srcvar, srcvlabl, aval, base, chg, ablfl, t_n, t_mean, t_sd, t_lsmean, t_lsmeanlci, t_lsmeanuci,
         t_lsmeandiff, t_lsmeandifflci, t_lsmeandiffuci, t_pvalue, t_rootmse
  from all
  order by ordvar, trtpn, trtp;
quit; 

data tfldata.T14_3_02_map (label="Table 14_3_02 - Glucose");
  set gluc_map; 
run; 
