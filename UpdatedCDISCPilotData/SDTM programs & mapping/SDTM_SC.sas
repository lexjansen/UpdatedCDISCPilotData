* create SDTM SC from CDASH datasets *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;


data d1;
  length DOMAIN SCORRES SCSTRESC $2 SCORRESU SCSTRESU $5 SCTESTCD $8 SCCAT $9 SCDTC $10 USUBJID $11 SCTEST $18 SCSEQ 8. ;
  set cdash.sc;    
  by studyid siteid subjid; 
  * DOMAIN *;
  domain='SC';
  * USUBJID *;
  usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);
  * SCSEQ *;
  if first.subjid then scseq=1;
  * SCTEST *;
  sctest=strip(edlevel_sctest);
  * SCTESTCD *;
  sctestcd=substr(sctest,1,2)||scan(sctest,2);
  * SCCAT *;
  sccat=strip(edlevel_sccat);
  * SCORRES *;
  scorres=strip(edlevel_scorres);
  * SCORRESU *;
  scorresu=strip(edlevel_scorresu);
  * SCSTREC *;
  scstresc=strip(scorres);
  * SCSTREN *;
  scstresn=input(scorres,8.);
  * SCSTRESU *;
  scstresu=strip(scorresu);
  * SCDAT *;  
  scdtc=put(input(scdat,date11.),e8601da.); 
  label domain='Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		scseq='Sequence Number'
		sctestcd='Subject Characteristic Short Name'
		sctest='Subject Characteristic'
		sccat='Category for Subject Characteristic'
        scorres='Result or Finding in Original Units'
		scorresu='Original Units'
		scstresc='Character Result/Finding in Std Format'
		scstresn='Numeric Result/Finding in Standard Units'
		scstresu='Standard Units'
		scdtc='Date/Time of Collection';
run; 

* merge in SDTM.DM.RFSTDTC for SCDY calculation *; 

proc sort data=d1;
  by studyid usubjid;
run; 

data d2;
  length SCDY 8.;
  merge d1 (in=a)
        sdtm.dm (in=b keep=studyid usubjid rfstdtc);
  by studyid usubjid;
  if a;
  * SCDY *;
  if scdat^='' then _scdtc=input(scdat,date11.);
  if rfstdtc^='' then do;
    _rfstdtc=input(rfstdtc,e8601da.);   
    if _scdtc>=_rfstdtc then scdy=(_scdtc-_rfstdtc) + 1;
    else scdy=_scdtc-_rfstdtc;
  end;
  label scdy='Study Day of Examination';
run; 

proc sql noprint;
  create table SC as
         select studyid, domain, usubjid, scseq, sctestcd, sctest, sccat, scorres, scorresu, scstresc,
		        scstresn, scstresu, scdtc, scdy
		 from d2;
quit;

* permanent dataset *;

proc sort data=sc
           out=sdtm.sc (label='Subject Characteristics');
  by studyid usubjid;
run; 

proc contents data=sdtm.sc varnum;
run; 

options ls=200 ps=200;

proc compare base=origsdtm.sc
             compare=sdtm.sc listall;
  id studyid usubjid;
run; 
