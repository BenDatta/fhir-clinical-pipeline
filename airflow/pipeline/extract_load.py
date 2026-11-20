import os
import requests
import psycopg2
from psycopg2.extras import Json, execute_values

FHIR_BASE_URL = os.getenv("FHIR_BASE_URL", "http://localhost:8090/fhir")
# Medication is needed because some MedicationRequests reference the drug
# (medicationReference) instead of embedding it (medicationCodeableConcept).
RESOURCE_TYPES = ["Patient", "Encounter", "Observation", "Condition", "MedicationRequest", "Medication"]
PAGE_SIZE = int(os.getenv("FHIR_PAGE_SIZE", "1000"))  # HAPI max_page_size is 1000

UPSERT_SQL = '''
    INSERT INTO raw.fhir_resources
        (resource_type, resource_id, last_updated, payload)
    VALUES %s
    ON CONFLICT (resource_type, resource_id)
    DO UPDATE SET
        last_updated = EXCLUDED.last_updated,
        payload = EXCLUDED.payload,
        extracted_at = NOW()
'''

def connect_db():
    return psycopg2.connect(
        host=os.getenv("WAREHOUSE_HOST", "localhost"),
        port=os.getenv("WAREHOUSE_PORT", "5432"),
        dbname=os.getenv("WAREHOUSE_DB", "warehouse"),
        user=os.getenv("ETL_USER", "etl_user"),
        password=os.environ["ETL_PASSWORD"],
    )

def fetch_pages(resource_type, session):
    """Yield one page of resources at a time.

    Uses _offset paging sorted by _id instead of following 'next' links:
    HAPI's cached-search paging stops after 3,000 results (the 'next' link
    disappears), while _offset runs a fresh query per page and reaches every row.
    """
    url = f"{FHIR_BASE_URL}/{resource_type}"
    offset = 0
    while True:
        params = {"_count": PAGE_SIZE, "_offset": offset, "_sort": "_id"}
        response = session.get(url, params=params, headers={"Accept": "application/fhir+json"}, timeout=300)
        response.raise_for_status()
        page = [entry["resource"] for entry in response.json().get("entry", []) if "resource" in entry]
        if not page:
            return
        yield page
        offset += len(page)

def extract_and_load():
    conn = connect_db()
    session = requests.Session()
    try:
        for resource_type in RESOURCE_TYPES:
            total = 0
            for page in fetch_pages(resource_type, session):
                if not page:
                    continue
                rows = [
                    (resource_type, r["id"], r.get("meta", {}).get("lastUpdated"), Json(r))
                    for r in page
                ]
                with conn, conn.cursor() as cur:  # commit each page
                    execute_values(cur, UPSERT_SQL, rows, page_size=len(rows))
                total += len(rows)
                if total % 10000 < len(rows):
                    print(f"{resource_type}: {total} loaded", flush=True)
            print(f"{resource_type}: {total} loaded (done)", flush=True)
        print("FHIR extraction and warehouse load completed.")
    finally:
        conn.close()

if __name__ == "__main__":
    extract_and_load()
