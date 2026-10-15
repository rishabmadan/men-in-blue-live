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
    Fetches raw live match metrics from upstream cricket provider.
    Falls back to mock live Indian match data if API key is not configured.
    """
    rapidapi_key = os.getenv("CRICKET_API_KEY", "")
    rapidapi_host = os.getenv("CRICKET_API_HOST", "cricket-live-data.p.rapidapi.com")
    
    if rapidapi_key:
        try:
            headers = {
                "X-RapidAPI-Key": rapidapi_key,
                "X-RapidAPI-Host": rapidapi_host
            }
            # Upstream match polling
            with httpx.Client(timeout=6.0) as client:
                res = client.get(f"https://{rapidapi_host}/match/current", headers=headers)
                if res.status_code == 200:
                    data = res.json()
                    return data.get("results", {}).get("current_match", {})
        except Exception as e:
            print(f"[Upstream API Error] Polling failed: {e}. Falling back to default feed.")
            
    # Mock data strictly matching Indian National Cricket Team fixture
    return {
        "home_team_short": "IND",
        "home_team_name": "India",
        "away_team_short": "AUS",
        "away_team_name": "Australia",
        "live_score_runs_wickets": "184/4",
        "live_overs": "18.2",
        "current_run_rate": "10.04",
        "live_status_string": "IND needs 14 off 10 balls"
    }

# MARK: - Unified Handler Entry Point

def handler(event, context=None):
    """
    Vercel / AWS Lambda compatible serverless handler.
    Exposes:
      - POST /api/register-token
      - GET  /api/cron-update
    """
    # Normalize path and method across Vercel / API Gateway events
    path = event.get("path") or event.get("rawPath") or ""
    method = (event.get("httpMethod") or event.get("requestContext", {}).get("http", {}).get("method") or "GET").upper()
    
    # -------------------------------------------------------------
    # ROUTE 1: REGISTER EPHEMERAL PUSH TOKEN FROM IPHONE
    # -------------------------------------------------------------
    if "/api/register-token" in path and method == "POST":
        try:
            raw_body = event.get("body", "{}")
            if isinstance(raw_body, str):
                body = json.loads(raw_body) if raw_body else {}
            else:
                body = raw_body
                
            token = body.get("token")
            activity_id = body.get("activityId")
            
            if not token or not activity_id:
                return {
                    "statusCode": 400,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"error": "Missing required fields: token and activityId"})
                }
                
            save_token(token=token, activity_id=activity_id)
            print(f"[Registration] Stored APNs token for Activity ID: {activity_id}")
            
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "status": "Token saved securely",
                    "activityId": activity_id
                })
            }
        except Exception as e:
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": f"Failed to register token: {str(e)}"})
            }

    # -------------------------------------------------------------
    # ROUTE 2: CRON CRICKET FETCH & APNS DELIVERY
    # -------------------------------------------------------------
    elif "/api/cron-update" in path:
        device = get_active_token()
        if not device:
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"status": "No registered token targets found in datastore."})
            }
            
        match = fetch_live_cricket_match()
        
        home_short = str(match.get("home_team_short", "")).upper()
        home_name = str(match.get("home_team_name", "")).upper()
        away_short = str(match.get("away_team_short", "")).upper()
        away_name = str(match.get("away_team_name", "")).upper()
        
        # STRICT BACKEND FILTER: Refuse non-India fixtures
        matches_india = (
            "IND" in home_short or "INDIA" in home_name or "IND" in home_name or
            "IND" in away_short or "INDIA" in away_name or "IND" in away_name
        )
        
        if not matches_india:
            print(f"[Strict Filter] Fixture '{home_short}' vs '{away_short}' does not involve India. Aborting push.")
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "status": "Filtered: India is not active in this fixture. APNs delivery aborted."
                })
            }
            
        # Build Apple-Compliant Live Activity Push Data Schema
        apns_payload = {
            "aps": {
                "timestamp": int(time.time()),
                "event": "update",
                "content-state": {
                    "scoreString": match.get("live_score_runs_wickets", "0/0"),
                    "oversString": f"({match.get('live_overs', '0')})",
                    "currentRunRate": f"CRR: {match.get('current_run_rate', '0.00')}",
                    "statusMessage": match.get("live_status_string", "Match Live")
                }
            }
        }
        
        # Environment Config
        team_id = os.getenv("APPLE_TEAM_ID", "")
        key_id = os.getenv("APPLE_KEY_ID", "")
        p8_private_key = os.getenv("APPLE_P8_KEY", "")
        bundle_id = os.getenv("IOS_BUNDLE_ID", "com.meninblue.live")
        apns_env = os.getenv("APNS_ENVIRONMENT", "sandbox").lower()
        
        # Select Apple APNs Endpoint
        apns_base = (
            "https://api.sandbox.push.apple.com" 
            if apns_env == "sandbox" 
            else "https://api.push.apple.com"
        )
        device_token = device["token"]
        apns_url = f"{apns_base}/3/device/{device_token}"
        
        # Check authentication credentials
        if not (team_id and key_id and p8_private_key):
            # Development dry-run mode when Apple Developer credentials are not yet injected
            print("[Dev Warning] APNs credentials not configured in env. Dry run payload compiled:")
            print(json.dumps(apns_payload, indent=2))
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "status": "Dry-run successful (Missing APPLE_TEAM_ID, KEY_ID, or APPLE_P8_KEY)",
                    "payload": apns_payload
                })
            }
            
        try:
            apns_jwt = generate_apns_jwt(team_id, key_id, p8_private_key)
            
            headers = {
                "authorization": f"bearer {apns_jwt}",
                "apns-topic": f"{bundle_id}.push-type.liveactivity",
                "apns-push-type": "liveactivity",
                "apns-priority": "10"
            }
            
            # Apple APNs requires true HTTP/2 multiplexed TLS socket
            with httpx.Client(http2=True, timeout=8.0) as client:
                response = client.post(
                    apns_url,
                    json=apns_payload,
                    headers=headers
                )
                
            if response.status_code == 200:
                print(f"[APNs] Live Activity updated successfully for device: {device_token[:8]}...")
                return {
                    "statusCode": 200,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"status": "APNs update broadcasted successfully", "code": 200})
                }
            else:
                print(f"[APNs Error] Apple returned {response.status_code}: {response.text}")
                return {
                    "statusCode": response.status_code,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({
                        "error": "APNs delivery rejected by Apple",
                        "code": response.status_code,
                        "details": response.text
                    })
                }
                
        except Exception as e:
            print(f"[APNs Exception] Pipeline failed: {str(e)}")
            return {
                "statusCode": 500,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": f"Pipeline failure: {str(e)}"})
            }
            
    # Unmapped Route
    return {
        "statusCode": 404,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": f"Route not mapped: {method} {path}"})
    }
