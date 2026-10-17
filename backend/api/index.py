import os
import json
import time
import re
from typing import Dict, Any, Optional

try:
    import jwt  # PyJWT library with cryptography backend
except ImportError:
    jwt = None

try:
    import httpx  # Required for HTTP/2 transmission to Apple APNs
except ImportError:
    httpx = None

# MARK: - In-Memory Datastore Fallback
# In production, swap with Supabase, Redis, or PostgreSQL connection
TOKEN_STORE: Dict[str, Dict[str, Any]] = {}

def get_db_connection():
    """Optional database connection helper for Supabase / PostgreSQL."""
    db_url = os.getenv("DATABASE_URL")
    if db_url:
        try:
            import psycopg2
            return psycopg2.connect(db_url)
        except Exception:
            return None
    return None

def save_token(token: str, activity_id: str) -> None:
    """Saves device push token and activity ID into datastore."""
    TOKEN_STORE["active_device"] = {
        "token": token,
        "activityId": activity_id,
        "updated_at": int(time.time())
    }
    
    # If Supabase/PostgreSQL is connected, persist token
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO active_trackers (token, activity_id, updated_at)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (activity_id) DO UPDATE
                    SET token = EXCLUDED.token, updated_at = EXCLUDED.updated_at;
                """, (token, activity_id, int(time.time())))
                conn.commit()
            conn.close()
        except Exception as e:
            print(f"[Database Error] Failed to persist token to PostgreSQL: {e}")

def get_active_token() -> Optional[Dict[str, Any]]:
    """Retrieves active device token from database or fallback memory store."""
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT token, activity_id FROM active_trackers ORDER BY updated_at DESC LIMIT 1;")
                row = cur.fetchone()
                if row:
                    conn.close()
                    return {"token": row[0], "activityId": row[1]}
            conn.close()
        except Exception as e:
            print(f"[Database Error] Fallback to in-memory store: {e}")
            
    return TOKEN_STORE.get("active_device")

def generate_apns_jwt(team_id: str, key_id: str, private_key_pem: str) -> str:
    """Generates an Apple APNs compliant ES256 JWT bearer token."""
    if not jwt:
        raise RuntimeError("PyJWT library is missing. Install requirements: pip install pyjwt cryptography")
    
    # Normalize private key string (handling escaped newlines in environment variables)
    clean_key = private_key_pem.replace("\\n", "\n").strip()
    if not clean_key.startswith("-----BEGIN"):
        clean_key = f"-----BEGIN PRIVATE KEY-----\n{clean_key}\n-----END PRIVATE KEY-----"
        
    token_headers = {
        "alg": "ES256",
        "kid": key_id
    }
    token_claims = {
        "iss": team_id,
        "iat": int(time.time())
    }
    
    return jwt.encode(token_claims, clean_key, algorithm="ES256", headers=token_headers)

def fetch_live_cricket_match() -> Dict[str, Any]:
    """
    Fetches real-time scores directly from Cricbuzz.
    Supports T20, ODI, and multi-innings Test matches with zero API keys and no rate limits.
    """
    url = "https://www.cricbuzz.com/api/cricket-match/live-scores"
    headers = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    }
    
    try:
        if httpx:
            with httpx.Client(timeout=8.0) as client:
                res = client.get(url, headers=headers)
                if res.status_code == 200:
                    data = res.json()
                    
                    # Scan match categories for India
                    for match_category in data.get("typeMatches", []):
                        for series in match_category.get("seriesMatches", []):
