-- 1단계: AP 코호트 구축 및 기준선 SCr 정의 (Cohort_Base TEMP TABLE 생성)
-- 수정됨: CREATE TEMP TABLE 구문을 맨 위로 올리고, WITH 절을 그 아래에 배치했습니다.

CREATE TEMP TABLE Cohort_Base AS
WITH AcutePancreatitisPatients AS (
    -- AP 진단 코드 (ICD-9: 577.0, ICD-10: K85%)를 가진 환자 식별
    SELECT DISTINCT d.subject_id, d.hadm_id 
    FROM diagnoses_icd AS d
    WHERE (d.icd_version = 9 AND d.icd_code = '5770') OR (d.icd_version = 10 AND d.icd_code LIKE 'K85%')
),
RenalDiseaseHistory AS (
    -- 신장 질환 병력 환자 식별
    SELECT DISTINCT d.subject_id 
    FROM diagnoses_icd AS d
    WHERE (d.icd_version = 9 AND d.icd_code LIKE '585%') OR (d.icd_version = 10 AND d.icd_code LIKE 'N18%')
),
AP_Cohort AS (
    -- AP 환자 중, 18세 이상, ICU 24시간 이상 체류, 신장 질환 병력 없는 환자의 첫 ICU 체류 선택
    SELECT
        icu.subject_id, icu.hadm_id, icu.stay_id, icu.intime, icu.outtime,
        (CAST(strftime('%Y', icu.intime) AS INTEGER) - p.anchor_year) + p.anchor_age AS admission_age,
        (julianday(icu.outtime) - julianday(icu.intime)) * 24 AS icu_los_hours,
        ROW_NUMBER() OVER (PARTITION BY icu.subject_id ORDER BY icu.intime) AS rn
    FROM icustays AS icu
    INNER JOIN AcutePancreatitisPatients AS ap ON icu.hadm_id = ap.hadm_id
    INNER JOIN patients AS p ON icu.subject_id = p.subject_id
    LEFT JOIN RenalDiseaseHistory AS rd ON icu.subject_id = rd.subject_id
    WHERE (CAST(strftime('%Y', icu.intime) AS INTEGER) - p.anchor_year) + p.anchor_age >= 18 
        AND rd.subject_id IS NULL 
        AND (julianday(icu.outtime) - julianday(icu.intime)) * 24 >= 24 
        AND icu.intime IS NOT NULL
),
SCr_Pre_24hr AS (
    -- 기준선 SCr 측정을 위한 크레아티닌 측정값 (입원 전 7일 ~ 입원 후 24시간)
    SELECT t1.subject_id, t1.stay_id, t1.intime, t2.valuenum AS scr_value
    FROM AP_Cohort AS t1
    INNER JOIN labevents AS t2 ON t1.subject_id = t2.subject_id
    WHERE t1.rn = 1 
        AND t2.itemid IN (50912, 227427) 
        AND t2.valuenum IS NOT NULL AND t2.valuenum > 0
        AND t2.charttime BETWEEN DATETIME(t1.intime, '-7 day') AND DATETIME(t1.intime, '+24 hour')
)
-- 최종 SELECT: 코호트 확정 및 기준선 SCr 계산
SELECT
    t1.subject_id, t1.hadm_id, t1.stay_id, t1.intime, t1.outtime, t1.admission_age,
    MIN(t2.scr_value) AS baseline_scr
FROM AP_Cohort AS t1
LEFT JOIN SCr_Pre_24hr AS t2 ON t1.subject_id = t2.subject_id
WHERE t1.rn = 1
GROUP BY 1, 2, 3, 4, 5, 6;