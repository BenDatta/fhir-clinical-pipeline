-- One row per FHIR MedicationRequest (prescriptions, coded in RxNorm).
-- The drug is either embedded (medicationCodeableConcept) or referenced
-- (medicationReference -> Medication resource); both are resolved here.
WITH requests AS (
    SELECT payload
    FROM {{ source('clinical_raw', 'fhir_resources') }}
    WHERE resource_type = 'MedicationRequest'
),

medications AS (
    SELECT
        payload ->> 'id'                              AS medication_id,
        payload -> 'code' -> 'coding' -> 0 ->> 'code'    AS medication_code,
        payload -> 'code' -> 'coding' -> 0 ->> 'display' AS medication_name
    FROM {{ source('clinical_raw', 'fhir_resources') }}
    WHERE resource_type = 'Medication'
)

SELECT
    r.payload ->> 'id'                                                  AS medication_request_id,
    split_part(r.payload -> 'subject' ->> 'reference', '/', 2)          AS patient_id,
    split_part(r.payload -> 'encounter' ->> 'reference', '/', 2)        AS encounter_id,
    r.payload ->> 'status'                                              AS status,
    r.payload ->> 'intent'                                              AS intent,
    COALESCE(r.payload -> 'medicationCodeableConcept' -> 'coding' -> 0 ->> 'code',
             m.medication_code)                                         AS medication_code,
    COALESCE(r.payload -> 'medicationCodeableConcept' -> 'coding' -> 0 ->> 'display',
             m.medication_name)                                         AS medication_name,
    CASE WHEN r.payload ? 'medicationReference' THEN 'reference' ELSE 'embedded' END
                                                                        AS medication_source,
    split_part(r.payload -> 'reasonReference' -> 0 ->> 'reference', '/', 2) AS reason_condition_id,
    r.payload -> 'reasonCode' -> 0 -> 'coding' -> 0 ->> 'display'       AS reason_name,
    r.payload -> 'dosageInstruction' -> 0 ->> 'text'                    AS dosage_text,
    (r.payload ->> 'authoredOn')::timestamptz                           AS authored_at
FROM requests r
LEFT JOIN medications m
       ON m.medication_id = split_part(r.payload -> 'medicationReference' ->> 'reference', '/', 2)
