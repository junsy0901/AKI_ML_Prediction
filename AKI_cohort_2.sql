-- 2단계: AKI 결과 변수 계산 및 저장 (수정됨: CREATE를 맨 위로)
CREATE TEMP TABLE Cohort_AKI AS
WITH SCr_Measurements AS (
    -- 1단계에서 확정된 코호트 환자의 7일간 크레아티닌 측정값 가져오기
    SELECT 
        t1.subject_id, t1.stay_id, t1.intime, t2.charttime, t2.valuenum AS current_scr, t1.baseline_scr
    FROM Cohort_Base AS t1
    INNER JOIN labevents AS t2 ON t1.subject_id = t2.subject_id
    WHERE t2.itemid IN (50912, 227427) 
        AND t2.valuenum IS NOT NULL AND t2.valuenum > 0
        AND t2.charttime BETWEEN t1.intime AND DATETIME(t1.intime, '+7 day')
),
AKI_Status_Calc AS (
    -- KDIGO 기준 적용 (48시간 윈도우 계산 포함)
    SELECT s.stay_id,
        MAX(
            CASE 
                -- 48시간 이내 0.3mg/dL 증가
                WHEN (s.current_scr - (
                    SELECT MIN(t.current_scr) 
                    FROM SCr_Measurements AS t 
                    WHERE t.subject_id = s.subject_id 
                      AND t.charttime BETWEEN DATETIME(s.charttime, '-48 hour') AND s.charttime
                )) >= 0.3 THEN 1
                -- 기준선 대비 1.5배 증가
                WHEN (s.current_scr / s.baseline_scr) >= 1.5 THEN 1
                ELSE 0
            END
        ) AS aki_outcome
    FROM SCr_Measurements AS s
    GROUP BY s.stay_id
)
-- 최종 SELECT: 1단계 코호트 정보에 AKI 결과 붙이기
SELECT 
    t1.*,
    COALESCE(t2.aki_outcome, 0) AS aki_outcome -- AKI 정보가 없으면 0(Non-AKI)으로 처리
FROM Cohort_Base AS t1
LEFT JOIN AKI_Status_Calc AS t2 ON t1.stay_id = t2.stay_id;