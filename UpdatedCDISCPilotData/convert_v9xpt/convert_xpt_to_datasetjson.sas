%let project_folder=/_github/lexjansen/UpdatedCDISCPilotData/UpdatedCDISCPilotData;

%include "&project_folder/convert_v9xpt/config.sas";

%macro convert(lib=, type=, data=);
  filename xptFile "%sysfunc(pathname(&lib))/&data..&type";
  %xpt2loc(filespec=xptFile, libref=work);

  %write_datasetjson(
   dataset=work.&data,
   jsonpath=%sysfunc(pathname(&lib))/datasetjson/&data..json,
   usemetadata=N,
   fileOID=CDISCPILOT01.&data,
   studyOID=CDISCPILOT01,
   metaDataVersionOID=MDV.CDISCPILOT01
   );
%mend convert;


/*****************************************************************************************************/
/* CDASH */

%util_gettree(
  dir=%sysfunc(pathname(cdash)), 
  outds=work.cdash_v9xpt, 
  where=%str(ext="v9xpt" and dir=0),
  keep=fullpath
);

data work.cdash_v9xpt;
  length dataset $32 code $2048;
  set work.cdash_v9xpt;
  dataset = scan(fullpath, -2, "\/.");
  code=cats('%nrstr(%convert(lib=cdash, type=v9xpt, data=', dataset, ');)');
  call execute(code);
run;

 /* Get the paths of the JSON files */
%util_gettree(
  dir=%sysfunc(pathname(cdash))/datasetjson, 
  outds=work.dirtree_cdash, 
  where=%str(ext="json" and dir=0),
  keep=fullpath
);

/*****************************************************************************************************/
/* SDTM */

%util_gettree(
  dir=%sysfunc(pathname(sdtm)), 
  outds=work.sdtm_xpt, 
  where=%str(ext="xpt" and dir=0),
  keep=fullpath
);

data work.sdtm_xpt;
  length dataset $32 code $2048;
  set work.sdtm_xpt;
  dataset = scan(fullpath, -2, "\/.");
  if dataset='tracker' then delete;
  code=cats('%nrstr(%convert(lib=sdtm, type=xpt, data=', dataset, ');)');
  call execute(code);
run;

 /* Get the paths of the JSON files */
%util_gettree(
  dir=%sysfunc(pathname(sdtm))/datasetjson, 
  outds=work.dirtree_sdtm, 
  where=%str(ext="json" and dir=0),
  keep=fullpath
);

/*****************************************************************************************************/
/* ADaM */

%util_gettree(
  dir=%sysfunc(pathname(adam)), 
  outds=work.adam_xpt, 
  where=%str(ext="xpt" and dir=0),
  keep=fullpath
);

data work.adam_xpt;
  length dataset $32 code $2048;
  set work.adam_xpt;
  dataset = scan(fullpath, -2, "\/.");
  if dataset='tracker' then delete;
  code=cats('%nrstr(%convert(lib=adam, type=xpt, data=', dataset, ');)');
  call execute(code);
run;

 /* Get the paths of the JSON files */
%util_gettree(
  dir=%sysfunc(pathname(adam))/datasetjson, 
  outds=work.dirtree_adam, 
  where=%str(ext="json" and dir=0),
  keep=fullpath
);

/*****************************************************************************************************/
/* TFL */

%util_gettree(
  dir=%sysfunc(pathname(tfl)), 
  outds=work.tfl_v9xpt, 
  where=%str(ext="v9xpt" and dir=0),
  keep=fullpath
);

data work.tfl_v9xpt;
  length dataset $32 code $2048;
  set work.tfl_v9xpt;
  dataset = scan(fullpath, -2, "\/.");
  code=cats('%nrstr(%convert(lib=tfl, type=v9xpt, data=', dataset, ');)');
  call execute(code);
run;

 /* Get the paths of the JSON files */
%util_gettree(
  dir=%sysfunc(pathname(tfl))/datasetjson, 
  outds=work.dirtree_tfl, 
  where=%str(ext="json" and dir=0),
  keep=fullpath
);



/*****************************************************************************************************/
/* Validate against JSON schema */
data work.results;
  set work.dirtree_cdash(rename=fullpath=json_file)
      work.dirtree_sdtm(rename=fullpath=json_file)
      work.dirtree_adam(rename=fullpath=json_file)
      work.dirtree_tfl(rename=fullpath=json_file);
  length result_code 8 result_character result_path $255 json_file json_schema $512;
  retain json_schema "&dataset_json_sas/schema/dataset.schema.json";
  call missing(result_code, result_character, result_path);

  call validate_datasetjson(json_file, json_schema, result_code, result_character, result_path);
  if result_code = 1 then putlog 'ERR' 'OR:' json_file= result_character= result_path=;
run;

/* Report the results */
%create_template(type=VALIDATION_RESULTS, out=work.schema_validation_results);
data work.schema_validation_results;
  set work.schema_validation_results work.results;
run;  

ods listing close;
ods html5 file="&project_folder/convert_v9xpt/validate_datasetjson_results.html";

  proc print data=work.schema_validation_results label;
  run;
  
ods html5 close;
ods listing;
title01;
