#!/bin/bash
set -e

python load_csv.py harvest_local harvest_local.csv harvest_local.ctl pcornet_cdm_user pcornet_cdm
python load_csv.py PMN_LabNormal pmn_labnormal.csv pmn_labnormal.ctl pcornet_cdm_user pcornet_cdm

# Run some tests
sqlplus /nolog <<EOF
connect ${pcornet_cdm_user}/${pcornet_cdm}

set echo on;

define i2b2_data_schema=${i2b2_data_schema}
define i2b2_etl_schema=${i2b2_etl_schema}

WHENEVER SQLERROR EXIT SQL.SQLCODE;

-- Make sure the ethnicity code has been added to the patient dimension
-- See update_ethnicity_pdim.sql
select ethnicity_cd from "&&i2b2_data_schema".patient_dimension where 1=0;

-- Make sure that the providerid column has been added to the visit dimension
select providerid from "&&i2b2_data_schema".visit_dimension where 1=0;

-- Make sure the inout_cd has been populated
-- See heron_encounter_style.sql
select case when qty = 0 then 1/0 else 1 end inout_cd_populated from (
  select count(*) qty from "&&i2b2_data_schema".visit_dimension where inout_cd is not null
  );

-- Make sure the RXNorm mapping table exists
select rxcui from "&&i2b2_etl_schema".clarity_med_id_to_rxcui@id where 1=0;

-- Make sure the observation fact medication table is populated
select case when qty > 0 then 1 else 1/0 end obs_fact_meds_populated from (
  select count(*) qty from observation_fact_meds
  );
EOF


########### Initialize Schema ###########
if [ ${initialize_schema} == 'true' ]
then

sqlplus /nolog <<EOF
connect ${pcornet_cdm_user}/${pcornet_cdm}

set echo on;
set timing on;
set linesize 3000;
set pagesize 5000;

define i2b2_data_schema=${i2b2_data_schema}
define i2b2_meta_schema=${i2b2_meta_schema}
define i2b2_etl_schema=${i2b2_etl_schema}
define datamart_id=${datamart_id}
define datamart_name=${datamart_name}
define network_id=${network_id}
define network_name=${network_name}
define terms_table=${terms_table}
define min_pat_list_date_dd_mon_rrrr=${min_pat_list_date_dd_mon_rrrr}
define min_visit_date_dd_mon_rrrr=${min_visit_date_dd_mon_rrrr}
define enrollment_months_back=${enrollment_months_back}
define pcornet_cdm_user=${pcornet_cdm_user}

-- Prepare for transform
start PCORNetInit.sql
EOF

fi


########### Load Transform Procedures ###########
if [ ${load_procedures} == 'true' ]
then

sqlplus /nolog <<EOF
connect ${pcornet_cdm_user}/${pcornet_cdm}

set echo on;
set timing on;
set linesize 3000;
set pagesize 5000;

define i2b2_data_schema=${i2b2_data_schema}
define i2b2_meta_schema=${i2b2_meta_schema}
define i2b2_etl_schema=${i2b2_etl_schema}
define datamart_id=${datamart_id}
define datamart_name=${datamart_name}
define network_id=${network_id}
define network_name=${network_name}
define terms_table=${terms_table}
define min_pat_list_date_dd_mon_rrrr=${min_pat_list_date_dd_mon_rrrr}
define min_visit_date_dd_mon_rrrr=${min_visit_date_dd_mon_rrrr}
define enrollment_months_back=${enrollment_months_back}
define pcornet_cdm_user=${pcornet_cdm_user}

-- Define transform procedures
start PCORNetLoader_ora.sql
EOF

fi


########### Exectute Transform ########### 
sqlplus /nolog <<EOF
connect ${pcornet_cdm_user}/${pcornet_cdm}

set echo on;
set timing on;
set linesize 3000;
set pagesize 5000;

-- Run transform
execute PCORNetLoader('${start_with}', '${release_name}', '${BUILD_NUMBER}', '${data_source}');
EOF


########### Run Stats / Tests ###########
sqlplus /nolog <<EOF
connect ${pcornet_cdm_user}/${pcornet_cdm}

set echo on;
set timing on;
set linesize 3000;
set pagesize 5000;

define pcornet_cdm_user=${pcornet_cdm_user}
define i2b2_data_schema=${i2b2_data_schema}

-- Report stats
start cdm_stats.sql

-- CDM transform tests
start cdm_transform_tests.sql

quit;
EOF
