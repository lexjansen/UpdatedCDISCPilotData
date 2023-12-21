* create TFL dataset for Table 14-2.01 from PDF report-tlf-pilot3 *; 

* set up libnames for your environment *; 

%let mypath=put\your\path\here;

libname ADAM "&mypath.\ORIGADAM"; 
libname TFL "&mypath.\TFL datasets"; 

* source data - only vars and population of interest *; 
proc sort data=adam.adsl (where=(ittfl='Y'))
 		   out=adsl (keep=trt01p: usubjid age: race: weightbl heightbl bmibl mmsetot ittfl);
 	by trt01pn trt01p;
run;

proc contents data=adsl out=adslcont(keep=name label rename=(name=srcvar label=srcvlabl)) noprint;
run; 

proc sql noprint; 
  alter table adslcont
  modify srcvar char(8)
  modify srcvlabl char(50);
quit;

* stats for continuous variables *;
%macro stat1(varin=, ord=);

	proc means data=adsl noprint;
	  by trt01pn trt01p;
	  var &varin;
	  output out=adfr mean=mean stddev=sd median=median min=min max=max;
	run;
	
	data adfr1;
	  length ORDVAR 8. SRCVAR T_MEAN T_SD T_MEDIAN T_MIN T_MAX $8. ;
	  set adfr;
	  srcvar="&varin"; * source ADSL variable *; 
	  ordvar=&ord;
	  t_mean=left(put(round(mean,0.01),7.2));		
	  t_sd=left(put(round(sd,0.01),7.2));
      t_median=left(put(round(median,0.01),7.2));		
      t_min=left(put(round(min,0.01),7.2));	
	  t_max=left(put(round(max,0.01),7.2));	
      label t_mean='Table Result - Mean'
            t_sd='Table Result - sd'
            t_median='Table Result - Median'	
			t_min='Table Result - Minimum'
			t_max='Table Result - Maximum'
			ordvar='Order Variable';
      drop m: sd _: ;
	run;
	
	* merge back with source ADSL variable values *; 
	data &varin;	  
	    merge adsl (in=a keep=trt01p: usubjid ittfl &varin. 
	                %if &varin=AGE %then %do; 
					  &varin.u
	                %end; 
					)
	          adfr1 (in=b);
      by trt01pn trt01p;
	  if a;
	  rename &varin=AVAL;	  
	  %if &varin=AGE %then %do; 
        rename &varin.u=AVALU;	  
	  %end; 
	run; 


%mend stat1;

%stat1(varin=AGE, ord=2);
%stat1(varin=HEIGHTBL, ord=5);
%stat1(varin=WEIGHTBL, ord=6);
%stat1(varin=BMIBL, ord=7);
%stat1(varin=MMSETOT, ord=8);


* stats for categorical variables *;

%macro stat2 (varin= , ord=);

  proc freq data=adsl noprint;
    by trt01pn trt01p;
	table &varin / out=adfr (drop=percent rename=(count=T_N));	
  run;

  data adfr1;
    length ORDVAR 8. SRCVAR $8 AVALCAT $50;
	set adfr;
	srcvar="&varin";  * source ADSL variable *; 
	ordvar=&ord;   
	avalcat=strip(&varin);  * source ADSL value *; 
	label t_n='Table Result - n '
		  ordvar='Order Variable'
		  avalcat='Analysis Value Category';
  run;

  * merge back with source ADSL variable values *; 

  %if &varin^=ITTFL %then %do; 
    proc sort data=adfr1;
      by trt01pn trt01p &varin. ;
    run;

    proc sort data=adsl;
      by trt01pn trt01p &varin. ;
    run;
  %end; 

  data &varin;	    
	merge adsl (in=a keep=trt01p: usubjid ittfl 
	                 %if &varin^=ITTFL %then %do; 
					   &varin. &varin.n
	                 %end; 
					)                                  
	      adfr1 (in=b);
    by trt01pn trt01p
       %if &varin^=ITTFL %then %do; 
          &varin. 
       %end;
	;
	if a;		
	%if &varin^=ITTFL %then %do; 
	  rename &varin.n=AVAL;	  	  
	  drop &varin. ;
	%end; 
  run;   

  %if &varin^=ITTFL %then %do; 
    proc sort data=&varin;
      by trt01pn trt01p aval;
    run; 
  %end; 

%mend stat2;

%stat2(varin=ITTFL, ord=1);
%stat2(varin=AGEGR1, ord=3);
%stat2(varin=RACE, ord=4);

data all01;
  set ittfl
      age
	  agegr1
	  race
	  heightbl
	  weightbl
	  bmibl
	  mmsetot;
run; 

* merge in source variable label *;
proc sort data=all01;
  by srcvar;
run; 

proc sort data=adslcont;
  by srcvar;
run; 

data all02;
  length SRCDOM $4 SRCVLABL $50;
  merge all01 (in=a)
        adslcont (in=b);
  by srcvar;
  if a;
  srcdom='ADSL';
  label srcdom='Source Data'
        srcvar='Source Variable'
        srcvlabl='Source Variable Label';
run;  
 
proc sql noprint; 
  create table demog_map as
  select ordvar, trt01pn, trt01p, usubjid, srcdom, srcvar, srcvlabl, avalcat, aval, avalu, t_n, t_mean, t_sd, t_median, t_min, t_max
  from all02
  order by ordvar, trt01pn, trt01p, aval, avalcat;
quit; 

data tfldata.T14_2_01_map (label="Table 14_2_01 - Demography");
  set demog_map; 
run; 
