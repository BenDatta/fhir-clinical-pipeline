-- Patient dimension. Age is age at death for deceased patients, otherwise
-- age as of the build date (the mart is rebuilt on every DAG run).
WITH patients AS (
    SELECT
        *,
        DATE_PART('year', AGE(COALESCE(deceased_at::date, CURRENT_DATE), birth_date))::int AS age
    FROM {{ ref('stg_patients') }}
)

SELECT
    patient_id,
    gender,
    birth_date,
    age,
    CASE
        WHEN age < 18 THEN '0-17'
        WHEN age < 35 THEN '18-34'
        WHEN age < 50 THEN '35-49'
        WHEN age < 65 THEN '50-64'
        WHEN age < 80 THEN '65-79'
        ELSE '80+'
    END                       AS age_group,
    is_deceased,
    deceased_at,
    race,
    ethnicity,
    marital_status,
    city,
    state
FROM patients
