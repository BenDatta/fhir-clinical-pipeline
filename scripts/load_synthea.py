"""Upload Synthea FHIR bundles to the HAPI FHIR server.

Order matters: hospitalInformation*.json and practitionerInformation*.json
(Organizations, Locations, Practitioners) must go first because every patient
bundle references them. Patient bundles are then sent in parallel.

Synthea patient bundles use POST, so uploading the same file twice creates
duplicates. Each successfully uploaded file is recorded in a progress file and
skipped on re-runs, so it is safe to stop and restart.

Usage:
    python3 scripts/load_synthea.py                       # data/synthea/*/fhir
    python3 scripts/load_synthea.py --workers 6
    python3 scripts/load_synthea.py --dirs data/synthea/alive/fhir
"""
import argparse
import glob
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.getenv("FHIR_BASE_URL", "http://localhost:8090/fhir")
PROGRESS_FILE = os.path.join(ROOT, "data", "synthea", ".uploaded.txt")
SHARED_PREFIXES = ("hospitalInformation", "practitionerInformation")

lock = Lock()


def post_bundle(path, retries=3):
    with open(path, "rb") as fh:
        body = fh.read()
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(
            BASE, data=body, method="POST",
            headers={"Content-Type": "application/fhir+json", "Accept": "application/fhir+json",
                     "Prefer": "return=minimal"},
        )
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                resp.read()
                return
        except urllib.error.HTTPError as err:
            detail = err.read().decode("utf-8", "replace")[:500]
            if err.code < 500 or attempt == retries:
                raise RuntimeError(f"HTTP {err.code}: {detail}") from None
        except (urllib.error.URLError, TimeoutError) as err:
            if attempt == retries:
                raise RuntimeError(str(err)) from None
        time.sleep(5 * attempt)


def mark_done(path):
    with lock, open(PROGRESS_FILE, "a") as fh:
        fh.write(os.path.relpath(path, ROOT) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dirs", nargs="+", default=sorted(glob.glob(os.path.join(ROOT, "data", "synthea", "*", "fhir"))))
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()

    done = set()
    if os.path.exists(PROGRESS_FILE):
        done = {line.strip() for line in open(PROGRESS_FILE) if line.strip()}

    shared, patients = [], []
    for d in args.dirs:
        for path in sorted(glob.glob(os.path.join(d, "*.json"))):
            (shared if os.path.basename(path).startswith(SHARED_PREFIXES) else patients).append(path)
    # hospitals before practitioners (practitioner roles reference organizations)
    shared.sort(key=lambda p: (not os.path.basename(p).startswith("hospital"), p))

    pending_shared = [p for p in shared if os.path.relpath(p, ROOT) not in done]
    pending = [p for p in patients if os.path.relpath(p, ROOT) not in done]
    print(f"Shared files: {len(shared)} ({len(pending_shared)} to upload); "
          f"patient bundles: {len(patients)} ({len(pending)} to upload)", flush=True)

    for path in pending_shared:
        print(f"Uploading {os.path.relpath(path, ROOT)} ...", flush=True)
        post_bundle(path)
        mark_done(path)

    failures = []
    start = time.time()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(post_bundle, p): p for p in pending}
        for i, fut in enumerate(as_completed(futures), 1):
            path = futures[fut]
            try:
                fut.result()
                mark_done(path)
            except Exception as exc:  # keep going; report at the end
                failures.append((path, str(exc)))
                print(f"FAILED {os.path.basename(path)}: {exc}", flush=True)
            if i % 25 == 0 or i == len(pending):
                rate = i / (time.time() - start)
                eta = (len(pending) - i) / rate / 60 if rate else 0
                print(f"{i}/{len(pending)} patient bundles, {rate:.2f}/s, ~{eta:.0f} min left", flush=True)

    if failures:
        print(f"\n{len(failures)} bundle(s) failed; re-run the script to retry them.")
        sys.exit(1)
    print("All Synthea bundles uploaded.")


if __name__ == "__main__":
    main()
