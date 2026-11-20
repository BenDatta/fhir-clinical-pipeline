SELECT
    observation_id,
    patient_id,
    status,
    observation_code,
    observation_name,
    observed_at,
    value,
    unit
FROM {{ ref('stg_observations') }}
