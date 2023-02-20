# mimic-icu-mortality

BigQuery SQL code is provided here to analyze MIMIC-IV electronic health records. 
The aim is to predict ICU mortality based on first measures of many lab measures, plus age, gender, admission type.

For more information about the study, see chapter 21 of the book [Secondary Analysis of Electronic Health Records](https://www.ncbi.nlm.nih.gov/books/NBK543630/)

* The original code provided by the authors of the chapter was for an earlier version of MIMIC data, and it was not designed for BigQuery.
* This repository has BigQuery SQL code that has been verified to work with MIMIC-IV data.
* Additionally, an autoencoder is used for anomaly detection.
* Mortality prediction is carried out with BigQuery ML algorithms. 
