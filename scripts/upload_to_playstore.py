"""
Google Play Developer API - Automated Internal Testing Uploader
Usage:
  python scripts/upload_to_playstore.py

Prerequisites:
  pip install google-api-python-client google-auth-httplib2 google-auth
"""

import os
import sys
import subprocess
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = "com.avd_hsh.app"
TRACK = "internal"  # 'internal', 'alpha' (closed), 'beta', or 'production'
SERVICE_ACCOUNT_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "android",
    "play-service-account.json",
)
AAB_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "build",
    "app",
    "outputs",
    "bundle",
    "release",
    "app-release.aab",
)

def run_build():
    print("[1/4] 🔨 Building fresh Flutter App Bundle...")
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = subprocess.run(["flutter", "build", "appbundle"], cwd=root_dir, shell=True)
    if res.returncode != 0:
        print("❌ Flutter build failed! Aborting upload.")
        sys.exit(1)
    print("✅ Build completed successfully.")

def upload_bundle():
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        print(f"❌ Error: Service Account JSON not found at:\n   {SERVICE_ACCOUNT_FILE}")
        print("Please download your service account key from Google Cloud Console and place it there.")
        sys.exit(1)

    if not os.path.exists(AAB_PATH):
        print(f"❌ Error: AAB file not found at:\n   {AAB_PATH}")
        sys.exit(1)

    print(f"[2/4] 🔐 Authenticating with Google Play Developer API...")
    scopes = ["https://www.googleapis.com/auth/androidpublisher"]
    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=scopes
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    print(f"[3/4] 📦 Creating edit session for {PACKAGE_NAME}...")
    edit_request = service.edits().insert(body={}, packageName=PACKAGE_NAME)
    edit_result = edit_request.execute()
    edit_id = edit_result["id"]

    try:
        print(f"⬆️  Uploading {os.path.basename(AAB_PATH)}...")
        media = MediaFileUpload(
            AAB_PATH,
            mimetype="application/octet-stream",
            resumable=True,
            chunksize=1024 * 1024 * 8,
        )
        bundle_response = (
            service.edits()
            .bundles()
            .upload(packageName=PACKAGE_NAME, editId=edit_id, media_body=media)
            .execute()
        )
        version_code = bundle_response["versionCode"]
        print(f"✅ Uploaded successfully! Version code: {version_code}")

        print(f"[4/4] 🚀 Assigning bundle to track '{TRACK}'...")
        track_body = {
            "track": TRACK,
            "releases": [
                {
                    "versionCodes": [version_code],
                    "status": "completed",
                }
            ],
        }
        service.edits().tracks().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            track=TRACK,
            body=track_body,
        ).execute()

        print("💾 Committing release edit...")
        service.edits().commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
        print(f"🎉 Success! App version {version_code} is now live on Google Play '{TRACK}' track!")

    except Exception as e:
        print(f"❌ Error during upload: {e}")
        try:
            service.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
        except Exception:
            pass
        sys.exit(1)

if __name__ == "__main__":
    if "--no-build" not in sys.argv:
        run_build()
    upload_bundle()
