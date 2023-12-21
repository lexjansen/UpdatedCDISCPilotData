* create SDTM DM from CDASH datasets*; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;


* get first dose info for RFSTDTC RFXSTDTC *;

data firstdos;
  length RFSTDTC $10 RFXSTDTC $20 ;
  set cdash.ex (where=(visit='BASELINE'));
  rfstdtc=put(input(exstdat,date11.),e8601da.);  
  rfxstdtc=put(input(exstdat,date11.),e8601da.);  
  keep studyid siteid subjid rf: ;
run; 

* get Subject Reference End Date/Time info RFENDTC - inconsistent with instruction in ORIG SDTM define *; 
* (Date/time of last study drug treatment derived from EX)                                             *;
* actual derivation uses CDASH.DSDAT of last disposition event                                         *;

data ref_end;  
  length RFENDTC $10;
  set cdash.ds (in=b where=(dscat='DISPOSITION EVENT'));
  by studyid siteid subjid;
  if last.subjid; 
  rfendtc=put(input(dsdat,date11.),e8601da.);    
  keep studyid siteid subjid rf: ;
run; 

* get last dose info for RFXENDTC *;

data lastdos;
  length RFXENDTC $20 ;
  set cdash.ex (where=(exendat^=''));
  by studyid siteid subjid;
  if last.subjid;  
  rfxendtc=put(input(exendat,date11.),e8601da.);  
  keep studyid siteid subjid rf: ;
run; 

* get date/time end of participation for RFPENDTC - inconsistent with instruction in ORIG SDTM define *; 
* (DSSTDTC of last disposition event)                                                                 *;
* Original SDTM.DM.RFPENDTC contains dates that are not the DSSTDTC of the last dispostion event and  *;
* the dates do not exist in any other original SDTM domain                                            *; 
* E.g. USUBJID=01-701-1057  RFPENDTC=2013-12-27 - original SDTM.DS.DSSTDTC=2013-12-20                 *;

data rfp_arm;
  length RFPENDTC $20 ;
  set cdash.x1;
  if rfpentim='' then rfpendtc=put(input(rfpendat,date11.),e8601da.);  
  else rfpendtc=put(input(rfpendat,date11.),e8601da.)||'T'||strip(rfpentim);  
  label rfpendtc='Date/Time of End of Participation';
  drop rfpendat rfpentim;
run; 

* get highest dose taken for derivation of ACTARM and ACTARMCD *; 

proc sort data=cdash.ex
           out=highex;
  by studyid siteid subjid descending exdstxt;
run; 

data highex2;
  set highex;
  by studyid siteid subjid descending exdstxt;
  if first.subjid;
  keep studyid siteid subjid extrt exdstxt;
run; 

* get death date for DTHDTC *; 

data death;
  length DTHDTC $20 ;
  set cdash.ds (where=(dsterm='DEATH'));
  * DTHDTC *;        
  dthdtc=put(input(dthdat,date11.),e8601da.);    
  keep studyid siteid subjid dthdtc;
run; 

data d1;
  length DTHFL $1 DOMAIN $2 ACTARMCD $8 DMDTC $10 USUBJID $11 ACTARM RFICDTC $20 RACE $78 DMDY 8.;
  merge cdash.dm (in=a rename=(race=orace))
        firstdos (in=b)
		ref_end (in=c)
		lastdos (in=d)
		rfp_arm (in=e)
		highex2 (in=f)
		death (in=g);
  by studyid siteid subjid;
  if a;
  * DOMAIN *;
  domain='DM';
  * USUBJID *;
  usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);
  * RFENDTC updated for subjects that are screen failures *;
  if rfstdtc='' then rfendtc=rfstdtc;
  * RFICDTC *;
  rficdtc='';
  * DTHFL *; 
  if dthdtc^='' then dthfl='Y';
  * RACE *; 
  if orace=:'CA' then race='WHITE';
  else if orace='AF' then race='BLACK OR AFRICAN AMERICAN';
  else if orace in ('EA','AS') then race='ASIAN';
  else if orace='O' then race='AMERICAN INDIAN OR ALASKA NATIVE';
  * DMDTC *;  
  dmdtc=put(input(dmdat,date11.),e8601da.);    
  * DMDY *;
  if dmdtc^='' then _dmdtc=input(dmdat,date11.);
  if rfstdtc^='' then do;
    _rfstdtc=input(rfstdtc,e8601da.);   
    if _dmdtc>=_rfstdtc then dmdy=(_dmdtc-_rfstdtc) + 1;
    else dmdy=_dmdtc-_rfstdtc;
  end;
  * ACTARM ACTARMCD *;
  if arm=:'S' or (arm=:'P' and extrt=:'P') or (index(arm,'Low')>0 and exdstxt='54') or (index(arm,'High')>0 and exdstxt='81')  then do;
    actarmcd=strip(armcd);   
    actarm=strip(arm);
  end; 
  else if (index(arm,'High')>0 and exdstxt='54') then do;       
    actarmcd='Xan_Lo';                                      * actual trt is different from randomized trt *; 
	actarm='Xanomeline Low Dose';                           * actual trt is different from randomized trt *;
  end; 
  label domain='Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		rfstdtc='Subject Reference Start Date/Time'
		rfendtc='Subject Reference End Date/Time'
        rfxstdtc='Date/Time of First Study Treatment'
		rfxendtc='Date/Time of Last Study Treatment'
		rficdtc='Date/Time of Informed Consent'
		rfpendtc='Date/Time of End of Participation'
        actarm='Description of Actual Arm'
		actarmcd='Actual Arm Code'
		dthdtc='Date/Time of Death'
		dthfl='Subject Death Flag'
        race='Race'
        dmdtc='Date/Time of Collection'
		dmdy='Study Day of Collection'; 
run;

proc sql noprint;
  create table DM as
         select studyid, siteid, domain, usubjid, subjid, rfstdtc, rfendtc, rfxstdtc, rfxendtc, rficdtc, rfpendtc,
                dthdtc, dthfl, age, ageu, sex, race, ethnic, country, arm, armcd, actarm, actarmcd, dmdtc, dmdy
		 from d1;
quit;

* permanent dataset *;

proc sort data=dm
           out=sdtm.dm (label='Demographics');
  by studyid usubjid;
run; 

proc contents data=sdtm.dm varnum;
run; 

options ls=200 ps=200;

proc compare base=origsdtm.dm
             compare=sdtm.dm listall;
  id studyid usubjid;
run; 
