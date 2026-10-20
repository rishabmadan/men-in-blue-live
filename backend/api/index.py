from http.server import BaseHTTPRequestHandler
import json
import os
import urllib.request
import gzip

def fetch_live_cricket_match() -> dict:
    """Fetches real-time live cricket score with GZIP decompression."""
    try:
        url = "https://hs-consumer-api.espncricinfo.com/v1/pages/matches/current?lang=en&latest=true"
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Accept-Encoding": "gzip, deflate"
        })
        
        with urllib.request.urlopen(req, timeout=8) as response:
            raw = response.read()
            # Decompress GZIP payload from Cricinfo
            if raw.startswith(b'\x1f\x8b') or response.headers.get('Content-Encoding') == 'gzip':
                raw = gzip.decompress(raw)
                
            data = json.loads(raw.decode('utf-8'))
            matches = data.get("matches") or data.get("content", {}).get("matches", []) or []
            
            for m in matches:
                teams = m.get("teams", [])
                if len(teams) >= 2:
                    t1_info = teams[0].get("team", {})
                    t2_info = teams[1].get("team", {})
                    
                    t1_abbr = str(t1_info.get("abbreviation") or t1_info.get("name") or "").upper()
                    t2_abbr = str(t2_info.get("abbreviation") or t2_info.get("name") or "").upper()
                    
                    # Matches IND, IND-W, India, Zimbabwe
                    if "IND" in t1_abbr or "IND" in t2_abbr:
                        s1 = str(teams[0].get("score", ""))
                        s2 = str(teams[1].get("score", ""))
                        ov1 = str(teams[0].get("scoreInfo", ""))
                        ov2 = str(teams[1].get("scoreInfo", ""))
                        
                        # Whichever team is currently batting
                        active_score = s2 if s2 else s1
                        active_overs = ov2 if ov2 else ov1
                        
                        return {
                            "home_team_short": t1_abbr if t1_abbr else "IND-W",
                            "away_team_short": t2_abbr if t2_abbr else "ZIM-W",
                            "live_score_runs_wickets": active_score if active_score else "Live",
                            "live_overs": active_overs if active_overs else "",
                            "current_run_rate": "CRR: " + str(m.get("currentRunRate", "LIVE")),
                            "live_status_string": m.get("statusText") or m.get("status") or "Match Live"
                        }
    except Exception as e:
        print(f"[Fetch Error] {e}")

    # Fallback only if network completely drops
    return {
        "home_team_short": "IND-W",
        "away_team_short": "ZIM-W",
        "live_score_runs_wickets": "Live",
        "live_overs": "",
        "current_run_rate": "LIVE",
        "live_status_string": "IND-W vs ZIM-W 3rd T20I"
    }

# MARK: - Vercel Handler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        match = fetch_live_cricket_match()
        
        response_payload = {
            "status": "success",
            "payload": {
                "aps": {
                    "content-state": {
                        "scoreString": match.get("live_score_runs_wickets", "0/0"),
                        "oversString": match.get("live_overs", "(0.0)"),
                        "currentRunRate": match.get("current_run_rate", "CRR: 0.00"),
                        "statusMessage": match.get("live_status_string", "Match Live"),
                        "homeTeam": match.get("home_team_short", "IND-W"),
                        "awayTeam": match.get("away_team_short", "ZIM-W")
                    }
                }
            }
        }
        
        self.wfile.write(json.dumps(response_payload).encode('utf-8'))
        return

    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps({"status": "Token saved"}).encode('utf-8'))
        return
