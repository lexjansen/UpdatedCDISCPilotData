* create SDTM SUPPDS from CDASH and Parent SDTM datasets *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname sdtm "&mypath.\SDTM"; 
libname origsdtm "&mypath.\ORIGSDTM" access=readonly; 
libname cdash "&mypath.\CDASH" access=readonly;


data d1;
  length RDOMAIN $2 IDVAR QNAM $8 USUBJID $11 QVAL QORIG QEVAL $200 ;
  set cdash.ie;  
   * RDOMAIN *;
  rdomain='DS';
  * USUBJID *;
  usubjid=substr(studyid,11,2)||"-"||strip(siteid)||"-"||strip(subjid);
  * IDVAR *;
  idvar='DSSEQ';  
  * QNAM *;
  qnam='ENTCRIT';
  * QVAL *;
  qval=substr(ietestcd,5,2);
  * QORIG *;
  qorig='CRF'; 
  * QEVAL *;
  qeval='';
  label rdomain='Related Domain Abbreviation'
        usubjid='Unique Subject Identifier'
		idvar='Identifying Variable'
		qnam='Qualifier Variable Name'
		qval='Data Value'
        qorig='Origin'
        qeval='Evaluator';
run; 

proc sort data=d1;
  by studyid usubjid;
run; 

* retrieve data from parent SDTM DS dataset for QLABEL and IDVARVAL*;

data d2;
  length QLABEL $40 IDVARVAL $200 ;
  merge d1 (in=a)
        sdtm.ds (in=b where=(dsterm='PROTOCOL ENTRY CRITERIA NOT MET') keep=studyid usubjid dsterm dsseq);
  by studyid usubjid;
  if a;   
  * IDVARVAL *;
  idvarval=compress(put(dsseq,8.));
  * QLABEL *;
  qlabel=strip(dsterm);
  label idvarval='Identifying Variable Value'
        qlabel='Qualifier Variable Label';          
run; 

proc sql noprint;
  create table SUPPDS as
         select studyid, rdomain, usubjid, idvar, idvarval, qnam, qlabel, qval, qorig, qeval
		 from d2;
quit;

* permanent dataset *;

proc sort data=suppds
           out=sdtm.suppds (label='Supplemental Qualifiers for DS');
  by studyid usubjid;
run; 

proc contents data=sdtm.suppds varnum;
run; 


options ls=200 ps=200;

proc compare base=origsdtm.suppds
             compare=sdtm.suppds listall;
  id studyid usubjid;
run; 
