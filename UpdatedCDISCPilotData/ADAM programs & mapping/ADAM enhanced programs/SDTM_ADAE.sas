* create ADAE dataset *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname adam2 "&mypath.\ADaM2"; 
libname sdtm "&mypath.\SDTM" access=readonly; 
libname origadam "&mypath.\ORIGADAM" access=readonly;

* get dosing dates for derivation of TRTA dose at time of AE *; 

data pex;
  set sdtm.ex;
  exstdtc2=input(exstdtc,e8601da.);
  if visit='BASELINE' then visit='WEEK 0';
  visit=tranwrd(visit,'WEEK ','W');
run;

proc transpose data=pex
                out=pex2a (drop=_:);
  by studyid usubjid;
  var exstdtc2;
  id visit;
run;

proc transpose data=pex
                out=pex2b (drop=_: ) prefix=X;
  by studyid usubjid;
  var exdose;
  id visit;
run;

data pex3;
  merge pex2a(in=a)
        pex2b(in=b);
  by studyid usubjid;
  if a;
run;

data d1;
  length ASTDTF TRTEMFL $1 ADURU $4 CQ01NAM $19 TRTP TRTA $20 
         TRTPN TRTAN ASTDY ASTDT AENDT AENDY ADURN 8. ;
  merge sdtm.ae (in=a)
        adam2.adsl (in=b keep=studyid usubjid siteid age: race: sex saffl trt: )
		pex3 (in=c);
  by studyid usubjid;
  if a; 
  * ASTDT ASTDTF *;
  lenstdt=length(aestdtc);
  if lenstdt=10 then astdt=input(substr(aestdtc,1,10),e8601da.);
  else if lenstdt=7 then do;
    _aestdtc=strip(aestdtc)||'-01';
	astdtf='D';
    astdt=input(substr(_aestdtc,1,10),e8601da.);
  end;   
  * ASTDY *;  
  if astdt^=. then do;
    if astdt>=trtsdt then astdy=(astdt-trtsdt)+1;
    else if astdt<trtsdt then astdy=astdt-trtsdt;
  end; 
  * AENDT *;
  if aeendtc^='' then aendt=input(substr(aeendtc,1,10),e8601da.);
  * AENDY *;  
  if aendt^=. then do;
    if aendt>=trtsdt then aendy=(aendt-trtsdt)+1;
    else if aendt<trtsdt then aendy=aendt-trtsdt;
  end; 
  * ADURN *;
  if astdt^=. and aendt^=. then adurn=(aendt-astdt)+1;
  * ADURU *;
  if adurn^=. then aduru='DAYS';
  * TRTEMFL *;
  if astdt^=. and astdt>=trtsdt then trtemfl='Y';
  * TRTP TRTPN *;
  if trtemfl='Y' then do;
    trtp=strip(trt01p);
    trtpn=trt01pn;
  end;
  * TRTA TRTAN *;  
  if index(trt01a,'High')>0 then do;
    if xw24=54 and astdt>=w24 then do;
      trta='Xanomeline Low Dose';
	  trtan=xw24;
	end;
    else if xw2=81 and astdt>=w2 then do;
      trta=strip(trt01a);
	  trtan=xw2;
	end;
    else if xw0=54 and astdt>=w0 then do;
      trta='Xanomeline Low Dose';
	  trtan=xw0;
	end;
  end; 
  else if trtemfl='Y' then do;
    trta=strip(trt01a);  
    trtan=trt01an;
  end; 
  * CQ01NAM *;
  if trtemfl='Y' then do; 
    if index(aedecod,'APPLICATION')>0 or index(aedecod,'DERMATITIS')>0 or index(aedecod,'ERYTHEMA')>0 or index(aedecod,'BLISTER')>0 or
     (aebodsys='SKIN AND SUBCUTANEOUS TISSUE DISORDERS' and aedecod not in ('COLD SWEAT','HYPERHIDROSIS','ALOPECIA')) then cq01nam='DERMATOLOGIC EVENTS';
  end; 
  format astdt aendt date9. ;
  informat astdt aendt date9. ;
run;

data flags d2a;
  set d1;
  if trtemfl='Y' then output flags;
  else output d2a;
run;  

proc sort data=flags;
  by usubjid astdt aeseq;
run;

data flags2;
 length AOCCFL $1 ;
  set flags;
  by usubjid astdt aeseq;
  if first.usubjid then aoccfl='Y';
run; 

proc sort data=flags2;
  by usubjid aebodsys astdt aeseq;
run;

data flags3;
 length AOCCSFL $1 ;
  set flags2;
  by usubjid aebodsys astdt aeseq;
  if first.aebodsys then aoccsfl='Y';
run; 

proc sort data=flags3;
  by usubjid aebodsys aedecod astdt aeseq;
run;

data flags4;
 length AOCCPFL $1 ;
  set flags3;
  by usubjid aebodsys aedecod astdt aeseq;
  if first.aedecod then aoccpfl='Y';
run; 

data flags5 d2b;
  set flags4;
  if aeser='Y' then output flags5;
  else output d2b;
run;

proc sort data=flags5;
  by usubjid astdt aeseq;
run;

data flags6;
 length AOCC02FL $1 ;
  set flags5;
  by usubjid astdt aeseq;
  if first.usubjid then aocc02fl='Y';
run; 

proc sort data=flags6;
  by usubjid aebodsys astdt aeseq;
run;

data flags7;
 length AOCC03FL $1 ;
  set flags6;
  by usubjid aebodsys astdt aeseq;
  if first.aebodsys then aocc03fl='Y';
run; 

proc sort data=flags7;
  by usubjid aebodsys aedecod astdt aeseq;
run;

data flags8;
 length AOCC04FL $1 ;
  set flags7;
  by usubjid aebodsys aedecod astdt aeseq;
  if first.aedecod then aocc04fl='Y';
run; 

data flags9 d2c;
  set flags8 d2b;
  if cq01nam^='' then output flags9;
  else output d2c;
run;

proc sort data=flags9;
  by usubjid cq01nam astdt aeseq;
run;

data flags10;
 length AOCC01FL $1 ;
  set flags9;
  by usubjid cq01nam astdt aeseq;
  if first.cq01nam then aocc01fl='Y';
run; 

data d3;
  set flags10 d2a d2c;
  label trtp='Planned Treatment'
        trtpn='Planned Treatment (N)'
        trta='Actual Treatment'
        trtan='Actual Treatment (N)'
        astdt='Analysis Start Date'
        astdtf='Analysis Start Date Imputation Flag'
        astdy='Analysis Start Relative Day'
        aendt='Analysis End Date'
        aendy='Analysis End Relative Day'
        adurn='Analysis Duration (N)'
        aduru='Analysis Duration Units'
        trtemfl='Treatment Emergent Analysis Flag'
        aoccfl='1st Occurrence within Subject Flag'
        aoccsfl='1st Occurrence of SOC Flag'
        aoccpfl='1st Occurrence of Preferred Term Flag'
        aocc02fl='1st Occurrence 02 Flag for Serious'
        aocc03fl='1st Occurrence 03 Flag for Serious SOC'
        aocc04fl='1st Occurrence 04 Flag for Serious PT'
        cq01nam='Customized Query 01 Name'
        aocc01fl='1st Occurrence 01 Flag for CQ01';
run; 

proc sql noprint; 
  alter table d3
  modify aeterm char(46)
  modify aellt char(46)
  modify aedecod char(46)
  modify aehlt char(8)
  modify aehlgt char(9)
  modify aesoc char(67)
  modify aeacn char(1)
  modify aeout char(26);
quit;

proc sql noprint;
  create table ADAE as
         select STUDYID, SITEID, USUBJID, TRT01P, TRT01PN, TRT01A, TRT01AN, TRTP, TRTPN, TRTA, TRTAN, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX, SAFFL, TRTSDT, TRTEDT,
                ASTDT, ASTDTF, ASTDY, AENDT, AENDY, ADURN, ADURU, AETERM, AELLT, AELLTCD, AEDECOD, AEPTCD, AEHLT, AEHLTCD,
                AEHLGT, AEHLGTCD, AEBODSYS, AESOC, AESOCCD, AESEV, AESER, AESCAN, AESCONG, AESDISAB, AESDTH, AESHOSP,
                AESLIFE, AESOD, AEREL, AEACN, AEOUT, AESEQ, TRTEMFL, AOCCFL, AOCCSFL, AOCCPFL, AOCC02FL, AOCC03FL, AOCC04FL,
                CQ01NAM, AOCC01FL
		 from d3;
quit;

* permanent dataset *;

proc sort data=adae
           out=adam2.adae (label='Adverse Events Analysis Dataset');
  by studyid usubjid aeterm astdt aeseq;
run; 

proc contents data=adam2.adae varnum;
run; 

options ls=200 ps=200;

proc compare base=origadam.adae
             compare=adam2.adae listall;
  id studyid usubjid aeterm astdt aeseq;
run; 
