* create ADLBC dataset *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname adam2 "&mypath.\ADaM2"; 
libname sdtm "&mypath.\SDTM" access=readonly; 
libname origadam "&mypath.\ORIGADAM" access=readonly;

* get dosing dates for derivation of TRTA dose at time of lab assessment *; 

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

proc format;
  value avisit 
    0='Baseline'
    2='Week 2'
	4='Week 4'
	6='Week 6'
	8='Week 8'
	12='Week 12'
	16='Week 16'
	20='Week 20'
	24='Week 24'
	26='Week 26'
    99='End of Treatment';
	
  invalue paramn
    'ALB'=33
    'ALP'=22
    'ALT'=24
    'AST'=25
    'BILI'=21
    'BUN'=26
    'CA'=30
    'CHOL'=34
    'CK'=35
    'CL'=20
    'CREAT'=27
    'GGT'=23
    'GLUC'=31
    'K'=19
    'PHOS'=29
    'PROT'=32
    'SODIUM'=18
    'URATE'=28;
run; 

data d1;
  length ABLFL ANRIND $1 PARCAT1 $4 PARAMCD $6 TRTP TRTA $20 PARAM $32
         TRTPN TRTAN AVISITN ADY ADT PARAMN AVAL A1LO A1HI R2A1LO R2A1HI ALBTRVAL 8. ;
  merge sdtm.lb (in=a where=(lbcat=:'CHEM' and visitnum not in (6,201)))
        adam2.adsl (in=b keep=studyid usubjid subjid trt: age: race: sex comp24fl dsraefl saffl)
		pex3 (in=c);
  by studyid usubjid;
  if a; 
  * AVISITN *;
  if visitnum=1 then avisitn=0;
  else if visitnum=4 then avisitn=2;
  else if visitnum=5 then avisitn=4;
  else if visitnum=7 then avisitn=6;
  else if visitnum=8 then avisitn=8;
  else if visitnum=9 then avisitn=12;
  else if visitnum=10 then avisitn=16;
  else if visitnum=11 then avisitn=20;
  else if visitnum=12 then avisitn=24;
  else if visitnum=13 then avisitn=26;  
  * ADY *;
  ady=lbdy;
  * ADT *;
  adt=input(substr(lbdtc,1,10),e8601da.);
  * PARAM *;
  param=strip(lbtest)||" ("||strip(lbstresu)||")";
  * PARAMCD *;
  paramcd=strip(lbtestcd);
  * PARAMN *;
  paramn=input(lbtestcd,paramn.);
  * PARCAT1 *;
  parcat1=substr(lbcat,1,4);
  * AVAL *;
  aval=lbstresn;
  * A1LO *;
  a1lo=lbstnrlo;
  * A1HI *;
  a1hi=lbstnrhi;
  * R2A1LO R2A1HI *;
  if aval^=. then do;
     r2a1lo=aval/a1lo;
     r2a1hi=aval/a1hi;
  end; 
  * ABLFL *;
  ablfl=strip(lbblfl);
  * ANRIND *;
  if aval^=. then do; 
    if aval>(1.5*lbstnrhi) then anrind='H';
    else if aval<(0.5*lbstnrlo) then anrind='L';  
    else anrind='N';
  end; 
  else anrind='N';
  * ALBTRVAL *;
  if lbstresn^=. then do; 
    _derv_nrlo=lbstresn - (0.5*lbstnrlo);
    _derv_nrhi=(1.5*lbstnrhi) - lbstresn;
    albtrval=max(_derv_nrlo,_derv_nrhi);
  end;
  * TRTP *;
  trtp=strip(trt01p);
  * TRTPN *;
  trtpn=trt01pn;
  * TRTA TRTAN *;  
  if index(trt01a,'High')>0 and visit^=:'UNSCHED' then do;
    if xw24=54 and adt>w24 then do;
      trta='Xanomeline Low Dose';
	  trtan=xw24;
	end;
    else if xw2=81 and adt>w2 then do;
      trta=strip(trt01a);
	  trtan=xw2;
	end;
    else if xw0=54 then do;
      trta='Xanomeline Low Dose';
	  trtan=xw0;
	end;
  end;  
  else if visit^=:'UNSCHED' then do;  
    trta=strip(trt01a);  
    trtan=trt01an;  
  end;
  format adt date9.;
  informat adt date9.;
  label trtp='Planned Treatment'
        trtpn='Planned Treatment (N)'
        trta='Actual Treatment'
		trtan='Actual Treatment (N)'
        avisitn='Analysis Visit (N)'
		ady='Analysis Relative Day'
        adt='Analysis Date'
		param='Parameter'
        paramcd='Parameter Code'
        paramn='Parameter (N)'
        parcat1='Parameter Category 1'
        aval='Analysis Value'                
        a1lo='Analysis Range 1 Lower Limit'
        a1hi='Analysis Range 1 Upper Limit'
        r2a1lo='Ratio to Analysis Range 1 Lower Limit'
        r2a1hi='Ratio to Analysis Range 1 Upper Limit'   
        albtrval='Amount Threshold Range' 
        anrind='Analysis Reference Range Indicator'        
        ablfl='Baseline Record Flag'        
		;
run;

data base;
  length BASE BR2A1LO BR2A1HI 8. ;
  set d1(where=(lbblfl='Y') keep=usubjid paramn aval lbblfl a1lo a1hi);
  * BASE *;
  base=aval;
   * BR2A1LO BR2A1HI *;
  if base^=. then do;
    if a1lo^=. then br2a1lo=base/a1lo;
    if a1hi^=. then br2a1hi=base/a1hi;
  end;   
  drop aval lbblfl a1lo a1hi;
  label base='Baseline Value'
        br2a1lo='Base Ratio to Analysis Range 1 Lower Lim'
        br2a1hi='Base Ratio to Analysis Range 1 Upper Lim';
run; 

proc sort data=d1;
  by usubjid paramn;
run; 

proc sort data=base;
  by usubjid paramn;
run; 

* get max vals to use in derivation for ANL01FL *;
proc means data=d1 (where=(0<avisitn<=24 and albtrval^=.)) noprint; 
  by usubjid paramn;
  var albtrval;
  output out=maxvals max=max_albtrval;
run; 

data d2;
  length BNRIND $1 CHG ALBTRVAL 8. ;
  merge d1(in=a)
        base(in=b)
		maxvals(in=c drop=_:);
  by usubjid paramn;
  if a;
  * CHG *;
  if avisitn^=0 and aval^=. and base^=. then chg=aval-base;  
  * BNRIND *;
  if base^=. then do; 
    if base>(1.5*lbstnrhi) then bnrind='H';
    else if base<(0.5*lbstnrlo) then bnrind='L';  
    else bnrind='N';
  end; 
  label chg='Change from Baseline'        
        bnrind='Baseline Reference Range Indicator'                
		;
run; 

proc sort data=d2;
  by usubjid paramn albtrval;
run; 

data matchmax nomatchmax;
  set d2;
  if albtrval^=. and albtrval=max_albtrval and avisitn>0 then output matchmax;
  else output nomatchmax;
run; 

data matchmax2;
  length ANL01FL $1 ;
  set matchmax;
  by usubjid paramn;  
  * ANL01FL *;  
  if first.paramn then anl01fl='Y';
  label anl01fl='Analysis Flag 01';
run; 

data d3;
  set nomatchmax
      matchmax2;
run; 

proc sort data=d3;
  by usubjid paramn visitnum;
run; 

* derived records for AVISIT=End of Treatment for subject that completed Week 24 visit during treatment *;

proc sort data=d3 (where=(.<avisitn<=24 and comp24fl='Y' and ady>0))
           out=etrt1;
  by usubjid paramn avisitn;
run; 

data etrt1b;
  set etrt1;
  by usubjid paramn avisitn;
  if last.paramn;
run; 

* derived records for AVISIT=End of Treatment for subject discontinued before Week 24 during treatment *;

proc sort data=d3 (where=(.<avisitn<24 and comp24fl='N' and ady>0))
           out=etrt2;
  by usubjid paramn avisitn;
run; 

data etrt2b;
  set etrt2;
  by usubjid paramn avisitn;
  if last.paramn;
run; 

data etrt3;
  length AENTMTFL $1 ;
  set etrt1b
      etrt2b;
  avisitn=99; 
  * AENTMTFL *;
  aentmtfl='Y';
  label aentmtfl='Last value in treatment visit';
run; 

* merge AENTMTFL flag back into main dataset *; 

proc sort data=etrt3;
  by usubjid paramn visitnum;
run; 
  
data d4;
  merge d3(in=a)
        etrt3(in=b keep=usubjid paramn visitnum aentmtfl);
  by usubjid paramn visitnum;
  if a;
run; 

* add end of treatment records to main dataset *; 
data d5;
  length AVISIT $16 ;
  set d4
      etrt3;
  * AVISIT *;
  if avisitn^=. then avisit=put(avisitn,avisit.);
  label avisit='Analysis Visit';
run; 

proc sql noprint; 
  alter table d5
  modify visit char(16)
  modify lbnrind char(6); 
quit;

proc sql noprint;
  create table ADLBC as
         select STUDYID, SUBJID, USUBJID, TRT01P, TRT01PN, TRT01A, TRT01AN, TRTP, TRTPN, TRTA, TRTAN, TRTSDT, TRTEDT, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX,
                COMP24FL, DSRAEFL, SAFFL, AVISIT, AVISITN, ADY, ADT, VISIT, VISITNUM, PARAM, PARAMCD, PARAMN, PARCAT1, AVAL, BASE, CHG,
                A1LO, A1HI, R2A1LO, R2A1HI, BR2A1LO, BR2A1HI, ANL01FL, ALBTRVAL, ANRIND, BNRIND, ABLFL, AENTMTFL, LBSEQ, LBNRIND, LBSTRESN
		 from d5;
quit;

* permanent dataset *;

proc sort data=ADLBC
           out=adam2.adlbc (label='Analysis Dataset Lab Blood Chemistry');
  by studyid usubjid avisitn paramn;
run; 

proc contents data=adam2.adlbc varnum;
run; 

options ls=200 ps=200;


proc sort data=origadam.adlbc
           out=origadlbc;
  by studyid usubjid paramcd avisit visit lbseq;*paramn avisitn visitnum lbseq;
run; 

proc sort data=adam2.adlbc
           out=newadlbc;
  by studyid usubjid paramcd avisit visit lbseq;
run; 

proc compare base=origadlbc
             compare=newadlbc criterion=0.0001 listall;
  id studyid usubjid  paramcd avisit visit lbseq;
run; 
