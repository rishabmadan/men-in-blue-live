from http.server import BaseHTTPRequestHandler
import json
import urllib.request
import ssl
import gzip


def fetch_live_cricket_match() -> dict:
    ctx = ssl._create_unverified_context()
    headers = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
        "Accept": "application/json",
        "Accept-Encoding": "gzip"
    }

    # 1. ESPN Direct Scoreboard API (Fast, CDN-cached, unblocked)
    endpoints = [
        "https://site.api.espn.com/apis/personalized/v2/scoreboard/header?sport=cricket&region=in",
        "https://site.web.api.espn.com/apis/personalized/v2/scoreboard/header?sport=cricket&region=in"
    ]

    for url in endpoints:
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, context=ctx, timeout=3.0) as resp:
                raw = resp.read()
                if resp.info().get('Content-Encoding') == 'gzip':
                    raw = gzip.decompress(raw)
                
                data = json.loads(raw.decode("utf-8", errors="ignore"))

                for sport in data.get("sports", []):
                    for league in sport.get("leagues", []):
                        for event in league.get("events", []):
                            name = event.get("name", "").upper()
                            short_name = event.get("shortName", "").upper()

                            # Match India
                            if "IND" in name or "IND" in short_name or "INDIA" in name:
                                competitors = event.get("competitors", [])
                                if len(competitors) >= 2:
                                    c1, c2 = competitors[0], competitors[1]
                                    t1 = c1.get("abbreviation") or "NZ"
                                    t2 = c2.get("abbreviation") or "IND"

                                    s1 = c1.get("score") or ""
                                    s2 = c2.get("score") or ""
                                    active_score = s1 if s1 else (s2 if s2 else "0/0")

                                    status_obj = event.get("status", {})
                                    status_str = status_obj.get("summary") or status_obj.get("description") or "Match Live"

                                    return {
                                        "home_team_short": t1,
                                        "away_team_short": t2,
                                        "live_score_runs_wickets": active_score,
                                        "live_overs": "",
                                        "current_run_rate": "LIVE",
                                        "live_status_string": status_str
                                    }
        except Exception as e:
            print(f"[Scoreboard Fetch Error] {e}")

    # Fallback if match hasn't started or API is quiet
    return {
        "home_team_short": "IND",
        "away_team_short": "NZ",
        "live_score_runs_wickets": "0/0",
        "live_overs": "(0.0)",
        "current_run_rate": "CRR: 0.00",
        "live_status_string": "IND vs NZ • Match Underway"
    }


# MARK: - Vercel Handler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        match = fetch_live_cricket_match()

        response_payload = {
            "status": "success",
            "payload": {
                "aps": {
                    "content-state": {
                        "scoreString": match.get("live_score_runs_wickets", "0/0"),
                        "oversString": match.get("live_overs", ""),
                        "currentRunRate": match.get("current_run_rate", "LIVE"),
                        "statusMessage": match.get("live_status_string", "Match Live"),
                        "homeTeam": match.get("home_team_short", "IND"),
                        "awayTeam": match.get("away_team_short", "NZ")
                    }
                }
            }
        }

        self.wfile.write(json.dumps(response_payload).encode("utf-8"))
        return
