* create SDTM EX from CDASH datasets *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;

proc format;
  invalue visnum
  'BASELINE'=3
  'WEEK 2'=4
  'WEEK 24'=12;

  invalue visdy
  'BASELINE'=1
  'WEEK 2'=14
  'WEEK 24'=168;

run; 

data d1;  
  length DOMAIN EXDOSFRQ $2 EXSTDTC EXENDTC $10 USUBJID $11 EXDOSE VISITNUM VISITDY 8. ;
  set cdash.ex;
  * DOMAIN *;
  domain='EX';
  * USUBJID *;
  usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);
  * EXDOSE *;
  exdose=input(exdstxt,8.);
  * VISITNUM *;
  visitnum=input(visit,visnum.); 
  * VISITDY *;
  visitdy=input(visit,visdy.); 
  * EXSTDTC *;  
  exstdtc=put(input(exstdat,date11.),e8601da.); 
  * EXENDTC *;
  if exendat^='' then exendtc=put(input(exendat,date11.),e8601da.); 
  label domain='Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		extrt='Name of Actual Treatment'
		exdose='Dose per Administration'
		exdosu='Dose Units'
		exdosfrm='Dose Form'
		exdosfrq='Dosing Frequency per Interval'
		exroute='Route of Administration'
		visitnum='Visit Number'
		visitdy='Planned Study Day of Visit'
		exstdtc='Start Date/Time of Treatment'
		exendtc='End Date/Time of Treatment';	
run; 

* merge in SDTM.DM.RFSTDTC for EXSTDY and EXENDY calculations *; 

proc sort data=d1;
  by studyid usubjid visitnum;
run; 

data d2;
  length EXSEQ EXSTDY EXENDY 8. ;
  merge d1 (in=a)
        sdtm.dm (in=b keep=studyid usubjid rfstdtc);
  by studyid usubjid;
  if a;
  retain exseq;
  * EXSEQ *;
  if first.usubjid then exseq=0;
  exseq=exseq+1;
  * EXSTDY EXENDY*;
  if exstdat^='' then _exstdtc=input(exstdat,date11.);
  if exendat^='' then _exendtc=input(exendat,date11.);
  if rfstdtc^='' then do;
    _rfstdtc=input(rfstdtc,e8601da.);       
    exstdy=(_exstdtc-_rfstdtc) + 1;
    if exendat^='' then exendy=(_exendtc-_rfstdtc) + 1;
  end;
  label exseq='Sequence Number'
        exstdy='Study Day of Start of Treatment'
		exendy='Study Day of End of Treatment';
run; 

proc sql noprint;
  create table EX as
         select studyid, domain, usubjid, exseq, extrt, exdose, exdosu, exdosfrm, exdosfrq, exroute, 
                visitnum, visit, visitdy, exstdtc, exendtc, exstdy, exendy
		 from d2;
quit;

* permanent dataset *;

proc sort data=ex
           out=sdtm.ex (label='Exposure');
  by studyid usubjid visitnum;
run; 

proc contents data=sdtm.ex varnum;
run; 

options ls=200 ps=200;

proc compare base=origsdtm.ex
             compare=sdtm.ex listall;
  id studyid usubjid visitnum;
run; 
