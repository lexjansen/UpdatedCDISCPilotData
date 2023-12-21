* create SDTM LB from CDASH datasets *; 

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

  invalue visdy
  'SCREENING 1'=-7  
  'BASELINE'=1
  'AMBUL ECG PLACEMENT'=13
  'WEEK 2'=14
  'WEEK 4'=28  
  'AMBUL ECG REMOVAL'=30  
  'WEEK 6'=42
  'WEEK 8'=56  
  'WEEK 12'=84
  'WEEK 16'=112
  'WEEK 20'=140
  'WEEK 24','RETRIEVAL'=168  
  'WEEK 26'=182;

run; 

data d1;
  length LBBLFL $1 DOMAIN $2 LBSTRESC LBSTRESU $8 USUBJID $11 LBDTC $16 LBNRIND $200 LBSEQ LBSTRESN LBSTNRLO LBSTNRHI VISITNUM VISITDY 8. ;
  set cdash.lb;
   * DOMAIN *;
  domain='LB';
  * USUBJID *;
  usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);
  * LBSEQ *;
  lbseq=lbrefid;
  * LBSTRESC LBSTRESU LBSTNRLO LBSTNRHI*;
  if lborresu='NO UNITS' then do;
    lbstresc=strip(lborres);
    lbstresu='';
  end; 
  else lbstresu=strip(lborresu);
  if substr(lborres,1,1) not in ('<','N') then _lborres=input(lborres,best8.);
  if lbornrlo^='' then _lbornrlo=input(lbornrlo,best8.);
  if lbornrhi^='' then _lbornrhi=input(lbornrhi,best8.);
  if lbtestcd in ('ALB','PROT') then do;     
    if _lborres^=.  then lbstresc=compress(put((_lborres*10),best8.));
    if _lbornrlo^=. then lbstnrlo=_lbornrlo*10;
	if _lbornrhi^=. then lbstnrhi=_lbornrhi*10;
	lbstresu=tranwrd(lbstresu,'g/dL','g/L');
  end;
  else if lbtestcd='BILI' then do;     	
    if _lborres^=.  then lbstresc=compress(put(round((_lborres*17.1),0.01),best8.));
	else if lborres=:'<' then lbstresc='<'||compress(put(round((0.2*17.1),0.01),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo*17.1),1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi*17.1),1);
	lbstresu=tranwrd(lbstresu,'mg/dL','umol/L');
  end; 
  else if lbtestcd='BUN' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/2.8011204),0.001),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/2.8011204),0.1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/2.8011204),0.1);
	lbstresu=tranwrd(lbstresu,'mg/dL','mmol/L');
  end; 
  else if lbtestcd='CA' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/4.008016),0.00001),best8.));
    if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/4.008016),0.1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/4.008016),0.01);
	lbstresu=tranwrd(lbstresu,'mg/dL','mmol/L');
  end; 
  else if lbtestcd='CHOL' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/38.66976),0.00001),best8.));
    if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/38.66976),0.01);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/38.66976),0.01);
	lbstresu=tranwrd(lbstresu,'mg/dL','mmol/L');
  end; 
  else if lbtestcd='CREAT' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres*88.4),0.01),best8.));
    if _lbornrlo^=. then lbstnrlo=round((_lbornrlo*88.4),1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi*88.4),1);
	lbstresu=tranwrd(lbstresu,'mg/dL','umol/L');
  end; 
  else if lbtestcd='GLUC' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/18.014772),0.00001),best8.));
	else if lborres=:'<' then lbstresc='<'||compress(put(round((40/18.014772),0.00001),best8.));
    if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/18.014772),0.1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/18.014772),0.1);
	lbstresu=tranwrd(lbstresu,'mg/dL','mmol/L');
  end;              
  else if lbtestcd='HBA1C' then do; 
    if _lborres^=.  then lbstresc=compress(put((_lborres/100),best8.));
    if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/102.380952),0.001);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/54.4642857),0.001);  * error in data ?? *; 
	lbstresu=tranwrd(lbstresu,'%','1');
  end; 
   else if lbtestcd='HCT' then do; 
    if _lborres^=.  then lbstresc=compress(put((_lborres/100),best8.));
    if _lbornrlo^=. then lbstnrlo=_lbornrlo/100;
    if _lbornrhi^=. then lbstnrhi=_lbornrhi/100;
    lbstresu=tranwrd(lbstresu,'%','1');
  end; 
  else if lbtestcd='HGB' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/1.6113438),0.00001),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/1.6113438),0.01);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/1.6113438),0.01);
	lbstresu=tranwrd(lbstresu,'g/dL','mmol/L');
  end; 
  else if lbtestcd='MCH' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/16.11343),0.00001),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/16.11343),0.1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/16.11343),0.1);
	lbstresu=tranwrd(lbstresu,'pg','fmol(Fe)');
  end; 
  else if lbtestcd='MCHC' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/1.6113438),0.0001),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/1.6113438),1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/1.6113438),1);
	lbstresu=tranwrd(lbstresu,'g/dL','mmol/L');
  end; 
  else if lbtestcd='PH' then do;	
    lbstresc=substr(lborres,1,1);  
	if _lbornrlo^=. then lbstnrlo=_lbornrlo;
    if _lbornrhi^=. then lbstnrhi=_lbornrhi;
  end; 
  else if lbtestcd='PHOS' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/3.096934),0.00001),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/3.096934),0.01);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/3.096934),0.01);
	lbstresu=tranwrd(lbstresu,'mg/dL','mmol/L');
  end; 
  else if lbtestcd='URATE' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres*59.48),0.001),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo*59.48),1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi*59.48),1);
	lbstresu=tranwrd(lbstresu,'mg/dL','umol/L');
  end; 
  else if lbtestcd='VITB12' then do; 
    if _lborres^=.  then lbstresc=compress(put(round((_lborres/1.3553808),0.0001),best8.));
	if _lbornrlo^=. then lbstnrlo=round((_lbornrlo/1.3553808),1);
    if _lbornrhi^=. then lbstnrhi=round((_lbornrhi/1.3553808),1);
	lbstresu=tranwrd(lbstresu,'pg/mL','pmol/L');
  end; 
  else if lbtestcd in ('BASO','EOS','LYM','MONO','PLAT','WBC') then do;
    if _lborres^=. then lbstresc=compress(put(_lborres,best8.));
    if _lbornrlo^=. then lbstnrlo=_lbornrlo;
    if _lbornrhi^=. then lbstnrhi=_lbornrhi;
    lbstresu=tranwrd(lbstresu,'THOU/uL','GI/L');  
  end; 
  else if lbtestcd in ('CL','K','SODIUM') then do;
    if _lborres^=. then lbstresc=compress(put(_lborres,best8.));
    if _lbornrlo^=. then lbstnrlo=_lbornrlo;
    if _lbornrhi^=. then lbstnrhi=_lbornrhi;
    lbstresu=tranwrd(lbstresu,'mEq/L','mmol/L');      
  end; 
  else if lbtestcd='RBC' then do;
    if _lborres^=. then lbstresc=compress(put(_lborres,best8.));
    if _lbornrlo^=. then lbstnrlo=_lbornrlo;
    if _lbornrhi^=. then lbstnrhi=_lbornrhi;
    lbstresu=tranwrd(lbstresu,'MILL/uL','TI/L');  
  end; 
  else if lbtestcd='TSH' then do;
    if _lborres^=. then lbstresc=compress(put(_lborres,best8.));
    if _lbornrlo^=. then lbstnrlo=_lbornrlo;
    if _lbornrhi^=. then lbstnrhi=_lbornrhi;
    lbstresu=tranwrd(lbstresu,'uIU/mL','mU/L');  
  end; 
  else do; 
    lbstresc=strip(lborres);  
    if _lbornrlo^=. then lbstnrlo=_lbornrlo;
    if _lbornrhi^=. then lbstnrhi=_lbornrhi;
	if lbtestcd='SPGRAV' and substr(lbstresc,5,1)='0' then lbstresc=substr(lbstresc,1,4);
  end; 
  * LBSTRESN *;
  if substr(lbstresc,1,1) not in ('','<','N') then lbstresn=input(lbstresc,best8.);      
  * LBNRIND *;
  if lbstresn^=. and lbstresc^='' and lbcat^='URINALYSIS' then do;   
     if lbtestcd in ('CA','HGB') then do; 	 
       if lbstnrhi^=. and round(lbstresn,0.01)>lbstnrhi then lbnrind="HIGH";
	   else if lbstnrhi^=. and lbstnrlo^=. and lbstnrlo<=round(lbstresn,0.01)<=lbstnrhi then lbnrind="NORMAL";
       else if lbstnrlo^=. and round(lbstresn,0.01)<lbstnrlo then lbnrind="LOW";  
	 end;  
     else if lbtestcd='MCH' then do; 	 
       if lbstnrhi^=. and round(lbstresn,0.1)>lbstnrhi then lbnrind="HIGH";
	   else if lbstnrhi^=. and lbstnrlo^=. and lbstnrlo<=round(lbstresn,0.1)<=lbstnrhi then lbnrind="NORMAL";
       else if lbstnrlo^=. and round(lbstresn,0.1)<lbstnrlo then lbnrind="LOW";  
	 end; 
     else if lbtestcd in ('CREAT','URATE') then do; 	 
       if lbstnrhi^=. and round(lbstresn,1)>lbstnrhi then lbnrind="HIGH";
	   else if lbstnrhi^=. and lbstnrlo^=. and lbstnrlo<=round(lbstresn,1)<=lbstnrhi then lbnrind="NORMAL";
       else if lbstnrlo^=. and round(lbstresn,1)<lbstnrlo then lbnrind="LOW";  
	 end; 
	 else if lbtestcd in ('MACROCY','POLYCHR') then do; 
       if lbstresn=1 then lbnrind='ABNORMAL';
	 end; 
	 else do;
       if lbstnrhi^=. and lbstresn>lbstnrhi then lbnrind="HIGH";
	   else if lbstnrhi^=. and lbstnrlo^=. and lbstnrlo<=lbstresn<=lbstnrhi then lbnrind="NORMAL";
       else if lbstnrlo^=. and lbstresn<lbstnrlo then lbnrind="LOW";  
	 end; 
  end; 
  else if lbstresn=. and lbcat^='URINALYSIS' then do; 
    if lborres='<40' then lbnrind='LOW';
  end; 
  else if lbcat='URINALYSIS' then do; 
    if lbtestcd in ('COLOR','UROBIL') and lborres^='' then do;
      lbstresu='';
      if lbstresc in ('N','0') then lbnrind='NORMAL';
	  else if lbstresc^='' then lbnrind='ABNORMAL';
	end; 
	else if lbtestcd='KETONES' then do;
      if lbstresc in ('0','N') then lbnrind='NORMAL';
	  else if lbstresc^='' then lbnrind='ABNORMAL';
	end; 
    else if lbtestcd='PH' then do;	  
	  if lbstnrhi^=. and lbstnrlo^=. and lbstnrlo<=lbstresn<=lbstnrhi then lbnrind='NORMAL';
      else if lbstresn^=. then lbnrind='ABNORMAL';
	end; 	
	else if lbtestcd='SPGRAV' then do; 
      if lbstnrhi^=. and lbstresn>lbstnrhi then lbnrind="HIGH";
	  else if lbstnrhi^=. and lbstnrlo^=. and lbstnrlo<=lbstresn<=lbstnrhi then lbnrind="NORMAL";
      else if lbstnrlo^=. and lbstresn<lbstnrlo then lbnrind="LOW";  
	end; 
  end; 
  if lbtestcd in ('ANISO','MICROCY','POIKILO') and lborres='1' then lbnrind='ABNORMAL';
  if lbtestcd='HBA1C' then do; 
    if _lborres>_lbornrhi then lbnrind='HIGH';
	else if _lbornrlo<=_lborres<=_lbornrhi then lbnrind='NORMAL';
    else if _lborres<_lbornrlo then lbnrind='LOW';
  end; 
  * LBBLFL *;
  if visit='SCREENING 1' then lbblfl='Y';
  * VISITNUM *;
  visitnum=input(visit,visnum.); 
  * VISITDY *;
  if visit^=:'UNSCHED' then visitdy=input(visit,visdy.); 
  * LBDTC *;  
  if lbtim^='' then lbdtc=put(input(lbdat,date11.),e8601da.)||'T'||strip(lbtim); 
  else lbdtc=put(input(lbdat,date11.),e8601da.); 
  label domain='Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		lbseq='Sequence Number'
        lbstresc='Character Result/Finding in Std Format'
		lbstresn='Numeric Result/Finding in Standard Units'
		lbstresu='Standard Units'
        lbstnrlo='Reference Range Lower Limit-Std Units'
        lbstnrhi='Reference Range Upper Limit-Std Units'
        lbnrind='Reference Range Indicator'
		lbblfl='Baseline Flag'
        visitnum='Visit Number'
		visitdy='Planned Study Day of Visit'
		lbdtc='Date/Time of Specimen Collection';        
run; 


* merge in SDTM.DM.RFSTDTC for LBDY calculation *; 

proc sort data=d1;
  by studyid usubjid;
run; 

data d2;  
  length LBDY 8. ;
  merge d1 (in=a)
        sdtm.dm (in=b keep=studyid usubjid rfstdtc);
  by studyid usubjid;
  if a;
  * LBDY *;
  if lbdat^='' then _lbdtc=input(lbdat,date11.);
  if rfstdtc^='' then do;
    _rfstdtc=input(rfstdtc,e8601da.);   
    if _lbdtc>=_rfstdtc then lbdy=(_lbdtc-_rfstdtc) + 1;
    else lbdy=_lbdtc-_rfstdtc;
  end;
  label lbdy='Study Day of Specimen Collection';
run; 

proc sql noprint;
  create table LB as         
         select studyid, domain, usubjid, lbseq, lbtestcd, lbtest, lbcat, lborres, lborresu, lbornrlo, lbornrhi, 
		        lbstresc, lbstresn, lbstresu, lbstnrlo, lbstnrhi, lbnrind, lbblfl, visitnum, visit, visitdy, lbdtc, lbdy
		 from d2;
quit;

* permanent dataset *;

proc sort data=lb
           out=sdtm.lb (label='Laboratory Test Findings');
  by studyid usubjid lbtestcd visitnum;
run; 

proc contents data=sdtm.lb varnum;
run; 

options ls=200 ps=200;

proc sort data=origsdtm.lb
           out=origlb;
  by usubjid lbseq;
run; 

proc sort data=sdtm.lb 
           out=lb;
  by usubjid lbseq;
run; 


proc compare base=origlb 
             compare=lb listall criterion=0.00001;
  id usubjid lbseq;
run; 
