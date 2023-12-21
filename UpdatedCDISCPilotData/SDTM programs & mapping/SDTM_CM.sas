* create SDTM CM from CDASH datasets *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;

proc format;
  value $month
  'JAN' = '01' 
  'FEB' = '02' 
  'MAR' = '03' 
  'APR' = '04' 
  'MAY' = '05' 
  'JUN' = '06' 
  'JUL' = '07' 
  'AUG' = '08'
  'SEP' = '09'
  'OCT' = '10'
  'NOV' = '11'
  'DEC' = '12';
run; 

proc sort data=sdtm.dm(keep=usubjid rfstdtc) out=dm;
  by usubjid;
run;

proc sort data=cdash.cm out=cm01;
  by studyid subjid;
run;

data cm02;
  length USUBJID $11;
  set cm01;
  ***USUBJID***;
  USUBJID=strip(substr(studyid,11, 2))||"-"||strip(siteid)||"-"||strip(subjid);
  DOMAIN="CM";
  ***VISITDY/VISITNUM***;
  if      visit="SCREENING 1"         then do; VISITNUM=1 ;   VISITDY=-7;  end;
  else if visit="SCREENING 2"         then do; VISITNUM=2 ;   VISITDY=-1;  end;
  else if visit="BASELINE"            then do; VISITNUM=3 ;   VISITDY=1;   end;
  else if visit="WEEK 2"              then do; VISITNUM=4 ;   VISITDY=14;  end;
  else if visit="WEEK 4"              then do; VISITNUM=5 ;   VISITDY=28;  end;
  else if visit="AMBUL ECG REMOVAL"   then do; VISITNUM=6 ;   VISITDY=30;  end;
  else if visit="WEEK 6"              then do; VISITNUM=7 ;   VISITDY=42;  end;
  else if visit="WEEK 8"              then do; VISITNUM=8 ;   VISITDY=56;  end;
  else if visit="WEEK 12"             then do; VISITNUM=9 ;   VISITDY=84;  end;
  else if visit="WEEK 16"             then do; VISITNUM=10 ;  VISITDY=112; end;
  else if visit="WEEK 20"             then do; VISITNUM=11 ;  VISITDY=140; end;
  else if visit="WEEK 24"             then do; VISITNUM=12 ;  VISITDY=168; end;
  else if visit="WEEK 26"             then do; VISITNUM=13 ;  VISITDY=182; end;
  else if visit="AE FOLLOW-UP"        then do; VISITNUM=101 ; VISITDY=.; end;
  else if visit="RETRIEVAL"           then do; VISITNUM=201 ; VISITDY=168; end; 
run;

proc sort data=cm02;
  by usubjid;
run;

data cm03;
  merge cm02(in=a)
        dm(in=b);
  by usubjid;
  if a;
  **CMDTC**;
  CMDTC= put(input(visdat, date11.), e8601da.);
  **CMSTDTC**;
  if length(cmstdat)=11 then CMSTDTC=put(input(cmstdat,date11.), e8601da.);
  else if length(cmstdat)=8 then cmstdtc=substr(cmstdat,5,4)||'-'||put(substr(cmstdat,1,3),$month.);
  else if length(cmstdat)=4 then CMSTDTC=cmstdat;
  **CMENDTC**;
  if length(cmendat)=11 then CMENDTC=put(input(cmendat,date11.), e8601da.);
  else if length(cmendat)=8 then cmendtc=substr(cmendat,5,4)||'-'||put(substr(cmendat,1,3),$month.);
  **CMSTDY**;
  rfstdt=input(rfstdtc, yymmdd10.);
  if length(cmstdat)=11 then do;
    cmstdt=input(cmstdat, date11.);
    if cmstdt>=rfstdt then cmstdy=(cmstdt-rfstdt)+1;
    else cmstdy=cmstdt-rfstdt;
  end;
  **CMENDY**;
  if length(cmendat)=11 then do;
    cmendt=input(cmendat, date11.);
    if cmendt>=rfstdt then cmendy=(cmendt-rfstdt)+1;
    else cmendy=cmendt-rfstdt;
  end;
  **creating order for cmseq**;
  seqord=input(substr(cmstdtc,1,4), 4.);
  if length(cmstdtc)=7 then do;
	seqord2=input(substr(cmstdtc,6,2), 2.);
  end;
  else if length(cmstdtc)=10 then do;
	seqord2=input(substr(cmstdtc,6,2), 2.);
    seqord3=input(substr(cmstdtc,9), 2.);
  end;
  drop cmendt rfstdt: cmstdt;
run;

proc sort data=cm03 out=cm04;
  by usubjid visitnum seqord seqord2 seqord3 cmtrt cmspid;
run;

data cm05;
  set cm04;
  by usubjid visitnum seqord seqord2 seqord3 cmtrt cmspid;
  retain CMSEQ 1;
  if first.usubjid then CMSEQ=1;
  else CMSEQ=CMSEQ+1;
run;

***-----------------------------------------***;
*** - match CMSEQ values to original SDTM - ***;
***-----------------------------------------***;
proc sort data=cm05 out=bin nodupkey dupout=brec;
  by STUDYID DOMAIN USUBJID CMTRT CMDECOD CMINDC CMCLAS CMDOSE CMDOSU CMDOSFRQ CMROUTE
     VISITNUM VISIT VISITDY CMDTC CMSTDTC CMENDTC CMSTDY CMENDY;
run;

proc sort data=brec nodupkey out= brec01;
  by usubjid cmtrt visitdy ;
run;

proc sort data=cm05 out=breccm;
  by usubjid cmtrt visitdy;
run;

data brec02;
  merge breccm(in=a)
        brec01(in=b keep=usubjid cmtrt visitdy);
  by usubjid cmtrt visitdy;
  if b;
  if cmtrt="HYDROCORTISONE, TOPICAL" and seqord=2013 then do;
    if visitdy in(56 84 112 ) then output;
  end;
  else if cmtrt="HYDROCORTISONE, TOPICAL" and seqord=2012 then do;
    if visitdy in(1 168 ) then output;
  end;
  else if cmtrt="VITAMINS" then do;
    if visitdy in(182) then output;
  end;
  keep usubjid cmseq cmspid cmtrt visitdy seqord ;
run;

proc sort data=brec02;
  by usubjid visitdy cmspid;
  
data brec03;
  set brec02;  
  by usubjid visitdy cmspid;
  if first.visitdy then cmseq=cmseq+1;
  else cmseq=cmseq-1;
run;

proc sort data=cm05;
  by usubjid cmtrt visitdy cmspid;
run;

data cm06;
  merge cm05(in=a)
        brec03(in=b keep=usubjid cmtrt visitdy cmspid cmseq);
  by usubjid cmtrt visitdy cmspid;
  if a;
run;

proc sort data=cm06 out=cm07;
  by USUBJID cmtrt cmstdy cmindc visitnum cmseq;
run;

data sdtm.CM (label="Concomitant Medications");
  attrib
    STUDYID  length=$12  label="Study Identifier"
    DOMAIN   length=$2   label="Domain Abbreviation"
    USUBJID  length=$11  label="Unique Subject Identifier"
    CMSEQ    length=8    label="Sequence Number"
    CMSPID   length=$2   label="Sponsor-Defined Identifier"
    CMTRT    length=$44  label="Reported Name of Drug, Med, or Therapy"
    CMDECOD  length=$24  label="Standardized Medication Name"
    CMINDC   length=$34  label="Indication"
    CMCLAS   length=$42  label="Medication Class"
    CMDOSE   length=8    label="Dose per Administration"
    CMDOSU   length=$17  label="Dose Units"
    CMDOSFRQ length=$15  label="Dosing Frequency per Interval"
    CMROUTE  length=$200 label="Route of Administration"
    VISITNUM length=8    label="Visit Number"
    VISIT    length=$19  label="Visit Name"
    VISITDY  length=8    label="Planned Study Day of Visit"
    CMDTC    length=$10  label="Date/Time of Collection"
    CMSTDTC  length=$10  label="Start Date/Time of Medication"
    CMENDTC  length=$10  label="End Date/Time of Medication"
    CMSTDY   length=8    label="Study Day of Start of Medication"
    CMENDY   length=8    label="Study Day of End of Medication";
  set cm07;
  keep STUDYID DOMAIN USUBJID
       CMSEQ CMSPID CMTRT CMDECOD CMINDC
       CMCLAS CMDOSE CMDOSU CMDOSFRQ CMROUTE
       VISITNUM VISIT VISITDY
       CMDTC CMSTDTC CMENDTC
       CMSTDY CMENDY;
run;

proc contents data=sdtm.cm varnum;
run;


options ls=200 ps=200;

proc compare data=origsdtm.cm compare=sdtm.cm listall;
  id studyid usubjid cmtrt cmstdtc cmseq cmspid;
run;




