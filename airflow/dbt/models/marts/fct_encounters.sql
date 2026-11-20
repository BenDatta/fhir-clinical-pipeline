SELECT
    encounter_id,
    patient_id,
    status,
    encounter_class,
    started_at,
    ended_at,
    CASE
      WHEN started_at IS NOT NULL AND ended_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM (ended_at - started_at)) / 3600.0
    END AS duration_hours
FROM {{ ref('stg_encounters') }}
