* create SDTM VS from CDASH datasets *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;

proc sort data=sdtm.dm(keep=usubjid rfstdtc) out=dm;
  by usubjid;
run;

proc sort data=cdash.vs out=vs01;
  by studyid subjid;
run;

data vs02;
  length USUBJID $11;
  set vs01;
  ***USUBJID***;
  USUBJID=strip(substr(studyid,11, 2))||"-"||strip(siteid)||"-"||strip(subjid);
  DOMAIN="VS";
  ***VISITDY/VISITNUM***;
  if      visit="SCREENING 1"         then do; VISITNUM=1 ;   VISITDY=-7;  end;
  else if visit="SCREENING 2"         then do; VISITNUM=2 ;   VISITDY=-1;  end;
  else if visit="BASELINE"            then do; VISITNUM=3 ;   VISITDY=1; VSBLFL="Y";  end;
  else if visit="UNSCHEDULED 3.1"     then do; VISITNUM=3.1 ; VISITDY=.;   end;
  else if visit="AMBUL ECG PLACEMENT" then do; VISITNUM=3.5 ; VISITDY=13;  end;
  else if visit="WEEK 2"              then do; VISITNUM=4 ;   VISITDY=14;  end;
  else if visit="WEEK 4"              then do; VISITNUM=5 ;   VISITDY=28;  end;
  else if visit="AMBUL ECG REMOVAL"   then do; VISITNUM=6 ;   VISITDY=30;  end;
  else if visit="WEEK 6"              then do; VISITNUM=7 ;   VISITDY=42;  end;
  else if visit="WEEK 8"              then do; VISITNUM=8 ;   VISITDY=56;  end;
  else if visit="WEEK 12"             then do; VISITNUM=9 ;   VISITDY=84;  end;
  else if visit="WEEK 16"             then do; VISITNUM=10 ;  VISITDY=112;  end;
  else if visit="WEEK 20"             then do; VISITNUM=11 ;  VISITDY=140; end;
  else if visit="WEEK 24"             then do; VISITNUM=12 ;  VISITDY=168; end;
  else if visit="WEEK 26"             then do; VISITNUM=13 ;  VISITDY=182; end;
  else if visit="RETRIEVAL"           then do; VISITNUM=201 ; VISITDY=168; end; 
run;

proc sort data=vs02;
  by usubjid;
run;

data vs03;
  merge vs02(in=a)
        dm(in=b);
  by usubjid;
  if a;
run;

***----------------------------------***;
***Layering different tests in decod ***;
***----------------------------------***;
data vs04;
  length vstestcd vsstresc $6 vstest $24;;
  set vs03 (in=a where=(vsorres^="" or (vsstat^="" and vsorres="")) keep=diabp: usubjid domain studyid vsblfl visit: rfstdtc 
                                                                  rename=(diabp_vspos=VSPOS diabp_vsorres=vsorres diabp_vsorresu=vsorresu 
                                                                          diabp_vsstat=vsstat diabp_vsdat=vsdtco diabp_vstpt=vstpt diabp_vstptnum=vstptnum))
	  vs03 (in=b where=(vsorres^="" or (vsstat^="" and vsorres="")) keep=sysbp: usubjid domain studyid vsblfl visit: rfstdtc 
                                                                  rename=(sysbp_vspos=VSPOS sysbp_vsorres=vsorres sysbp_vsorresu=vsorresu 
                                                                          sysbp_vsstat=vsstat sysbp_vsdat=vsdtco sysbp_vstpt=vstpt sysbp_vstptnum=vstptnum))
	  vs03 (in=c where=(vsorres^="" or (vsstat^="" and vsorres="")) keep=pulse: usubjid domain studyid vsblfl visit: rfstdtc 
                                                                  rename=(pulse_vspos=VSPOS pulse_vsorres=vsorres pulse_vsorresu=vsorresu 
                                                                          pulse_vsstat=vsstat pulse_vsdat=vsdtco pulse_vstpt=vstpt pulse_vstptnum=vstptnum));
  if a then do; 
    VSTESTCD="DIABP"; 
    VSTEST="Diastolic Blood Pressure"; 
    VSTPTREF="PATIENT "||strip(vspos); 
  end;
  else if b then do; 
    VSTESTCD="SYSBP"; 
    VSTEST="Systolic Blood Pressure"; 
    VSTPTREF="PATIENT "||strip(vspos); 
  end;
  else if c then do; 
    VSTESTCD="PULSE"; 
    VSTEST="Pulse Rate"; 
    VSTPTREF="PATIENT "||strip(vspos); 
  end;
  VSSTRESN=input(vsorres,8.);
  if vsstresn^=. then VSSTRESC=strip(put(vsstresn, 3.));
  VSSTRESU=vsorresu;
  if vstptnum=815 then vseltm="PT5M";
  else if vstptnum=816 then vseltm="PT1M";
  else if vstptnum=817 then vseltm="PT3M";
run;

data vs04a;
  length vstest $24;
  set vs03 (in=a where=(vsorres^="") keep=height: usubjid domain studyid vsblfl visit: rfstdtc 
                                   rename=(height_vsorres=vsorres height_vsorresu=vsorresu height_vsstat=vsstat height_vsdat=vsdtco))
	  vs03 (in=b where=(vsorres^="") keep=temp: usubjid domain studyid vsblfl visit: rfstdtc 
                                   rename=(temp_vsorres=vsorres temp_vsorresu=vsorresu temp_vsstat=vsstat temp_vsdat=vsdtco temp_vsloc=vsloc))
      vs03 (in=c where=(vsorres^="") keep=weight: usubjid domain studyid vsblfl visit: rfstdtc 
                                   rename=(weight_vsorres=vsorres weight_vsorresu=vsorresu weight_vsstat=vsstat weight_vsdat=vsdtco));
  if a then do;
    VSTESTCD="HEIGHT"; 
    VSTEST="Height"; 
	**converting inches to cm**;
	if vsorresu="IN" then vsstresn= round(input(vsorres,8.)*2.54, 0.01);
	else vsstresn= round(input(vsorres,8.), 0.01);
	vsstresu="cm";
  end;
  else if b then do;
    VSTESTCD="TEMP"; 
    VSTEST="Temperature"; 
	**converting fahrenheit to degrees celcius**;
    if vsorresu ="F" then do;
	  if vsorres=:"0" then do;
	    vsorr=substr(vsorres, 2);
	    vsstresn= round((input(vsorr,8.)-32)*5/9, 0.01);
	  end;
	  else vsstresn= round((input(vsorres,8.)-32)*5/9, 0.01);
	end;
	else if vsorresu="C" then do;
      if vsorres=:"0" then do;
	    vsorr=substr(vsorres, 2);
	    vsstresn= round(input(vsorr,8.), 0.01);
	  end;
	  else vsstresn= round(input(vsorr,8.), 0.01);
	end;
	vsstresu="C";
  end;
  else if c then do;
    VSTESTCD="WEIGHT"; 
    VSTEST="Weight"; 
	**converting pounds to kilograms**;
    if vsorresu="LB" then vsstresn=round(input(vsorres,8.)*0.4536, 0.01);
	else if vsorresu = "kg" then do;
	  if vsorres=:"0" then do;
	    vsorr=substr(vsorres,2);
        vsstresn=round(input(vsorr,8.), 0.01);
	  end;
	  else vsstresn=round(input(vsorr,8.), 0.01);
	end;
	vsstresu="kg";
  end;
  vsstresc=strip(put(vsstresn, best6.));
run;

data vs05;
  set vs04
      vs04a;
  **VSDY**;
  rfstdt=input(rfstdtc, yymmdd10.);
  vsdt=input(vsdtco, date11.);
  if vsdt>=rfstdt then vsdy=(vsdt-rfstdt)+1;
  else vsdy=vsdt-rfstdt;
  format vsdt E8601da.;
  **VSDTC**;
  VSDTC=put(vsdt, e8601da.);
run;

proc sort data=vs05 out=vs06;
  by usubjid vstestcd visitnum vstptnum;
run;

data vs07;
  set vs06;
  by usubjid vstestcd visitnum vstptnum;
  retain vsseq 1;
  if first.usubjid then vsseq=1;
  else vsseq=vsseq+1;
run;

data sdtm.VS(label="Vital Signs");
  attrib 
       STUDYID  length=$12   label="Study Identifier"
       DOMAIN   length=$2    label="Domain Abbreviation"
       USUBJID  length=$11   label="Unique Subject Identifier"
       VSSEQ    length=8     label="Sequence Number"
       VSTESTCD length=$6    label="Vital Signs Test Short Name"
       VSTEST   length=$24   label="Vital Signs Test Name"
       VSPOS    length=$8    label="Vital Signs Position of Subject"
       VSORRES  length=$5    label="Result or Finding in Original Units"
       VSORRESU length=$200  label="Original Units"
       VSSTRESC length=$6    label="Character Result/Finding in Std Format"
       VSSTRESN length=8     label="Numeric Result/Finding in Standard Units"
       VSSTRESU length=$200  label="Standard Units"
       VSSTAT   length=$8    label="Completion Status"
       VSLOC    length=$200  label="Location of Vital Signs Measurement"
       VSBLFL   length=$1    label="Baseline Flag"
       VISITNUM length=8     label="Visit Number"
       VISIT    length=$19   label="Visit Name"
       VISITDY  length=8     label="Planned Study Day of Visit"
       VSDTC    length=$10   label="Date/Time of Measurements"
       VSDY     length=8     label="Study Day of Vital Signs"
       VSTPT    length=$30   label="Planned Time Point Name"
       VSTPTNUM length=8     label="Planned Time Point Number"
       VSELTM   length=$4    label="Planned Elapsed Time from Time Point Ref"
       VSTPTREF length=$16   label="Time Point Reference";
  set vs07;
  keep STUDYID DOMAIN USUBJID 
       VSSEQ VSTESTCD VSTEST VSPOS 
       VSORRES VSORRESU VSSTRESC VSSTRESN VSSTRESU 
       VSSTAT VSLOC VSBLFL
       VISITNUM VISIT VISITDY
       VSDTC VSDY VSTPT VSTPTNUM 
       VSELTM VSTPTREF ;
run;

proc contents data=sdtm.vs varnum ;
run;

proc sort data=ORIGSDTM.vs out=SDTMVS;
  by USUBJID vsseq;
run;

proc sort data=sdtm.vs out=new;
  by USUBJID vsseq;
run;

proc compare data=sdtmvs compare=new listall;
run;






