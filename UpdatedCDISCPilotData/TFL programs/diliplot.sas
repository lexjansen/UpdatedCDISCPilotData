* create potential DILI plots *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname ADAM "&mypath.\ORIGADAM"; 
libname TFL "&mypath.\TFL datasets"; 

proc datasets library=work memtype=data kill nolist;
run;
quit;

DM "out;clear;log;clear;";

***----------------***;
*** Bring in data  ***;
***----------------***;
proc sort data= adam.adlbc(where=(paramcd in("ALT" "BILI" "AST") and ady>1 and avisitn^=99)) out=bc01;
  by usubjid paramn avisitn;
run;

proc sort data= adam.adsl(where=(saffl="Y")) out=sl01;
  by usubjid;
run;

data bc02;
  merge bc01(in=a)
        sl01(in=b);
  by usubjid;
  if a and b;
  keep usubjid trta trtan aval param: avisit: saffl avisit: visit visitnum R2a1hi adt;
run;

data bc03;
length param $100 paramcd $8;
  set bc02(in=a)
      bc02(in=b where=(paramn in (24 25)));
  if b then do;
    paramcdorig=paramcd;
	paramnorig=paramn;
	paramorig=param;
    paramcd="AST/ALT";
    paramn=99;
    param="Aspartate Aminotransferase (U/L) or Alanine Aminotransferase (U/L)";
  end;
run;

proc sort data=bc03 out= bc04;
  by usubjid trtan paramn R2a1hi descending adt;
run;

data bc05;
  set bc04;
  by usubjid trtan paramn R2a1hi descending adt;
  if last.paramn;
run;

**Remove subjects with missing values **;
proc sort data=bc05(where=(aval=.)) out=miss;
  by usubjid;
run;

data bc06;
  merge bc05(in=a)
        miss(in=b);
  by usubjid;
  if a and not b;
run;

***------------------------------***;
*** -       QC dataset map     - ***;
***------------------------------***;
%macro quality(inp=, parn=, map=);
  data QC01;
    set bc06(in=a where=(paramn=21))
        bc06(in=b where=(paramn=&parn));
    SRCDOM="ADLBC";
    SRCVAR="R2ALHI";
    SRCVLABL="Ratio values";
    %if &parn=99 %then %do;
      if paramn=99 then ORDVAR=2;
	  else ORDVAR=1;
      if paramorig^="" then do;
        paramcd=paramcdorig;
	    param=paramorig;
	    paramn=paramnorig;
	  end;
	  drop paramcdorig paramorig paramnorig;
    %end;
  run;

  %if &parn=99 %then %do;
    proc sql noprint; 
      create table QC02 as
      select ordvar, usubjid, saffl, trta, trtan, param, paramcd, paramn, visit, visitnum, avisit, avisitn, srcdom, srcvar, srcvlabl, R2a1hi
      from qc01
      order by ordvar, R2a1hi;
    quit;

    proc sort data=QC02 out=tfl.&map ;
      by ordvar R2a1hi;
    run;
  %end;
  %else %do;
    proc sql noprint; 
      create table QC02 as
      select usubjid, saffl, trta, trtan, param, paramcd, paramn, visit, visitnum, avisit, avisitn, srcdom, srcvar, srcvlabl, R2a1hi
      from qc01
      order by paramn, R2a1hi;
    quit;

    proc sort data=QC02 out=tfl.&map ;
      by paramn R2a1hi;
    run;
  %end;
%mend quality;
**ALT**;
%quality(inp=bc06, parn=24, map=F15_1_1_map);
**AST**;
%quality(inp=bc06, parn=25, map=F15_1_2_map);
**ALT or ALT**;
%quality(inp=bc06, parn=99, map=F15_1_3_map);

***------------------------------***;
*** -       figure output      - ***;
***------------------------------***;
data bc07;
  merge bc06 (in=a where=(paramn=21) rename=(R2A1hi=Y_BILI))
        bc06 (in=b where=(paramn=24) rename=(R2A1hi=X_ALT))
        bc06 (in=b where=(paramn=25) rename=(R2A1hi=X_AST))
        bc06 (in=b where=(paramn=99) rename=(R2A1hi=X_ALTAST));
  by usubjid trtan;
  if a;
  keep usubjid trta: Y: x:;
run;

proc sort data=bc07;
  by trtan;
run;

%let pgmname=diliplot.sas;

***------------------***;
*** - graph output - ***;
***------------------***;
options orientation=landscape nodate nonumber leftmargin=.25in rightmargin=.25in topmargin=0.25in bottommargin=0.25in;
ods graphics / reset width=100pct height=100pct border=off attrpriority=none ;
ods output;
ods escapechar="~";

%macro fig(x=,xlabel=,titlea=,titleb=,abbrev=,output=);
  ods pdf file="&mypath.\TFL datasets\&output..pdf" dpi=300 nogtitle nogfootnote;
  title;
  title1 font="courier new" j=l "Study: CDISCPILOT01";
  title2 font="courier new" j=c "&titlea.";
  title3 font="courier new" j=c "&titleb.";
  title4 font="courier new" j=c "Analysis Set: Safety Set";
  footnote;
  footnote1 height=10pt font="courier new" j=l "&abbrev.";
  footnote2 height=10pt font="courier new" j=l "Program:diliplot.sas" j=c "Date:&sysdate9." j=r "Page ~{thispage} of ~{lastpage}" ;


  proc sgplot data=bc07 noborder ;
    styleattrs datasymbols=(circle square x) datacontrastcolors=(royalblue VIO black);
    scatter x=&x. y=y_BILI / group=trta markerattrs=(size=10px);
    keylegend /  title="" location=outside position=bottom valueattrs=(Family="courier new");
    xaxis label="&xlabel." labelattrs=(family="courier new") values=(0 to 6 by 1);
    yaxis label="Peak BILI (xULN)" labelattrs=(family="courier new") values=(0 to 6 by 1) ;
    refline 3 / axis=x lineattrs=(thickness=0.5 color=black pattern=dash);
    refline 2 / axis=y lineattrs=(thickness=0.5 color=black pattern=dash); 
    inset "Cholestasis" / position=topleft noborder TEXTATTRS=(Family="courier new");
    inset "Potential Hy's Law" / position=topright noborder TEXTATTRS=(Family="courier new");
    inset "Temple's Corollary" / position=bottomright noborder TEXTATTRS=(Family="courier new");
  run;
  ods pdf close;
%mend fig;

**AST**;
%fig(x=x_alt, 
     xlabel=%str(Peak ALT (xULN)),
     titlea=%str(Figure 15.1.1),
	 titleb=%str(Potential Drug Induced Liver Injury Plot),
     abbrev=%str(ALT=Alanine Aminotransferase, BILI=Bilirubin, ULN=Upper limit of normal.),
     output=%str(F15_1_1));
**ALT**;
%fig(x=x_ast, 
     xlabel= %str(Peak AST (xULN)),
     titlea=%str(Figure 15.1.2),
	 titleb=%str(Potential Drug Induced Liver Injury Plot),
     abbrev=%str(AST=Aspartate Aminotransferase, BILI=Bilirubin, ULN=Upper limit of normal.),
     output=%str(F15_1_2));
**AST/ALT**;
%fig(x=x_altast, 
     xlabel= %str(Peak AST or ALT (xULN)),
     titlea=%str(Figure 15.1.3),
	 titleb=%str(Potential Drug Induced Liver Injury Plot),
     abbrev=%str(ALT=Alanine Aminotransferase, AST=Aspartate Aminotransferase, BILI=Bilirubin, ULN=Upper limit of normal.),
     output=%str(F15_1_3));

