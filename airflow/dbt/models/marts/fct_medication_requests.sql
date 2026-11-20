SELECT
    medication_request_id,
    patient_id,
    encounter_id,
    status,
    intent,
    medication_code,
    medication_name,
    medication_source,
    reason_condition_id,
    reason_name,
    dosage_text,
    authored_at
FROM {{ ref('stg_medication_requests') }}
