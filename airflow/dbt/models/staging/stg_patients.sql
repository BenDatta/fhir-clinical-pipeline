-- One row per FHIR Patient. Direct identifiers (names, street address,
-- phone, MRN) are deliberately not carried into the warehouse models.
WITH source AS (
    SELECT payload
    FROM {{ source('clinical_raw', 'fhir_resources') }}
    WHERE resource_type = 'Patient'
)

SELECT
    payload ->> 'id'                                    AS patient_id,
    payload ->> 'gender'                                AS gender,
    (payload ->> 'birthDate')::date                     AS birth_date,
    (payload ->> 'deceasedDateTime')::timestamptz       AS deceased_at,
    (payload ? 'deceasedDateTime'
        OR COALESCE((payload ->> 'deceasedBoolean')::boolean, FALSE)) AS is_deceased,

    -- US Core race / ethnicity extensions: use the 'text' sub-extension
    (SELECT sub ->> 'valueString'
       FROM jsonb_array_elements(payload -> 'extension') ext,
            jsonb_array_elements(ext -> 'extension') sub
      WHERE ext ->> 'url' = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
        AND sub ->> 'url' = 'text'
      LIMIT 1)                                          AS race,
    (SELECT sub ->> 'valueString'
       FROM jsonb_array_elements(payload -> 'extension') ext,
            jsonb_array_elements(ext -> 'extension') sub
      WHERE ext ->> 'url' = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'
        AND sub ->> 'url' = 'text'
      LIMIT 1)                                          AS ethnicity,

    payload -> 'maritalStatus' ->> 'text'               AS marital_status,
    payload -> 'address' -> 0 ->> 'city'                AS city,
    payload -> 'address' -> 0 ->> 'state'               AS state
FROM source
