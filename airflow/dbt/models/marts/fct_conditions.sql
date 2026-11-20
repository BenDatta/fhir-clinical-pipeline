SELECT
    condition_id,
    patient_id,
    encounter_id,
    condition_code,
    condition_name,
    condition_type,
    clinical_status,
    verification_status,
    category,
    onset_at,
    abated_at,
    recorded_at,
    clinical_status = 'active' AS is_active,
    CASE
      WHEN abated_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM (abated_at - onset_at)) / 86400.0
    END                         AS duration_days
FROM {{ ref('stg_conditions') }}
