-- One row per FHIR Condition (diagnoses, coded in SNOMED CT).
SELECT
    payload ->> 'id'                                                   AS condition_id,
    split_part(payload -> 'subject' ->> 'reference', '/', 2)           AS patient_id,
    split_part(payload -> 'encounter' ->> 'reference', '/', 2)         AS encounter_id,
    payload -> 'code' -> 'coding' -> 0 ->> 'code'                      AS condition_code,
    payload -> 'code' -> 'coding' -> 0 ->> 'display'                   AS condition_name,
    payload -> 'code' -> 'coding' -> 0 ->> 'system'                    AS code_system,
    -- SNOMED CT semantic tag, e.g. 'disorder', 'finding', 'situation'
    substring(payload -> 'code' -> 'coding' -> 0 ->> 'display' from '\(([^()]*)\)\s*$') AS condition_type,
    payload -> 'clinicalStatus' -> 'coding' -> 0 ->> 'code'            AS clinical_status,
    payload -> 'verificationStatus' -> 'coding' -> 0 ->> 'code'        AS verification_status,
    payload -> 'category' -> 0 -> 'coding' -> 0 ->> 'code'             AS category,
    (payload ->> 'onsetDateTime')::timestamptz                         AS onset_at,
    (payload ->> 'abatementDateTime')::timestamptz                     AS abated_at,
    (payload ->> 'recordedDate')::timestamptz                          AS recorded_at
FROM {{ source('clinical_raw', 'fhir_resources') }}
WHERE resource_type = 'Condition'
