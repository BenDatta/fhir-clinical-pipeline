SELECT
    payload ->> 'id' AS observation_id,
    split_part(payload -> 'subject' ->> 'reference', '/', 2) AS patient_id,
    payload ->> 'status' AS status,
    payload -> 'code' -> 'coding' -> 0 ->> 'code' AS observation_code,
    payload -> 'code' -> 'coding' -> 0 ->> 'display' AS observation_name,
    (payload ->> 'effectiveDateTime')::timestamptz AS observed_at,
    (payload -> 'valueQuantity' ->> 'value')::numeric AS value,
    payload -> 'valueQuantity' ->> 'unit' AS unit
FROM {{ source('clinical_raw', 'fhir_resources') }}
WHERE resource_type = 'Observation'
