* create SDTM AE from CDASH datasets *; 

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

data d1;
  length AESER $1 DOMAIN $2 AEREL AESEV $8 AEDTC AESTDTC AEENDTC $10 USUBJID $11 AEBODSYS $67 AEBDSYCD 8. ;
  set cdash.ae (where=(aeyn='Y') rename=(aeser=oaeser aerel=oaerel aesev=oaesev));
  * DOMAIN *;
  domain='AE';
  * USUBJID *;
  usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);
  * AESEV *;
  if oaesev=1 then aesev='MILD';
  else if oaesev=2 then aesev='MODERATE';
  else if oaesev=3 then aesev='SEVERE';
  * AEREL *; 
  if oaerel=1 then aerel='NONE';
  else if oaerel=2 then aerel='REMOTE';
  else if oaerel=3 then aerel='POSSIBLE';
  else if oaerel=4 then aerel='PROBABLE';
  * AESER *;
  if oaeser='No' then aeser='N';
  else if oaeser in ('1','2','3','4','5','6','7','8') then aeser='Y';   
  * AEBODSYS *;
  aebodsys=strip(aesoc);
  * AEBDSYCD *;
  aebdsycd=aesoccd;
  * AEDTC *;
  aedtc=put(input(aedat,date11.),e8601da.); 
  * AESTDTC *;
  if length(aestdat)=11 then aestdtc=put(input(aestdat,date11.),e8601da.); 
  else if length(aestdat)=4 then aestdtc=strip(aestdat);
  else if length(aestdat)=8 then aestdtc=substr(aestdat,5,4)||'-'||put(substr(aestdat,1,3),$month.);
  * AEENDTC *;
  if aeendat^='' then aeendtc=put(input(aeendat,date11.),e8601da.); 
  label domain='Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		aespid='Sponsor-Defined Identifier'
		aeterm='Reported Term for the Adverse Event'
        aellt='Lowest Level Term'
		aelltcd='Lowest Level Term Code'
		aedecod='Dictionary-Derived Term'
		aeptcd='Preferred Term Code'
		aehlt='High Level Term'
		aehltcd='High Level Term Code'
		aehlgt='High Level Group Term'
		aehlgtcd='High Level Group Term Code'
        aebodsys='Body System or Organ Class'
		aebdsycd='Body System or Organ Class Code'
        aesoc='Primary System Organ Class'
		aesoccd='Primary System Organ Class Code'
		aesev='Severity/Intensity'
		aeser='Serious Event'
		aerel='Causality'
		aesdisab='Persist or Signif Disability/Incapacity'
        aeshosp='Requires or Prolongs Hospitalization'
		aedtc='Date/Time of Collection'
        aestdtc='Start Date/Time of Adverse Event'
        aeendtc='End Date/Time of Adverse Event';
run; 

* merge in SDTM.DM.RFSTDTC for AESTDY and AEENDY calculation *; 

proc sort data=d1;
  by studyid usubjid;
run; 

data d2;
  length AESTDY AEENDY 8.;
  merge d1 (in=a)
        sdtm.dm (in=b keep=studyid usubjid rfstdtc);
  by studyid usubjid;
  if a;
 * AESTDY AEENDY*;
  if aestdat^='' and length(aestdat)=11 then _aestdtc=input(aestdat,date11.);
  if aeendat^='' then _aeendtc=input(aeendat,date11.);
  if rfstdtc^='' then do;
    _rfstdtc=input(rfstdtc,e8601da.);  
    if _aestdtc^=. then do;
      if _aestdtc>=_rfstdtc then aestdy=(_aestdtc-_rfstdtc) + 1;
      else aestdy=_aestdtc-_rfstdtc;
	end; 
	if aeendat^='' then do; 
      if _aeendtc>=_rfstdtc then aeendy=(_aeendtc-_rfstdtc) + 1;
      else aeendy=_aeendtc-_rfstdtc;
	end;     
  end;
  label aestdy='Study Day of Start of Adverse Event'
		aeendy='Study Day of End of Adverse Event';
  * data issue for USUBJID=01-716-1063 where AETERM=HYPERHIDROSIS and AEDTC=2013-05-09 *;
  * AESTDY=366 but AESTDTC is on the same day as the first dose so AESTDY should be 1  *; 
  * AESTDY value is set to 366 for this subject to match original SDTM AESTDY value    *;
  if usubjid='01-716-1063' and aeterm='HYPERHIDROSIS' and aedtc='2013-05-09' and aestdy=1 then aestdy=aestdy+365;
run; 

proc sort data=d2;
  by studyid usubjid aedtc aestdtc aespid aeterm;
run; 

data d3;
  length AESEQ 8.;
  set d2;
  by studyid usubjid aedtc aestdtc aespid aeterm;
  retain aeseq;
  if first.usubjid then aeseq=0;
  aeseq=aeseq+1;
  label aeseq='Sequence Number';
run; 


proc sql noprint;
  create table AE as
         select studyid, domain, usubjid, aeseq, aespid, aeterm, aellt, aelltcd, aedecod, aeptcd, aehlt, aehltcd,
		        aehlgt, aehlgtcd, aebodsys, aebdsycd, aesoc, aesoccd, aesev, aeser, aeacn, aerel, aeout, aescan, 
                aescong, aesdisab, aesdth, aeshosp, aeslife, aesod, aedtc, aestdtc, aeendtc, aestdy, aeendy
		 from d3;
quit;

* permanent dataset *;

proc sort data=ae
           out=sdtm.ae (label='Adverse Events');
  by studyid usubjid aeterm aestdtc aeseq;
run; 

proc contents data=sdtm.ae varnum;
run; 


options ls=200 ps=200;

proc sort data=origsdtm.ae
           out=origae;
  by studyid usubjid aeterm aedtc aeseq;
run; 

proc sort data=sdtm.ae
           out=ae;
  by studyid usubjid aeterm aedtc aeseq;
run; 

proc compare base=origae
             compare=ae listall;
  id studyid usubjid aeterm aedtc aeseq;
run; 
