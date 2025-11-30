-- 기존 테이블 삭제 (재실행 시 오류 방지)
DROP TABLE IF EXISTS Final_Dataset;

-- 3단계: 예측 변수 추출 및 최종 테이블 생성
CREATE TEMP TABLE Final_Dataset AS
WITH Vitals_24hr AS (
    -- 활력 징후: chartevents 사용 (valuenum 컬럼)
    SELECT t1.stay_id,
        AVG(CASE WHEN t2.itemid = 220045 THEN t2.valuenum END) AS heart_rate_mean,
        AVG(CASE WHEN t2.itemid = 220179 THEN t2.valuenum END) AS sbp_mean,
        AVG(CASE WHEN t2.itemid = 220180 THEN t2.valuenum END) AS dbp_mean,
        AVG(CASE WHEN t2.itemid = 220181 THEN t2.valuenum END) AS mbp_mean,
        AVG(CASE WHEN t2.itemid = 220210 THEN t2.valuenum END) AS resp_rate_mean,
        AVG(CASE WHEN t2.itemid = 223761 THEN t2.valuenum END) AS temperature_mean,
        AVG(CASE WHEN t2.itemid = 220277 THEN t2.valuenum END) AS spo2_mean
    FROM Cohort_AKI AS t1
    INNER JOIN chartevents AS t2 ON t1.stay_id = t2.stay_id
    WHERE t2.charttime BETWEEN t1.intime AND DATETIME(t1.intime, '+24 hour') 
    GROUP BY t1.stay_id
),
Labs_24hr AS (
    -- 실험실 데이터: labevents 사용 (valuenum 컬럼)
    SELECT t1.stay_id,
        MAX(CASE WHEN t2.itemid = 51301 THEN t2.valuenum END) AS wbc_max,
        MAX(CASE WHEN t2.itemid = 51221 THEN t2.valuenum END) AS hematocrit_max,
        MAX(CASE WHEN t2.itemid = 51222 THEN t2.valuenum END) AS hemoglobin_max,
        MAX(CASE WHEN t2.itemid = 51265 THEN t2.valuenum END) AS platelets_max,
        MAX(CASE WHEN t2.itemid = 50912 THEN t2.valuenum END) AS creatinine_max,
        MAX(CASE WHEN t2.itemid = 51006 THEN t2.valuenum END) AS bun_max,
        MIN(CASE WHEN t2.itemid = 50868 THEN t2.valuenum END) AS aniongap_min,
        MAX(CASE WHEN t2.itemid = 50882 THEN t2.valuenum END) AS bicarbonate_max,
        MAX(CASE WHEN t2.itemid = 50893 THEN t2.valuenum END) AS calcium_max,
        MAX(CASE WHEN t2.itemid = 50902 THEN t2.valuenum END) AS chloride_max,
        MAX(CASE WHEN t2.itemid IN (50931, 50809) THEN t2.valuenum END) AS glucose_max,
        MAX(CASE WHEN t2.itemid = 50983 THEN t2.valuenum END) AS sodium_max,
        MAX(CASE WHEN t2.itemid = 50971 THEN t2.valuenum END) AS potassium_max,
        MAX(CASE WHEN t2.itemid = 51237 THEN t2.valuenum END) AS inr_max,
        MAX(CASE WHEN t2.itemid = 51274 THEN t2.valuenum END) AS pt_max,
        MAX(CASE WHEN t2.itemid = 51275 THEN t2.valuenum END) AS ptt_max,
        MAX(CASE WHEN t2.itemid = 50861 THEN t2.valuenum END) AS alt_max,
        MAX(CASE WHEN t2.itemid = 50878 THEN t2.valuenum END) AS ast_max,
        MAX(CASE WHEN t2.itemid = 50863 THEN t2.valuenum END) AS alp_max,
        MAX(CASE WHEN t2.itemid = 50885 THEN t2.valuenum END) AS bilirubin_total_max
    FROM Cohort_AKI AS t1
    INNER JOIN labevents AS t2 ON t1.subject_id = t2.subject_id
    WHERE t2.charttime BETWEEN t1.intime AND DATETIME(t1.intime, '+24 hour') 
    GROUP BY t1.stay_id
),
Urine_Output AS (
    -- 소변량: outputevents 사용 (!!! 수정됨: valuenum -> value !!!)
    SELECT t1.stay_id,
        SUM(t2.value) AS urineoutput_24hr  -- valuenum이 아닌 value 컬럼을 사용합니다.
    FROM Cohort_AKI AS t1
    INNER JOIN outputevents AS t2 ON t1.stay_id = t2.stay_id
    WHERE t2.charttime BETWEEN t1.intime AND DATETIME(t1.intime, '+24 hour')
    GROUP BY t1.stay_id
),
Comorbidities AS (
    -- 기저 질환: diagnoses_icd 사용
    SELECT t1.subject_id,
        MAX(CASE WHEN d.icd_code LIKE '410%' OR d.icd_code LIKE '412%' OR d.icd_code LIKE 'I21%' OR d.icd_code LIKE 'I22%' THEN 1 ELSE 0 END) AS myocardial_infarct,
        MAX(CASE WHEN d.icd_code LIKE '428%' OR d.icd_code LIKE 'I50%' THEN 1 ELSE 0 END) AS congestive_heart_failure,
        MAX(CASE WHEN d.icd_code LIKE '4439%' OR d.icd_code LIKE 'I739%' THEN 1 ELSE 0 END) AS peripheral_vascular_disease,
        MAX(CASE WHEN d.icd_code LIKE '430%' OR d.icd_code LIKE 'I60%' THEN 1 ELSE 0 END) AS cerebrovascular_disease,
        MAX(CASE WHEN d.icd_code LIKE '290%' OR d.icd_code LIKE 'F00%' THEN 1 ELSE 0 END) AS dementia,
        MAX(CASE WHEN d.icd_code LIKE '49%' OR d.icd_code LIKE 'J44%' THEN 1 ELSE 0 END) AS chronic_pulmonary_disease,
        MAX(CASE WHEN d.icd_code LIKE '710%' OR d.icd_code LIKE 'M05%' THEN 1 ELSE 0 END) AS rheumatic_disease,
        MAX(CASE WHEN d.icd_code LIKE '531%' OR d.icd_code LIKE 'K25%' THEN 1 ELSE 0 END) AS peptic_ulcer_disease,
        MAX(CASE WHEN (d.icd_code LIKE '571%' OR d.icd_code LIKE 'K70%') AND NOT (d.icd_code LIKE '572%' OR d.icd_code LIKE 'K72%') THEN 1 ELSE 0 END) AS mild_liver_disease,
        MAX(CASE WHEN d.icd_code LIKE '572%' OR d.icd_code LIKE 'K72%' THEN 1 ELSE 0 END) AS severe_liver_disease,
        MAX(CASE WHEN d.icd_code LIKE '250%' OR d.icd_code LIKE 'E11%' THEN 1 ELSE 0 END) AS diabetes,
        MAX(CASE WHEN d.icd_code LIKE '344%' OR d.icd_code LIKE 'G82%' THEN 1 ELSE 0 END) AS paraplegia,
        MAX(CASE WHEN d.icd_code LIKE '19%' OR d.icd_code LIKE 'C7%' THEN 1 ELSE 0 END) AS malignant_cancer,
        MAX(CASE WHEN d.icd_code LIKE '042%' OR d.icd_code LIKE 'B20%' THEN 1 ELSE 0 END) AS aids
    FROM Cohort_AKI AS t1
    LEFT JOIN diagnoses_icd AS d ON t1.subject_id = d.subject_id
    GROUP BY t1.subject_id
)

-- 최종 SELECT
SELECT
    c.subject_id, c.hadm_id, c.stay_id, 
    c.admission_age,
    p.gender,
    adm.race,
    adm.insurance,
    adm.admission_type,
    c.aki_outcome,
    c.baseline_scr,
    v.heart_rate_mean, v.sbp_mean, v.dbp_mean, v.mbp_mean,
    v.resp_rate_mean, v.temperature_mean, v.spo2_mean,
    u.urineoutput_24hr,
    l.wbc_max, l.hematocrit_max, l.hemoglobin_max, l.platelets_max,
    l.creatinine_max, l.bun_max, l.aniongap_min, l.bicarbonate_max,
    l.calcium_max, l.chloride_max, l.glucose_max, l.sodium_max, l.potassium_max,
    l.inr_max, l.pt_max, l.ptt_max,
    l.alt_max, l.ast_max, l.alp_max, l.bilirubin_total_max,
    co.myocardial_infarct, co.congestive_heart_failure, co.peripheral_vascular_disease,
    co.cerebrovascular_disease, co.dementia, co.chronic_pulmonary_disease,
    co.rheumatic_disease, co.peptic_ulcer_disease, co.mild_liver_disease,
    co.severe_liver_disease, co.diabetes, co.paraplegia,
    co.malignant_cancer, co.aids
FROM Cohort_AKI AS c
INNER JOIN patients AS p ON c.subject_id = p.subject_id
INNER JOIN admissions AS adm ON c.hadm_id = adm.hadm_id
LEFT JOIN Vitals_24hr AS v ON c.stay_id = v.stay_id
LEFT JOIN Labs_24hr AS l ON c.stay_id = l.stay_id
LEFT JOIN Urine_Output AS u ON c.stay_id = u.stay_id
LEFT JOIN Comorbidities AS co ON c.subject_id = co.subject_id
ORDER BY c.subject_id;