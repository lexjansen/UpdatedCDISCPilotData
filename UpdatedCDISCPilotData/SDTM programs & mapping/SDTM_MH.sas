* create SDTM MH from CDASH datasets *; 

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

proc sort data=cdash.mh out=mh01;
  by studyid subjid;
run;

data mh02;
  length USUBJID $11 MHSEV $8;
  set mh01(rename=(mhsev=mhsevo MHSOC=MHBODSYS));
  ***USUBJID***;
  USUBJID=strip(substr(studyid,11, 2))||"-"||strip(siteid)||"-"||strip(subjid);
  DOMAIN="MH";
  ***VISITDY/VISITNUM***;
  if visit="SCREENING 1" then do; 
    VISITNUM=1; 
    VISITDY=-7; 
  end;
  ***MHSEV***;
  if mhsevo=1 then mhsev="MILD";
  else if mhsevo=2 then MHSEV="MODERATE";
  else if mhsevo=3 then MHSEV="SEVERE";
run;

proc sort data=mh02 out= mh03;
  by usubjid;
run;

data mh04;
  merge mh03(in=a)
        dm(in=b);
  by usubjid;
  if a;
  ***MHDTC***;
  MHDTC= put(input(MHdat, date11.), e8601da.);
  **MHSTDTC**;
  if length(mhstdat)=11 then MHSTDTC=put(input(mhstdat,date11.), e8601da.);
  else if length(mhstdat)=8 then mhstdtc=substr(mhstdat,5,4)||'-'||put(substr(mhstdat,1,3),$month.);
  else if length(mhstdat)=4 then MHSTDTC=mhstdat;
  **MHDY**;
  rfstdt=input(rfstdtc, yymmdd10.);
  if length(mhdat)=11 then do;
    mhstdt=input(mhdat, date11.);
    if mhstdt>=rfstdt then mhdy=(mhstdt-rfstdt)+1;
    else mhdy=mhstdt-rfstdt;
  end;
   **creating order for cmseq**;
  seqord=input(substr(mhstdtc,1,4), 4.);
  if length(mhstdtc)=7 then do;
	seqord2=input(substr(mhstdtc,6,2), 2.);
  end;
  else if length(mhstdtc)=10 then do;
	seqord2=input(substr(mhstdtc,6,2), 2.);
    seqord3=input(substr(mhstdtc,9), 2.);
  end;
  if mhterm=:"VERB" then seqord4=input(substr(mhterm,10, 4), 4.);
run;

proc sort data=mh04 out=mh05;
  by usubjid seqord seqord2 seqord3 seqord4;
run;

data mh06;
  set mh05;
  by usubjid seqord seqord2 seqord3;
  retain MHSEQ 1;
  if first.usubjid then MHSEQ=1;
  else MHSEQ=MHSEQ+1;
run;

proc sort data=mh06 out=mh07;
  by usubjid seqord4 seqord seqord2 seqord3 ;
run;

data sdtm.mh (label="Medical History"); 
  attrib STUDYID  length=$12  label="Study Identifier"
         DOMAIN   length=$2   label="Domain Abbreviation"
         USUBJID  length=$11  label="Unique Subject Identifier"
         MHSEQ    length=8    label="Sequence Number"
         MHSPID   length=$3   label="Sponsor-Defined Identifier"
         MHTERM   length=$19  label="Reported Term for the Medical History"
         MHLLT    length=$200 label="Lowest Level Term"
         MHDECOD  length=$44  label="Dictionary-Derived Term"
         MHHLT    length=$200 label="High Level Term"
         MHHLGT   length=$200 label="High Level Group Term"
         MHCAT    length=$34  label="Category for Medical History"
         MHBODSYS length=$67  label="Body System or Organ Class"
         MHSEV    length=$8   label="Severity/Intensity"
         VISITNUM length=8    label="Visit Number"
         VISIT    length=$19  label="Visit Name"
         VISITDY  length=8    label="Planned Study Day of Visit"
         MHDTC    length=$10  label="Date/Time of History Collection"
         MHSTDTC  length=$10  label="Start Date/Time of Medical History Event"
         MHDY     length=8    label="Study Day of History Collection";
  set mh07;
  keep STUDYID DOMAIN USUBJID
       MHSEQ MHSPID MHTERM MHLLT 
       MHDECOD MHHLT MHHLGT MHCAT MHBODSYS
       MHSEV VISITNUM VISIT VISITDY
       MHDTC MHSTDTC MHDY;
run;
        

proc contents data=sdtm.mh varnum;
run;

proc compare data=origsdtm.mh compare=sdtm.mh listall;
run;

