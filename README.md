# 2025-2 Data Analytics
# MIMIC 기반 기존 연구 리뷰 및 재현 과제

### File Structure
```
AKI_ML_Prediction/
├── AKI_cohort_1.sql                 # SQL: 코호트 선정 및 제외 기준 적용 (1단계)
├── AKI_cohort_2.sql                 # SQL: AKI 결과 변수 정의 (KDIGO 기준) (2단계)
├── AKI_cohort_3.sql                 # SQL: 예측 변수(활력징후, 랩 데이터 등) 추출 및 통합 (3단계)
├── AKI_cohort.csv                   # SQL 실행 결과로 추출된 원본 데이터 (Raw Data)
├── AKI_cohort.ipynb                 # Preprocessing: 결측치 처리(MICE) 및 인코딩
├── Processed_MIMIC_Data.csv         # 전처리가 완료된 모델링용 데이터셋
├── AKI_model.ipynb                  # Modeling: 모델 학습, 하이퍼파라미터 튜닝, 시각화
├── final_all_models_performance.csv # Result: 모든 모델의 성능 평가 지표 결과
└── requirement.txt                  # 프로젝트 실행에 필요한 Python 라이브러리 목록
```
