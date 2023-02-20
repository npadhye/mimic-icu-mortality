
------- Boosted Tree ------------------------------------

/* Predictive model: train boosted tree for ICU mortality
      Run time ~ 9 min  */
CREATE MODEL
  `mimic-ehr-315921.mimic_data_processed.icu_mort_btree` 
  OPTIONS(model_type='boosted_tree_classifier',
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
  `mimic-ehr-315921.mimic_data_processed.icu_mort_model_table_v1`
WHERE
  split_set IN ('train', 'validation');

-----------------------------------------------------------------


/* Evaluate model performance on testing set */
SELECT
  *
FROM
  ML.EVALUATE(MODEL `mimic-ehr-315921.mimic_data_processed.icu_mort_btree`,
    (
    SELECT
          *
    FROM
           `mimic-ehr-315921.mimic_data_processed.icu_mort_model_table_v1`
    WHERE
          split_set = 'test'));

------------------------------------------------------------


/* Evaluate importance of predictors
      Possible for boosted tree and random forest models in BigQuery ML */
SELECT
  *
FROM
  ML.FEATURE_IMPORTANCE(MODEL `mimic-ehr-315921.mimic_data_processed.icu_mort_btree`)
ORDER BY
  importance_gain DESC;


-----------------------------------------------------------------------------------

------- Random Forest ------------------------------------------------

/* Predictive model: train random forest for ICU mortality
      Run time ~ 9 min  */
CREATE MODEL
  `mimic-ehr-315921.mimic_data_processed.icu_mort_rforest` 
  OPTIONS(model_type='random_forest_classifier',
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
  `mimic-ehr-315921.mimic_data_processed.icu_mort_model_table_v1`
WHERE
  split_set IN ('train', 'validation');

-----------------------------------------------------------------


/* Evaluate model performance on testing set */
SELECT
  *
FROM
  ML.EVALUATE(MODEL `mimic-ehr-315921.mimic_data_processed.icu_mort_rforest`,
    (
    SELECT
          *
    FROM
           `mimic-ehr-315921.mimic_data_processed.icu_mort_model_table_v1`
    WHERE
          split_set = 'test'));

------------------------------------------------------------


/* Evaluate importance of predictors
      Possible for boosted tree and random forest models in BigQuery ML */
SELECT
  *
FROM
  ML.FEATURE_IMPORTANCE(MODEL `mimic-ehr-315921.mimic_data_processed.icu_mort_rforest`)
ORDER BY
  importance_gain DESC;

----------------------------------------------------------------------------------------

-------- Deep Neural Network -----------------------------------------------

/* Predictive model: train DNN for ICU mortality
      Run time ~ 40 min  */
CREATE MODEL `mimic-ehr-315921.mimic_data_processed.icu_mort_dnn`
OPTIONS(MODEL_TYPE='DNN_CLASSIFIER',
        ACTIVATION_FN = 'RELU',
        BATCH_SIZE = 16,
        DROPOUT = 0.1,
        EARLY_STOP = FALSE,
        HIDDEN_UNITS = [128, 128, 128],
        INPUT_LABEL_COLS = ['thirty_day_mort'],
        LEARN_RATE=0.001,
        MAX_ITERATIONS = 50,
        OPTIMIZER = 'ADAGRAD')
AS 
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
  `mimic-ehr-315921.mimic_data_processed.icu_mort_model_table_v1`
WHERE
  split_set IN ('train', 'validation');
-----------------------------------------------------------------


/* Evaluate model performance on testing set */
SELECT
  *
FROM
  ML.EVALUATE(MODEL `mimic-ehr-315921.mimic_data_processed.icu_mort_dnn`,
    (
    SELECT
          *
    FROM
           `mimic-ehr-315921.mimic_data_processed.icu_mort_model_table_v1`
    WHERE
          split_set = 'test'));
------------------------------------------------------------------------------



