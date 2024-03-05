/*****************************************************************************************************/
/*** Include macros from dataset_json_sas project (https://github.com/lexjansen/dataset-json-sas)  ***/
/*****************************************************************************************************/

%let dataset_json_sas = /_github/lexjansen/dataset-json-sas;
options sasautos = (%qsysfunc(compress(%qsysfunc(getoption(SASAUTOS)),%str(%()%str(%)))) "&dataset_json_sas/macros");
options ls=max;
filename luapath ("&dataset_json_sas/lua");

%* This is needed to be able to run Python;
%* Update to your own locations           ;
options set=MAS_PYPATH="&dataset_json_sas/venv/Scripts/python.exe";
options set=MAS_M2PATH="%sysget(SASROOT)/tkmas/sasmisc/mas2py.py";

%let fcmplib=work;
%include "&dataset_json_sas/macros/validate_datasetjson.sas";

options cmplib=&fcmplib..datasetjson_funcs;

/*****************************************************************************************************/
/*****************************************************************************************************/



libname cdash "&project_folder/CDASH";
libname sdtm "&project_folder/SDTM";
libname adam "&project_folder/ADaM";
libname tfl "&project_folder/TFL datasets";
