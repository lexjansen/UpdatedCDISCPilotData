* create ADSL dataset *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname adam2 "&mypath.\ADaM2"; 
libname sdtm "&mypath.\SDTM" access=readonly; 
libname origadam "&mypath.\ORIGADAM" access=readonly;


proc format;
  value $discon
    'COMPLETED'='Completed'
    'ADVERSE EVENT'='Adverse Event'
    'DEATH'='Death'
    'LACK OF EFFICACY'='Lack of Efficacy'
    'LOST TO FOLLOW-UP'='Lost to Follow-up'
    'PHYSICIAN DECISION'='Physician Decision'
    'PROTOCOL VIOLATION'='Protocol Violation'
    'STUDY TERMINATED BY SPONSOR'='Sponsor Decision'
    'WITHDRAWAL BY SUBJECT'='Withdrew Consent';

  value $dsterm
	'PROTOCOL VIOLATION'='I/E Not Met';

  invalue race
    'WHITE'=1
    'BLACK OR AFRICAN AMERICAN'=2  
    'AMERICAN INDIAN OR ALASKA NATIVE'=6
    'ASIAN'=7;

  invalue trt01xn
    'Pbo'=0
    'Xan_Lo'=54
    'Xan_Hi'=81;

  value agegr1n
    1='<65'
    2='65-80'
    3='>80';

run; 

* get treatment start dates from SDTM.EX for derivation of CUMDOSE and COMP24FL *; 
data ex;
  set sdtm.ex;
  exstdtc2=input(exstdtc,e8601da.);
run; 

proc transpose data=ex 
                out=ex2 (drop=_:);
  by studyid usubjid;
  var exstdtc2;
  id visit;
run; 

* get last dose date from SDTM.EX for TRTEDT derivation *; 
proc sort data=ex;
  by studyid usubjid descending exseq;
run; 

data lastex;
  set ex;
  by studyid usubjid descending exseq;
  if first.usubjid;
  keep studyid usubjid exendtc;
run; 

* get info from SDTM.QS for derivation of EFFFL *;
proc sort data=sdtm.qs (where=(qscat=:'ALZ' and visitnum>3) keep=studyid usubjid qscat visitnum)
           out=qscog (rename=(qscat=_cogfl)) nodupkey;
  by studyid usubjid;
run;  

proc sort data=sdtm.qs (where=(qscat=:'CLIN' and visitnum>3) keep=studyid usubjid qscat visitnum)
           out=qscibic (rename=(qscat=_cibicfl)) nodupkey;
  by studyid usubjid;
run;  

* using SDTM.LB in place of SDTM.SV to get visit info for derivation of COMP8FL COMP16FL COMP24FL *;
proc sort data=sdtm.lb (where=(visitnum in (1,8,10,12)) keep=studyid usubjid visit: lbdtc)
           out=lb nodupkey;
  by studyid usubjid visit;
run; 

data lb2;
  set lb;
  lbdtc2=input(substr(lbdtc,1,10),e8601da.);
run; 

proc transpose data=lb2
                out=lb3 (drop=_: rename=(week_24=week_24lb));
  by studyid usubjid ;
  var lbdtc2;
  id visit; 
run; 

* get baseline height and weight from SDTM.VS *;

proc sort data=sdtm.vs (where=(vstestcd='HEIGHT' and visitnum=1) keep=studyid usubjid vstestcd vsstresn visitnum vsdtc)
           out=vshgt (rename=(vsstresn=_height) drop=vstestcd visitnum);
  by studyid usubjid;
run; 

proc sort data=sdtm.vs (where=(vstestcd='WEIGHT' and visitnum=3) keep=studyid usubjid vstestcd vsstresn visitnum)
           out=vswgt (rename=(vsstresn=_weight) drop=vstestcd visitnum);
  by studyid usubjid;
run; 

* derive MMSETOT from SDTM.QS *; 

proc summary data=sdtm.qs (where=(qscat=:'MINI')) noprint; 
  by studyid usubjid;
  var qsstresn; 
  output out=mmse (drop=_:) sum=qssum;
run; 

* get week 8 / 24 date from SDTM.CM to use in derivation of COMP8FL and COMP24FL;
data cm1a;
  set sdtm.cm (where=(visitnum=8));
  by studyid usubjid;
  week_8cm=input(cmdtc,e8601da.);  
  if first.usubjid;
  keep studyid usubjid week_8cm ;
run;

data cm1b;
  set sdtm.cm (where=(visitnum=12));
  by studyid usubjid;
  week_24cm=input(cmdtc,e8601da.);  
  if first.usubjid;
  keep studyid usubjid week_24cm;
run;

data d1;
  length ITTFL SAFFL EFFFL COMP8FL COMP16FL COMP24FL DISCONFL DSRAEFL $1 SITEGR1 $3 DURDSGR1 $4 AGEGR1 $5 BMIBLGR1 $6 EOSSTT $12 DCSREAS $18 DCDECOD $27 TRT01P TRT01A $20
         TRTSDT TRTEDT TRT01PN TRT01AN TRTDURD CUMDOSE AVGDD AGEGR1N RACEN HEIGHTBL WEIGHTBL BMIBL EDUCLVL VISIT1DT DISONSDT DURDIS VISNUMEN RFENDT MMSETOT 8. ;
  merge sdtm.dm (in=a where=(armcd^=:'S'))
        sdtm.ds (in=b where=(dscat=:'D') rename=(visitnum=dsvisnum) drop=dsseq dsspid visit dsstdy)
		ex2 (in=c)
		lastex (in=c2)
		qscog (in=d)
        qscibic (in=e)
		lb3 (in=f)
		vshgt (in=g)
		vswgt (in=h)
		sdtm.sc (in=i keep=studyid usubjid scstresn)
		sdtm.mh (in=j where=(mhcat='PRIMARY DIAGNOSIS') keep=studyid usubjid mhcat mhstdtc)
		mmse (in=k)
		cm1a (in=l)
        cm1b (in=m);
  by studyid usubjid;
  if a; 
  * SITEGR1 *;
  if siteid in ('702','706','707','711','714','715','717') then sitegr1='900';
  else sitegr1=strip(siteid);
  * TRT01P *;
  trt01p=strip(arm);
  * TRT01PN *;
  trt01pn=input(armcd,trt01xn.);
  * TRT01A *;
  trt01a=strip(actarm);            
  * TRT01AN *;
  trt01an=input(actarmcd,trt01xn.);  
  * TRTSDT *;
  trtsdt=input(rfxstdtc,e8601da.);  
  * TRTEDT *;
  if exendtc^='' then trtedt=input(rfxendtc,e8601da.);  
  else trtedt=input(dsstdtc,e8601da.);    
  * TRTDURD *; 
  trtdurd=(trtedt-trtsdt)+1;
  * RFENDT *;
  rfendt=input(rfendtc,e8601da.);   
  * CUMDOSE *; 
  if trt01pn < 81 then cumdose=trt01pn*trtdurd;  
  else if trt01pn=81 then do; 
    if dsdecod='COMPLETED' or (dsdecod^='COMPLETED' and trtedt>week_24 and week_24^=.) then do;
      w2cumd=54*((week_2-trtsdt)+1);
	  w24cumd=81*(week_24-week_2);
	  p24cumd=54*(trtedt-week_24);
	  cumdose=w2cumd+w24cumd+p24cumd;
	end; 
	else do;	 
      if week_2=. then w2cumd=54*((trtedt-trtsdt)+1);
      else if week_2^=. then w2cumd=54*(week_2-trtsdt);
	  if week_2^=. and week_24=. then w24cumd=81*((trtedt-week_2)+1);	  
      if w24cumd^=. then cumdose=w2cumd+w24cumd;
	  else cumdose=w2cumd;
	end; 
  end; 
  * AVGDD *;
  if cumdose>0 then avgdd=round((cumdose/trtdurd),0.1);
  else avgdd=cumdose;
  format trtsdt trtedt date9. ;
  * AGEGR1N *;  
  if age<65 then agegr1n=1;
  else if age<=80 then agegr1n=2;
  else if age>80 then agegr1n=3;
  * AGEGR1 *; 
  agegr1=put(agegr1n,agegr1n.);
  * RACEN *;
  racen=input(race,race.);
  * ITTFL *;
  if armcd^='' then ittfl='Y';
  else ittfl='N';
  * SAFFL *;
  if ittfl='Y' and trtsdt^=. then saffl='Y';
  else saffl='N';
  * EFFFL *;
  if saffl='Y' and _cogfl^='' and _cibicfl^='' then efffl='Y';
  else efffl='N';
  * COMP8FL *;
  if week_8^=. or week_8cm^=. then comp8fl='Y';
  else comp8fl='N';
  * COMP16FL *;
  if week_16^=. then comp16fl='Y';
  else comp16fl='N';
  * COMP24FL *;
  if week_24lb^=. or week_24cm^=. then comp24fl='Y';
  else comp24fl='N';
  * DCDECOD *;
  dcdecod=strip(dsdecod);
  * DCSREAS *;     
  if dcdecod^='COMPLETED' and dsterm^=:'PROTOCOL ENTRY' then dcsreas=put(dcdecod,$discon.); 
  else if dcdecod^='COMPLETED' and dsterm=:'PROTOCOL ENTRY' then dcsreas=put(dcdecod,$dsterm.); 
  * DISCONFL *;
  if dcsreas^='' then disconfl='Y';
  * DSRAEFL *;
  if dcsreas='Adverse Event' then dsraefl='Y';
  * HEIGHTBL *;
  if _height^=. then heightbl=round(_height,0.1);
  * WEIGHTBL *;
  if _weight^=. then weightbl=round(_weight,0.1);
  * BMIBL *;
  if weightbl^=. and heightbl^=. then bmibl=round((weightbl/((heightbl/100)**2)),0.1);
  * BMIBLGR1 *; 
  if .<bmibl<25 then bmiblgr1='<25';
  else if 25<=bmibl<30 then bmiblgr1='25-<30';
  else if bmibl>=30 then bmiblgr1='>=30';
  * EDUCLVL *;
  educlvl=scstresn;
  * DISONSDT *;
  disonsdt=input(mhstdtc,e8601da.);  
  * VISIT1DT *; 
  visit1dt=input(vsdtc,e8601da.);  
  * DURDIS *;
  durnumer=(visit1dt-disonsdt)+1;
  durdenom=365.25/12; 
  durdis=round((durnumer/durdenom),0.1);
  * DURDSGR1 *;
  if durdis<12 then durdsgr1='<12';
  else if durdis>=12 then durdsgr1='>=12';
  * VISNUMEN *;
  if dsdecod in ('COMPLETED','ADVERSE EVENT') and dsvisnum=13 then visnumen=dsvisnum-1;
  else visnumen=dsvisnum;
  * EOSSTT *;
  if dcdecod='COMPLETED' then eosstt=strip(dcdecod);
  else eosstt='DISCONTINUED';
  * MMSETOT *;
  mmsetot=qssum;  
  format trtsdt trtedt disonsdt visit1dt rfendt date9.;
  informat trtsdt trtedt disonsdt visit1dt rfendt date9.;
  label ittfl='Intent-To-Treat Population Flag'
        saffl='Safety Population Flag'
        efffl='Efficacy Population Flag'
		comp8fl='Completers of Week 8 Population Flag'
		comp16fl='Completers of Week 16 Population Flag'
        comp24fl='Completers of Week 24 Population Flag'
		disconfl='Did the Subject Discontinue the Study?'
		dsraefl='Discontinued due to AE?'
		dthfl='Subject Died?'
		sitegr1='Pooled Site Group 1'
		durdis='Duration of Disease (Months)'
        durdsgr1='Pooled Disease Duration Group 1'
		agegr1='Pooled Age Group 1'
		agegr1n='Pooled Age Group 1 (N)'
		bmibl='Baseline BMI (kg/m^2)'
		bmiblgr1='Pooled Baseline BMI Group 1'
		eosstt='End of Study Status'
        dcsreas='Reason for Discontinuation from Study'
        dcdecod='Standardized Disposition Term'
		trt01p='Planned Treatment for Period 01'
		trt01pn='Planned Treatment for Period 01 (N)'
        trt01a='Actual Treatment for Period 01'
		trt01an='Actual Treatment for Period 01 (N)'
		trtsdt='Date of First Exposure to Treatment'
		trtedt='Date of Last Exposure to Treatment'
        trtdurd='Total Treatment Duration (Days)'
		cumdose='Cumulative Dose (as planned)'
		avgdd='Avg Daily Dose (as planned)'
        racen='Race (N)'
		heightbl='Baseline Height (cm)'
        weightbl='Baseline Weight (kg)'
		educlvl='Years of Education'
		visit1dt='Date of Visit 1'
		disonsdt='Date of Onset of Disease'
		visnumen='End of Trt Visit (Vis 12 or Early Term.)'
		rfendt='Date of Discontinuation/Completion'
        mmsetot='MMSE Total'		
		;
run;

proc sql noprint; 
  alter table d1
  modify ageu char(5)
  modify race char(32)
  modify ethnic char(22)
  modify rfstdtc char(20)
  modify rfendtc char(20);
quit;

proc sql noprint;
  create table ADSL as
         select STUDYID, USUBJID, SUBJID, SITEID, SITEGR1, ARM, ACTARM, TRT01P, TRT01PN, TRT01A, TRT01AN, TRTSDT, TRTEDT, TRTDURD,
                AVGDD, CUMDOSE, AGE, AGEGR1, AGEGR1N, AGEU, RACE, RACEN, SEX, ETHNIC, SAFFL, ITTFL, EFFFL, COMP8FL, COMP16FL,
                COMP24FL, DISCONFL, DSRAEFL, DTHFL, BMIBL, BMIBLGR1, HEIGHTBL, WEIGHTBL, EDUCLVL, DISONSDT, DURDIS, DURDSGR1,
                VISIT1DT, RFSTDTC, RFENDTC, VISNUMEN, RFENDT, DCDECOD, EOSSTT, DCSREAS, MMSETOT
		 from d1;
quit;

* permanent dataset *;

proc sort data=adsl
           out=adam2.adsl (label='Subject-Level Analysis Dataset');
  by studyid usubjid;
run; 

proc contents data=adam2.adsl varnum;
run; 

options ls=200 ps=200;

proc compare base=origadam.adsl
             compare=adam2.adsl listall;
  id studyid usubjid;
run; 
