* create SDTM QS from CDASH datasets *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;


proc format;
  invalue visnum
  'SCREENING 1'=1
  'BASELINE'=3
  'WEEK 2'=4
  'WEEK 4'=5
  'AMBUL ECG REMOVAL'=6
  'WEEK 6'=7
  'WEEK 8'=8
  'WEEK 10 (T)'=8.1
  'WEEK 12'=9
  'WEEK 14 (T)'=9.1
  'WEEK 16'=10
  'WEEK 18 (T)'=10.1
  'WEEK 20'=11
  'WEEK 22 (T)'=11.1
  'WEEK 24'=12  
  'WEEK 26'=13  
  'RETRIEVAL'=201;

  invalue visdy
  'SCREENING 1'=-7  
  'BASELINE'=1
  'WEEK 2'=14
  'WEEK 4'=28  
  'AMBUL ECG REMOVAL'=30  
  'WEEK 6'=42
  'WEEK 8'=56  
  'WEEK 10 (T)'=70 
  'WEEK 12'=84
  'WEEK 14 (T)'=98 
  'WEEK 16'=112
  'WEEK 18 (T)'=126 
  'WEEK 20'=140
  'WEEK 22 (T)'=154 
  'WEEK 24','RETRIEVAL'=168  
  'WEEK 26'=182;

  invalue $cibic
  'MARKED IMPROVEMENT'='1'
  'MODERATE IMPROVEMENT'='2'
  'MINIMAL IMPROVEMENT'='3'
  'NO CHANGE'='4'
  'MINIMAL WORSENING'='5'
  'MODERATE WORSENING'='6'
  'MARKED WORSENING'='7';

  invalue $dad
  'N'='0'
  'Y'='1'
  'NA'='96';

  invalue $hachzero
  'MHITM01'='0'  
  'MHITM02'='0'
  'MHITM03'='0'
  'MHITM04'='0'
  'MHITM05'='0'
  'MHITM06'='0'
  'MHITM07'='0'  
  'MHITM08'='0'
  'MHITM09'='0'
  'MHITM10'='0'
  'MHITM11'='0'  
  'MHITM12'='0'
  'MHITM13'='0';  

  invalue $hach  
  'MHITM02'='1'  
  'MHITM04'='1'
  'MHITM05'='1'
  'MHITM06'='1'
  'MHITM07'='1'
  'MHITM08'='1'
  'MHITM09'='1'  
  'MHITM11'='1'
  'MHITM01'='2'
  'MHITM03'='2'
  'MHITM10'='2'  
  'MHITM12'='2'
  'MHITM13'='2';
  
run; 

data d1;
  length QSBLFL QSDRVFL $1 DOMAIN $2 QSSTRESC $4 QSSTRESU $7 QSDTC $10 USUBJID $11 QSSEQ QSSTRESN VISITNUM VISITDY 8. ;
  set cdash.qs;    
  * DOMAIN *;
  domain='QS';
  * USUBJID *;  
  usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);  
  * QSSEQ *;
  qsseq=qsspid;
  * QSSTRESC *;   
  if qscat='DISABILITY ASSESSMENT FOR DEMENTIA (DAD)' then qsstresc=input(qsorres,$dad.);
  else if qscat='MODIFIED HACHINSKI ISCHEMIC SCORE' then do; 
    if qsorres='ABSENT' then qsstresc=input(qstestcd,$hachzero.);
    else if qsorres='PRESENT' then qsstresc=input(qstestcd,$hach.);    
  end;  
  else if qscat='NEUROPSYCHIATRIC INVENTORY - REVISED (NPI-X)' then do; 
    if qsorres='ABSENT' then qsstresc='0';
    else if qsorres='NOT APPLICABLE' then qsstresc='96';
	else qsstresc=strip(qsorres);
  end;
  else if qstestcd='CIBIC' then qsstresc=input(qsorres,$cibic.);
  else qsstresc=strip(qsorres);
  * QSSTRESN *;  
  qsstresn=input(qsstresc,8.);
  * QSSTRESU *;  
  qsstresu=strip(qsorresu);
  * QSORRES - remove derived parameter values for ACTOT and NPTOT *;
  if qstestcd in ('ACTOT','NPTOT') then qsorres='';
  * QSBLFL *;
  if visit="BASELINE" then qsblfl='Y';
  * QSDRVFL *;
  if qstestcd in ('ACTOT' 'NPTOT') or substr(qstestcd,8,1)='S' then qsdrvfl='Y';
  * VISITNUM *;
  visitnum=input(visit,visnum.); 
  * VISITDY *;
  visitdy=input(visit,visdy.); 
  * QSDTC *;  
  qsdtc=put(input(qsdat,date11.),e8601da.);   
  label domain='Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		qsseq='Sequence Number'
        qsstresc='Character Result/Finding in Std Format'
        qsstresn='Numeric Finding in Standard Units'	
		qsstresu='Standard Units'
		qsblfl='Baseline Flag'
		qsdrvfl='Derived Flag'
		visitnum='Visit Number'
		visitdy='Planned Study Day of Visit'
		qsdtc='Date/Time of Finding';
run; 

* merge in SDTM.DM.RFSTDTC for QSDY calculation *; 

proc sort data=d1;
  by studyid usubjid;
run; 

data d2;
  length QSDY 8. ;
  merge d1 (in=a)
        sdtm.dm (in=b keep=studyid usubjid rfstdtc);
  by studyid usubjid;
  if a;
  * QSDY*;
  if qsdat^='' then _qsdtc=input(qsdat,date11.);  
  if rfstdtc^='' then do;
    _rfstdtc=input(rfstdtc,e8601da.);       
    if _qsdtc>=_rfstdtc then qsdy=(_qsdtc-_rfstdtc) + 1;
    else qsdy=_qsdtc-_rfstdtc;  
  end;
  if qscat=:'ALZ' then adascog=input(qsorres,8.);
  else if qscat=:'NEU' and qstestcd in ('NPITM01S','NPITM02S','NPITM03S','NPITM04S','NPITM05S','NPITM07S','NPITM08S','NPITM09S','NPITM10S') then do;    
    if qsorres^='' then np=input(qsorres,8.);
  end; 
  label qsdy='Study Day of Finding';		
run; 

* Derive QSSTRESN and QSSTRESC values for QSTESTCD=ACTOT                                   *;

* calculation of derived score ADAS-Cog(11) :                                              *; 
* Any computed total score will be treated as missing if more than 30% of the items are    *;
* missing or scored “not applicable”. For example - if 4 or more items are missing then    *;     
* the total score will not be computed. When one or more items are missing (but not more   *;
* than 30%) the total score will be adjusted in order to maintain the full range of the    *;
* scale. ADAS-Cog(11) is a 0-70 scale. If the first item Word Recall (ranges from 0 to 10) *;
* is missing then the remaining 10 items of the ADAS-Cog(11) will be summed and multiplied *;
* by (70 / (70-10))                                                                        *;
*                                                                                          *;
* ITEM01 Word Recall Task 0-10                                                             *;
* ITEM02 Naming Objects and Fingers 0-5                                                    *;
* ITEM04 Commands 0-5                                                                      *;
* ITEM05 Constructional praxis 0-5                                                         *;
* ITEM06 Ideational praxis 0-5                                                             *;
* ITEM07 Orientation 0-8                                                                   *;
* ITEM08 Word recognition 0-12                                                             *;
* ITEM11 Spoken Language Ability 0-5                                                       *;
* ITEM12 Comprehension of Spoken Language 0-5                                              *;
* ITEM13 Word Finding Difficulty in Spontaneous Speech 0-5                                 *;
* ITEM14 Recall of Test Instructions 0-5                                                   *;
* TOT01 ADAS-Cog (11) 0-70                                                                 *;

proc sort data=d2;
  by studyid usubjid qscat visitnum visit;
run;

proc transpose data=d2 (where=(qscat=:'ALZ' and qstestcd not in ('ACITM03','ACITM09','ACITM10','ACTOT')))
                out=adas1;
  by studyid usubjid qscat visitnum visit;
  var adascog;
  id qstestcd;
run; 

data adas2;
  length QSTESTCD $8 ; 
  set adas1;
  tot=sum(ACITM01,ACITM02,ACITM04,ACITM05,ACITM06,ACITM07,ACITM08,ACITM11,ACITM12,ACITM13,ACITM14);
  missn=nmiss(ACITM01,ACITM02,ACITM04,ACITM05,ACITM06,ACITM07,ACITM08,ACITM11,ACITM12,ACITM13,ACITM14);
  if missn=1 and acitm08=. then do;
    max=12;
	_qsstresn=tot*(70/(70-max));
  end; 
  else if missn=2 and acitm08=. and acitm14=. then do;
    max=12+5;
	_qsstresn=tot*(70/(70-max));
  end; 
  else if missn=3 and acitm06=. and acitm08=. and acitm14=. then do;
    max=5+12+5;
	_qsstresn=tot*(70/(70-max));
  end; 
  else _qsstresn=tot;
  _qsstresc=compress(put(_qsstresn,best8.));
  qstestcd='ACTOT';
  drop acit: tot missn max _name_;
run; 

* Derive QSSTRESN and QSSTRESC values for QSTESTCD=NPTOT                                   *;

* The primary assessment of this instrument will be for the total score (not including the *;
* sleep/appetite/euphoria domains. This total score is computed by taking the product of   *;
* the frequency and severity scores and summing them up across the domains                 *;
* Severity:  Range 1-3 (1=mild 2=moderate 3=marked)                                        *;
* Frequency: Range 1-4 (1=occasionally 2=often 3=frequently 4=very frequently)             *;
* Frequency × Severity for each NPI domain Range 0-12                                      *;
*                                                                                          *;
* NPI-X Total (9) will be calculated as the sum of all individual domain scores            *;
* If the domain is absent then the score for the domain is 0                               *;
* If the domain is not applicable then the score for the domain is set to missing          *;
* The range of NPI-X Total (9) is 0-108                                                    *;
* NPI-X Total (9) domains are:                                                             *;
*  Delusions                                                                               *;
*  Hallucinations                                                                          *;
*  Agitation/Aggression                                                                    *;
*  Depression/Dysphoria                                                                    *;
*  Anxiety                                                                                 *;
*  Apathy/Indifference                                                                     *;
*  Disinhibition                                                                           *;
*  Irritability/Lability                                                                   *;
*  Aberrant Motor Behavior                                                                 *;
*                                                                                          *;
* When one or more items are missing (but not more than 30%) the total score will be       *;
* adjusted in order to maintain the full range of the scale. NPI-X is a 0-108 scale.       *;
* If any item (ranges from 0 to 12) is missing then the remaining items of the NPI-X will  *;
* be summed and multiplied by (108 / (108-<number of missing items*12>))                   *;


proc transpose data=d2 (where=(qscat=:'NEU' and qstestcd in ('NPITM01S','NPITM02S','NPITM03S','NPITM04S','NPITM05S','NPITM07S','NPITM08S','NPITM09S','NPITM10S')))
                out=np1;
  by studyid usubjid qscat visitnum visit;
  var np;
  id qstestcd;
run; 

data np2;
  length QSTESTCD $8 ; 
  set np1;
  tot=sum(NPITM01S,NPITM02S,NPITM03S,NPITM04S,NPITM05S,NPITM07S,NPITM08S,NPITM09S,NPITM10S);
  missn=nmiss(NPITM01S,NPITM02S,NPITM03S,NPITM04S,NPITM05S,NPITM07S,NPITM08S,NPITM09S,NPITM10S);
  if missn>0 then do;
    max=missn*12;
	_qsstresn=tot*(108/(108-max));
  end; 
  else _qsstresn=tot;
  _qsstresc=compress(put(_qsstresn,best8.));
  qstestcd='NPTOT';
  drop npit: tot missn max _name_;
run; 

proc sort data=d2;
  by studyid usubjid qscat qstestcd visitnum visit;
run; 

proc sort data=adas2;
  by studyid usubjid qscat qstestcd visitnum visit;
run; 

proc sort data=np2;
  by studyid usubjid qscat qstestcd visitnum visit;
run; 

data d3;
  merge d2(in=a)
        adas2(in=b)
        np2(in=c);
  by studyid usubjid qscat qstestcd visitnum visit;
  if a; 
  if b then do; 
    if qsstresc^=_qsstresc then qsstresc=strip(_qsstresc);
	if qsstresn^=_qsstresn then qsstresn=_qsstresn;
  end;
  else if c then do; 
    if qsstresc^=_qsstresc then qsstresc=substr(_qsstresc,1,2);
	if qsstresn^=_qsstresn then qsstresn=_qsstresn;
  end;
  
run; 


proc sql noprint;
  create table QS as
         select studyid, domain, usubjid, qsseq, qstestcd, qstest, qscat, qsscat, qsorres, qsorresu, qsstresc, qsstresn, qsstresu, 
                qsblfl, qsdrvfl, visitnum, visit, visitdy, qsdtc, qsdy
		 from d3;
quit;

* permanent dataset *;

proc sort data=qs
           out=sdtm.qs (label='Questionnaires');
  by studyid usubjid qstestcd visitnum;
run; 

proc contents data=sdtm.qs varnum;
run; 

options ls=200 ps=200;

proc sort data=sdtm.qs
           out=qs;
  by studyid usubjid qsseq qstestcd visitnum;
run; 

proc sort data=origsdtm.qs
           out=origqs;
  by studyid usubjid qsseq qstestcd visitnum;
run; 

proc compare base=origqs
             compare=qs listall criterion=0.00000001;
  id studyid usubjid qsseq qstestcd visitnum;
run; 
