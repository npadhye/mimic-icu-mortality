/* Combine patient and lab data */
WITH
tpat AS (
  SELECT
    a.subject_id,
    a.hadm_id,
    a.stay_id,
    a.gender,
    a.admission_age,
    a.icu_intime,
    CASE
      WHEN a.hospital_expire_flag = 1 OR DATE_DIFF(a.dod, a.dischtime, day) < 30 THEN 1
    ELSE
      0
    END AS thirty_day_mort,
    b.admission_type
  FROM
    `physionet-data.mimiciv_derived.icustay_detail` a
  INNER JOIN
    `physionet-data.mimiciv_hosp.admissions` b
  ON
    a.hadm_id = b.hadm_id
  WHERE
    a.first_icu_stay
),
tlab1 AS (
  SELECT
    stay_id,
    itemid,
    valuenum,
    charttime
  FROM
    `physionet-data.mimiciv_icu.chartevents`
  WHERE
    itemid IN (/* potassium */ 227442,
      /* creatinine */ 220615,
      /* sodium */ 220645,
      /* chloride */ 220602,
      /* bicarbonate (HCO3) */ 227443,
      /* hematocrit */ 220545,
      /* WBC */ 220546,
      /* glucose */ 220621,
      /* magnesium */ 220635,
      /* ionized calcium */ 225667,
      /* non-ionized calcium */ 225625,
      /* phosphorous */ 225677,
      /* lactic acid */ 225668,
      /* HR */ 220045,
      /* mean BP noninvasive */ 220181,
      /* syst BP noninvasive */ 220179,
      /* mean BP arterial */ 220052,
      /* syst BP arterial */ 220050,
      /* temperature (F) */ 223761,
      /* temperature (C) */ 223762,
      /* spo2 forehead */ 229862,
      /* RR */ 220210)
    AND valuenum IS NOT NULL
  ORDER BY
    stay_id,
    itemid
),
tlab2 AS (
  SELECT
    stay_id,
    itemid,
    valuenum
  FROM (
    SELECT
      stay_id,
      itemid,
      valuenum,
      ROW_NUMBER() OVER (PARTITION BY stay_id, itemid ORDER BY charttime) AS row_num
    FROM
      tlab1
  )
  WHERE
    row_num = 1
  ORDER BY
    stay_id,
    itemid
),
tlab2_pivot AS (
  SELECT
    *
  FROM ( /* temporary table */
    SELECT
      *
    FROM
      tlab2 ) tlab2_temp PIVOT (SUM(valuenum) FOR itemid IN (227442 AS potassium,
        220615 AS creatinine,
        220645 AS sodium,
        220602 AS chloride,
        227443 AS bicarb,
        220545 AS hematocrit,
        220546 AS WBC,
        220621 AS glucose,
        220635 AS magnesium,
        225667 AS calcium_ion,
        225625 AS calcium_nonion,
        225677 AS phosphorous,
        225668 AS lactic_acid,
        220045 AS HR,
        220181 AS MBP_noninv,
        220179 AS SBP_noninv,
        220052 AS MBP_art,
        220050 AS SBP_art,
        223761 AS temp_F,
        223762 AS temp_C,
        229862 AS spo2,
        220210 AS RR ) )
  ORDER BY
    stay_id
),
t_final AS (
  SELECT
    tpat.*,
    tlab2_pivot.*
  FROM
    tpat
  INNER JOIN
    tlab2_pivot
  ON
    tpat.stay_id = tlab2_pivot.stay_id
)
SELECT
  *
FROM
  t_final
ORDER BY
  subject_id;
--------------------------------------------------------------

/* Note problems with temp_F from distribution - use Google Studio */


/* Assess other data quality problems */
SELECT
  MBP_noninv
FROM
  icumort.data_v1
WHERE
  MBP_noninv > 100000; 

/* 
potassium 4x 999999 
creatinine 6x 999999 
sodium 4x 999999
chloride 6x 999999
hematocrit 12x 999999
WBC 12x 999999
glucose 17x 999999
magnesium 3x 999999
calcium_ion 5x 999999
calcium_nonion 3x 999999
phosphorus 3x 999999
lactic_acid 4x 999999
HR none
MBP_noninv replace 3x above 100,000 (incl. 120130 and 140119)
MBP_art replace 1x above 100,000 (106112)
SBP_art none
SBP_noninv replace 1x above 100,000 (116114)
spo2 none
RR none
*/
----------------------------------------------------------

# Save resulting table as BQ table "data_v1" in dataset "icumort"

----------------------------------------------------------


/* Fix some of the data quality issues
      1. Temperature scale confusion
      2. Very large values in 15 columns */
UPDATE
  icumort.data_v1
SET
  temp_F = 32 +1.8*temp_C
WHERE
  temp_F IS NULL
  OR temp_F < 80;


UPDATE
  icumort.data_v1
SET
  potassium = NULL
WHERE
  potassium > 100000;

UPDATE
  icumort.data_v1
SET
  creatinine = NULL
WHERE
  creatinine > 100000;

UPDATE
  icumort.data_v1
SET
  sodium = NULL
WHERE
  sodium > 100000;

UPDATE
  icumort.data_v1
SET
  chloride = NULL
WHERE
  chloride > 100000;

UPDATE
  icumort.data_v1
SET
  hematocrit = NULL
WHERE
  hematocrit > 100000;

UPDATE
  icumort.data_v1
SET
  WBC = NULL
WHERE
  WBC > 100000;

UPDATE
  icumort.data_v1
SET
  glucose = NULL
WHERE
  glucose > 100000;

UPDATE
  icumort.data_v1
SET
  magnesium = NULL
WHERE
  magnesium > 100000;

UPDATE
  icumort.data_v1
SET
  calcium_ion = NULL
WHERE
  calcium_ion > 100000;

UPDATE
  icumort.data_v1
SET
  calcium_nonion = NULL
WHERE
  calcium_nonion > 100000;

UPDATE
  icumort.data_v1
SET
  phosphorous = NULL
WHERE
  phosphorous > 100000;

UPDATE
  icumort.data_v1
SET
  lactic_acid = NULL
WHERE
  lactic_acid > 100000;

UPDATE
  icumort.data_v1
SET
  MBP_noninv = NULL
WHERE
  MBP_noninv > 100000;

UPDATE
  icumort.data_v1
SET
  MBP_art = NULL
WHERE
  MBP_art > 100000;

UPDATE
  icumort.data_v1
SET
  SBP_noninv = NULL
WHERE
  SBP_noninv > 100000;
------------------------------------------------------------


/* Use Google anomaly detection tool to label anomalies */

-- Anomaly detection Step 1: create autoencoder model for anomaly detection in icu mortality data
-- Run time ~ 9 minutes
CREATE MODEL icumort.my_autoencoder_model
OPTIONS(
  model_type='autoencoder',
  activation_fn='relu',
  batch_size=8,
  dropout=0.2,  
  hidden_units=[32, 16, 4, 16, 32],
  learn_rate=0.001,
  l1_reg_activation=0.0001,
  max_iterations=10,
  optimizer='adam'
) AS 
SELECT 
  * EXCEPT(subject_id, hadm_id, stay_id, stay_id_1, icu_intime, temp_C, thirty_day_mort)
FROM 
  icumort.data_v1;
--


-- Anomaly detection Step 2: use above model to detect anomalies
SELECT
  *
FROM
  ML.DETECT_ANOMALIES(MODEL icumort.my_autoencoder_model,
                      STRUCT(0.02 AS contamination),
                      TABLE icumort.data_v1);

-------------------------------------------------------------------------

# Save resulting table as BQ table "data_anomalies_v1" in dataset "icumort"

-------------------------------------------------------------------------


/* How many anomalies were found? */
SELECT
  COUNT(*)
FROM
  icumort.data_anomalies_v1
WHERE
  is_anomaly;

/* What is the fraction or % of anomalous data? */
WITH
n_table AS (
  SELECT
    COUNT(*) AS N,
    COUNT(CASE WHEN is_anomaly THEN 1 END) AS N_anom
  FROM
    icumort.data_anomalies_v1
)
SELECT
  *,
  N_anom/N AS fraction_anom
FROM
  n_table;

-----------------------------------------------------------------



/* Create training, validation, and test split by hashing stay_id
      And drop anomalous rows */
WITH
  base_table AS (
  SELECT
    *
  FROM
    icumort.data_anomalies_v1
  WHERE
    NOT(is_anomaly)
  )
  -- Main Query
SELECT
  *,
  CASE
    WHEN ABS(MOD(FARM_FINGERPRINT(TO_JSON_STRING(stay_id)), 10)) < 8 THEN 'train'
    WHEN ABS(MOD(FARM_FINGERPRINT(TO_JSON_STRING(stay_id)), 10)) = 8 THEN 'validation'
    WHEN ABS(MOD(FARM_FINGERPRINT(TO_JSON_STRING(stay_id)), 10)) = 9 THEN 'test'
  END
  AS split_set
FROM
  base_table;

----------------------------------------------------------------------------

# Save resulting table as BQ table "data_ml_v1" in dataset "icumort"
# This table is ready for training ML models

-------------------------------------------------------------------------



/* Count missing values for each column */
SELECT
  COUNT(CASE WHEN thirty_day_mort IS NULL THEN 1 END) AS M_30d_mort,
  COUNT(CASE WHEN gender IS NULL THEN 1 END) AS M_gender,
  COUNT(CASE WHEN admission_age IS NULL THEN 1 END) AS M_age,
  COUNT(CASE WHEN admission_type IS NULL THEN 1 END) AS M_admtype,
  COUNT(CASE WHEN potassium IS NULL THEN 1 END) AS M_potassium,
  COUNT(CASE WHEN sodium IS NULL THEN 1 END) AS M_sodium,
  COUNT(CASE WHEN chloride IS NULL THEN 1 END) AS M_chloride,
  COUNT(CASE WHEN bicarb IS NULL THEN 1 END) AS M_bicarb,
  COUNT(CASE WHEN creatinine IS NULL THEN 1 END) AS M_creatinine,
  COUNT(CASE WHEN hematocrit IS NULL THEN 1 END) AS M_hematocrit,
  COUNT(CASE WHEN WBC IS NULL THEN 1 END) AS M_WBC,
  COUNT(CASE WHEN glucose IS NULL THEN 1 END) AS M_glucose,
  COUNT(CASE WHEN magnesium IS NULL THEN 1 END) AS M_magnesium,
  COUNT(CASE WHEN calcium_ion IS NULL THEN 1 END) AS M_calcion,
  COUNT(CASE WHEN calcium_nonion IS NULL THEN 1 END) AS M_calcnonion,
  COUNT(CASE WHEN phosphorous IS NULL THEN 1 END) AS M_phosphorous,
  COUNT(CASE WHEN lactic_acid IS NULL THEN 1 END) AS M_lactic_acid,
  COUNT(CASE WHEN HR IS NULL THEN 1 END) AS M_HR,
  COUNT(CASE WHEN MBP_noninv IS NULL THEN 1 END) AS M_MBP_noninv,
  COUNT(CASE WHEN SBP_noninv IS NULL THEN 1 END) AS M_SBP_noninv,
  COUNT(CASE WHEN MBP_art IS NULL THEN 1 END) AS M_MBP_art,
  COUNT(CASE WHEN SBP_art IS NULL THEN 1 END) AS M_SBP_art,
  COUNT(CASE WHEN temp_F IS NULL THEN 1 END) AS M_tempF,
  COUNT(CASE WHEN temp_C IS NULL THEN 1 END) AS M_tempC,
  COUNT(CASE WHEN spo2 IS NULL THEN 1 END) AS M_spo2,
  COUNT(CASE WHEN RR IS NULL THEN 1 END) AS M_RR,
FROM
  icumort.data_ml_v1;

/* Note large missing fractions for
   1. calcium_ion
   2. lactic_acid
   3. MBP_art
   4. SBP_art
   5. temp_C
   6. spo2 */

--------------------------------------------------------------


/* Check number of useful rows in data table
    - after leaving out the columns with high missing fraction */
SELECT
  COUNT(1)
FROM
  icumort.data_ml_v1
WHERE
  admission_age IS NOT NULL
  AND gender IS NOT NULL
  AND admission_type IS NOT NULL
  AND potassium IS NOT NULL
  AND bicarb IS NOT NULL
  AND creatinine IS NOT NULL
  AND sodium IS NOT NULL
  AND chloride IS NOT NULL
  AND hematocrit IS NOT NULL
  AND WBC IS NOT NULL
  AND glucose IS NOT NULL
  AND magnesium IS NOT NULL
  AND calcium_nonion IS NOT NULL
  AND phosphorous IS NOT NULL
  AND HR IS NOT NULL
  AND RR IS NOT NULL
  AND temp_F IS NOT NULL
  AND MBP_noninv IS NOT NULL
  AND SBP_noninv IS NOT null;

----------------------------------------------


/* Predictive model: train logistic regression for ICU mortality  */
#standardSQL
CREATE MODEL
  icumort.logistic1 
  OPTIONS(model_type='logistic_reg',
          input_label_cols=['thirty_day_mort'],
          data_split_method = 'RANDOM',
          data_split_eval_fraction = 0.1) AS
SELECT
  thirty_day_mort,
  admission_age,
  gender,
  admission_type,
  potassium,
  bicarb,
  creatinine,
  sodium,
  chloride,
  hematocrit,
  WBC,
  glucose,
  magnesium,
  calcium_nonion,
  phosphorous,
  HR,
  RR,
  temp_F,
  MBP_noninv,
  SBP_noninv
FROM
  icumort.data_ml_v1
WHERE
  split_set IN ('train', 'validation');

-----------------------------------------------------------------


/* Evaluate model performance on testing set */
SELECT
  *
FROM
  ML.EVALUATE(MODEL icumort.logistic1,
    (
    SELECT
          *
    FROM
           icumort.data_ml_v1
    WHERE
          split_set = 'test'));

------------------------------------------------------------


/* Predict on test set
      and view predictions for each case */
SELECT
   *
FROM
  ML.PREDICT(MODEL icumort.logistic1,
    (
    SELECT
          *
    FROM
           icumort.data_ml_v1
    WHERE
          split_set = 'test'
    ));


-------------------------------------------------------------

/* Describe features */
SELECT
  *
FROM
  ML.FEATURE_INFO(MODEL icumort.logistic1)


