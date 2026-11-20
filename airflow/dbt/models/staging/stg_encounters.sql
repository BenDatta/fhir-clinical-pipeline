SELECT
    payload ->> 'id' AS encounter_id,
    split_part(payload -> 'subject' ->> 'reference', '/', 2) AS patient_id,
    payload ->> 'status' AS status,
    payload -> 'class' ->> 'code' AS encounter_class,
    (payload -> 'period' ->> 'start')::timestamptz AS started_at,
    (payload -> 'period' ->> 'end')::timestamptz AS ended_at
FROM {{ source('clinical_raw', 'fhir_resources') }}
WHERE resource_type = 'Encounter'
