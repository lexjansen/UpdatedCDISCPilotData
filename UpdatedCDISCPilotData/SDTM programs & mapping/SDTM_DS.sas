* create SDTM DS from CDASH datasets and SDTM.LB *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;

proc format;
  invalue visnum
  'SCREENING 1'=1
  'UNSCHEDULED 1.1'=1.1
  'UNSCHEDULED 1.2'=1.2
  'UNSCHEDULED 1.3'=1.3
  'BASELINE'=3
  'AMBUL ECG PLACEMENT'=3.5
  'WEEK 2'=4
  'UNSCHEDULED 4.1'=4.1
  'UNSCHEDULED 4.2'=4.2  
  'WEEK 4'=5
  'UNSCHEDULED 5.1'=5.1
  'AMBUL ECG REMOVAL'=6
  'UNSCHEDULED 6.1'=6.1
  'WEEK 6'=7
  'UNSCHEDULED 7.1'=7.1
  'WEEK 8'=8
  'UNSCHEDULED 8.2'=8.2
  'WEEK 12'=9
  'UNSCHEDULED 9.2'=9.2
  'UNSCHEDULED 9.3'=9.3  
  'WEEK 16'=10
  'WEEK 20'=11
  'WEEK 24'=12
  'UNSCHEDULED 12.1'=12.1
  'WEEK 26'=13
  'UNSCHEDULED 13.1'=13.1
  'RETRIEVAL'=201;

run;

* get final visit info from SDTM.LB *; 

proc sort data=sdtm.lb (keep=studyid usubjid visit visitnum lbdtc lbdy)
           out=finallab;
  by usubjid visitnum;
run; 

data finallab2;
  set finallab;
  by usubjid visitnum;
  if last.usubjid;
run; 

data d1;
  length DOMAIN $2 SUBJID $4 DSDTC $19 DSSTDTC $10 VISITNUM 8.;
  set cdash.ds (in=a)
      finallab2 (in=b);
  * DOMAIN *;
  domain='DS';
  * USUBJID *;
  if a then usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);
  * DSDTC *;  
  if a then dsdtc=put(input(dsdat,date11.),e8601da.); 
  else if b then dsdtc=strip(lbdtc);
  * DSSTDTC *;
  if a then dsstdtc=put(input(dsstdat,date11.),e8601da.); 
  else if b then dsstdtc=substr(lbdtc,1,10);
  * VISITNUM *;
  visitnum=input(visit,visnum.); 
  if b then do;
    * DSCAT *;
    dscat='OTHER EVENT';
	dsterm='FINAL LAB VISIT';
	dsdecod='FINAL LAB VISIT';
  end; 
  if a then flag='a';
  else if b then flag='b';
  label domain='Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		dsterm='Reported Term for the Disposition Event'
		dsdecod='Standardized Disposition Term'
		dscat='Category for Disposition Event'
		visitnum='Visit Number'
		dsdtc='Date/Time of Collection'
		dsstdtc='Start Date/Time of Disposition Event';
run; 

* merge in SDTM.DM.RFSTDTC for DSSTDY calculation *; 

proc sort data=d1;
  by studyid usubjid;
run; 

data d2;  
  length DSSTDY 8. ;
  merge d1 (in=a)
        sdtm.dm (in=b keep=studyid usubjid rfstdtc);
  by studyid usubjid;
  if a;
  * DSSTDY *;
  if flag='a' then do; 
    if dsstdat^='' then _dsdtc=input(dsstdat,date11.);
    if rfstdtc^='' then do;
      _rfstdtc=input(rfstdtc,e8601da.);   
      if _dsdtc>=_rfstdtc then dsstdy=(_dsdtc-_rfstdtc) + 1;
      else dsstdy=_dsdtc-_rfstdtc;
    end;
  end; 
  else if flag='b' then dsstdy=lbdy; 
  label dsstdy='Study Day of Start of Disposition Event';
run;

* set up DSSEQ *; 

proc sort data=d2;
  by studyid usubjid dscat visitnum descending dsdtc; 
run; 

data d3;
  length DSSEQ 8. ;
  set d2;
  by studyid usubjid dscat visitnum descending dsdtc;
  retain dsseq;
  if first.usubjid then dsseq=0;
  dsseq=dsseq+1;
  label dsseq='Sequence Number';
run;  

proc sql noprint;
  create table DS as
         select studyid, domain, usubjid, dsseq, dsspid, dsterm, dsdecod, dscat, visitnum, visit,
                dsdtc, dsstdtc, dsstdy
		 from d3;
quit;

* permanent dataset *;

proc sort data=ds
           out=sdtm.ds (label='Disposition');
  by studyid usubjid dsdecod dsstdtc;
run; 

proc contents data=sdtm.ds varnum;
run; 


proc sort data=origsdtm.ds
           out=origds;
  by usubjid dsseq;
run; 

proc sort data=sdtm.ds 
           out=ds;
  by usubjid dsseq;
run; 


proc compare base=origds
             compare=ds listall;
  id usubjid dsseq;
run; 
