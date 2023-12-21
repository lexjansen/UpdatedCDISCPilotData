* create ADADAS dataset *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname adam "&mypath.\ADaM"; 
libname sdtm "&mypath.\SDTM" access=readonly; 
libname origadam "&mypath.\ORIGADAM" access=readonly;


proc format;
  invalue parcd 
  "ACITM01"=1
  "ACITM02"=2
  "ACITM03"=3
  "ACITM04"=4
  "ACITM05"=5
  "ACITM06"=6
  "ACITM07"=7
  "ACITM08"=8
  "ACITM09"=9
  "ACITM10"=10
  "ACITM11"=11
  "ACITM12"=12
  "ACITM13"=13
  "ACITM14"=14
  "ACTOT"=15;
run;
    
proc sort data=sdtm.qs(keep=studyid usubjid visitnum visit qstest qstestcd qsdy qsdtc qsstresn qsblfl qsseq rename=(visit=visita)) out=qs01;
  by usubjid;
run;

data qs01;
  length visit $17;
  set qs01;
  visit=visita;
  drop visita;
run;

proc sort data=adam.adsl(keep=studyid usubjid siteid sitegr1 subjid trtsdt trtedt trt01p trt01pn age 
                              agegr1 agegr1n sex race racen ittfl efffl comp24fl) out=sl01;
  by usubjid;
run;

data AS01;
  length paramcd $7;
  merge qs01(in=a where=(qstestcd in("ACTOT" "ACITM09" "ACITM04" "ACITM12" "ACITM05" "ACITM03" "ACITM06" "ACITM10" 
                                     "ACITM02" "ACITM07" "ACITM14" "ACITM11" "ACITM12" "ACITM13" "ACITM01" "ACITM08")))
        sl01(in=b);
  by usubjid;
  if a;
  TRTP=trt01p;
  TRTPN=trt01pn;
  PARAM=propcase(qstest);
  ADT=input(qsdtc, yymmdd10.);
  AVAL=QSSTRESN;
  ABLFL=QSBLFL;
  if adt>=trtsdt then ADY=adt-trtsdt+1;
  else if adt<trtsdt then ADY=adt-trtsdt+1;
  PARAMCD=qstestcd;
  if ady<=1 then do; vis1="Baseline"; vis1n=0; end;
  else if 2<=ady<=84 then do; vis1="Week 8"; vis1n=8; end;
  else if 85<=ady<=140 then do; vis1="Week 16"; vis1n=16; end;
  else if ady>140 then do; vis1="Week 24"; vis1n=24; end;
  format adt date9.;
  informat adt date9.;
  drop qstestcd qstest qsdtc qsstresn qsblfl  trt01p:;
run;

***BASE***;
data base;
  set AS01(where=(ablfl="Y"));
  BASE=aval;
  keep usubjid paramcd base;
run;

proc sort data=base;
  by usubjid paramcd;
run;

**DTYPE LOCF**;
data LOCF01;
  set AS01(where=(paramcd="ACTOT"));
run;

proc sort data=as01(where=(paramcd="ACTOT")) out= temp(keep= usubjid paramcd param studyid  siteid sitegr1 subjid trtsdt trtedt age 
                                                             agegr1 agegr1n sex race racen ittfl efffl comp24fl trtp trtpn adt) nodupkey;
  by usubjid;
run;

data temp01;
  set temp;
  by usubjid;
  do i=1 to 4;
    if i=1 then vis1n=0;
	else if i=2 then vis1n=8;
	else if i=3 then vis1n=16;
	else if i=4 then vis1n=24;
    output;
  end;
run;

proc sort data=temp01;
  by usubjid vis1n;
run;

proc sort data=locf01;
  by usubjid vis1n;
run;

data locf02;
length viscnew $19;
  merge temp01(in=a)
        locf01(in=b);
  by usubjid vis1n;
  if aval=. then do;
    DTYPE="LOCF";
  end;
  retain valnew visnew viscnew adynew adtnew qsnew;
  if first.usubjid then do;
    valnew=.;
	visnew=.;
	adynew=.;
	adtnew=.;
	qsnew=.;
	viscnew="";
  end;
  if aval ne . then do;
    valnew=aval;
	visnew=visitnum;
	viscnew=visit;
	adtnew=adt;
	adynew=ady;
	qsnew=qsseq;
  end;
  rename visit=visorig visitnum=visnorig;
run;

***-----------------------------------***;
***Bringing in LOCF into main dataset ***;
***-----------------------------------***;
data AS02;
  set AS01(where=(paramcd^="ACTOT"))
      locf02;
  if paramcd="ACTOT" then do;
    visit=viscnew;
	visitnum=visnew;
  end;
  if dtype="LOCF" then do;
    ady=adynew;
	aval=valnew;
	adt=adtnew;
	qsseq=qsnew;
	if vis1n=0 then vis1="Baseline";
    else if vis1n=8 then vis1="Week 8"; 
    else if vis1n=16 then vis1="Week 16"; 
    else if vis1n=24 then vis1="Week 24"; 
  end;
  rename vis1n=AVISITN vis1=AVISIT;
  drop viscnew i valnew visnew adynew visorig visnorig adtnew qsnew;
run;

proc sort data=AS02 out= AS03;
  by usubjid paramcd;
run;

data AS04;
  length awrange $6;
  merge AS03(in=a)
        base(in=b);
  by usubjid paramcd;
  if a;
  if ablfl^="Y" then do;
    if aval^=. and base^=. then CHG=AVAL-BASE;
	if base>0 and chg^=. then PCHG=(CHG/BASE)*100;
  end;
  **AWRANGE/AWTARGET**;
  if avisitn=0 then do; AWRANGE="<=1"; AWTARGET=1; AWLO=.; AWHI=1; end;
  else if avisitn=8 then do; AWRANGE="2-84"; AWTARGET=56; AWLO=2; AWHI=84; end;
  else if avisitn=16 then do; AWRANGE="85-140"; AWTARGET=112; AWLO=85; AWHI=140; end;
  else if avisitn=24 then do; AWRANGE=">140"; AWTARGET=168; AWLO=141; AWHI=.; end;
  AWU="DAYS";
  if ady^=. and awtarget^=. then AWTDIFF= abs(ADY-AWTARGET);
run;

***-----------------------------------***;
***ANL01FL                            ***;
***-----------------------------------***;
proc sort data=as04 out=anl01;
  by usubjid paramcd avisitn awtdiff;
run;

data AS05;
  set anl01;
  by usubjid paramcd avisitn awtdiff;
  if first.avisitn then ANL01FL="Y";
  else ANL01FL="";
  paramn=input(paramcd,parcd.);
run;

proc sort data=as05;
  by usubjid paramcd avisit adt;
run;

data adam.ADADAS (label="ADAS-Cog Analysis");
  attrib
    STUDYID  length=$12  label="Study Identifier"
	SITEID   length=$3   label="Study Site Identifier"
    SITEGR1  length=$3   label="Pooled Site Group 1"
    USUBJID  length=$11  label="Unique Subject Identifier"
	TRTSDT   length=8    label="Date of First Exposure to Treatment"
    TRTEDT   length=8    label="Date of Last Exposure to Treatment"
    TRTP     length=$20  label="Planned Treatment"
    TRTPN    length=8    label="Planned Treatment (N)"
    AGE      length=8    label="Age"
    AGEGR1   length=$5   label="Pooled Age Group 1"
    AGEGR1N  length=8    label="Pooled Age Group 1 (N)"
    RACE     length=$32  label="Race"
    RACEN    length=8    label="Race (N)"
    SEX      length=$1   label="Sex"
    ITTFL    length=$1   label="Intent-To-Treat Population Flag"
    EFFFL    length=$1   label="Efficacy Population Flag"
    COMP24FL length=$1   label="Completers of Week 24 Population Flag"
    AVISIT   length=$8   label="Analysis Visit"
    AVISITN  length=8    label="Analysis Visit (N)"
    VISIT    length=$17  label="Visit Name"
    VISITNUM length=8    label="Visit Number"
    ADY      length=8    label="Analysis Relative Day"
    ADT      length=8    label="Analysis Date"
    PARAM    length=$40  label="Parameter"
    PARAMCD  length=$7   label="Parameter Code"
    PARAMN   length=8    label="Parameter (N)"
    AVAL     length=8    label="Analysis Value"
    BASE     length=8    label="Baseline Value"
    CHG      length=8    label="Change from Baseline"
    PCHG     length=8    label="Percent Change from Baseline"
    ABLFL    length=$1   label="Baseline Record Flag"
    ANL01FL  length=$1   label="Analysis Flag 01"
    DTYPE    length=$4   label="Derivation Type"
    AWRANGE  length=$6   label="Analysis Window Valid Relative Range"
    AWTARGET length=8    label="Analysis Window Target"
    AWTDIFF  length=8    label="Analysis Window Diff from Target"
    AWLO     length=8    label="Analysis Window Beginning Timepoint"
    AWHI     length=8    label="Analysis Window Ending Timepoint"
    AWU      length=$4   label="Analysis Window Unit"
    QSSEQ    length=8    label="Sequence Number"
	;
  set AS05;
  keep STUDYID SITEID SITEGR1 USUBJID
       TRTSDT TRTEDT TRTP TRTPN
       AGE AGEGR1 AGEGR1N RACE RACEN SEX
       ITTFL EFFFL COMP24FL
       AVISIT AVISITN VISIT VISITNUM ADY ADT
       PARAM PARAMCD PARAMN
       AVAL BASE CHG PCHG
       ABLFL ANL01FL DTYPE
       AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU QSSEQ;
run;

proc contents data=adam.adadas varnum;
run;

proc sort data=adam.adadas out=new;
  by usubjid paramcd avisit adt;
run;

proc sort data=origadam.adadas out=old;
  by usubjid paramcd avisit adt;
run;

proc compare data=old compare=new criterion=0.00001 listall;
run;

