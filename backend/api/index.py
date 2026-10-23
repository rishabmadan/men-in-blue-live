from http.server import BaseHTTPRequestHandler
import json
import urllib.request
import ssl
import re
import time


def fetch_live_cricket_match() -> dict:
    ctx = ssl._create_unverified_context()
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }

    # Live sources for today (Vadodara ODI & live feeds)
    sources = [
        "https://timesofindia.indiatimes.com/sports/cricket/india-women-vs-zimbabwe-women-1st-odi-2026-live-score-cricket-match-today-scorecard-smriti-mandhana/liveblog/135139627.cms",
        "https://sports.ndtv.com/cricket/live-scores",
        "https://indianexpress.com/section/sports/cricket/live-score/"
    ]

    for url in sources:
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, context=ctx, timeout=3.5) as resp:
                raw_html = resp.read().decode("utf-8", errors="ignore")
                
                clean = re.sub(r'<[^>]+>', ' ', raw_html)
                clean = re.sub(r'\s+', ' ', clean)

                # Match India Women vs Zimbabwe Women or any active India match
                # Matches: "Zimbabwe Women 4/0 (0.5 ov)" or "ZIM-W 12/0 (2.0)"
                pattern = r'\b(Zimbabwe(?:\s*Women)?|ZIM-?W|India(?:\s*Women)?|IND-?W|NZ|New Zealand)\b\s*[:\-]?\s*(\d+/\d+|\d+)\s*\(([\d\.]+)(?:\s*ov)?\)'
                matches = re.findall(pattern, clean, re.I)

                if matches:
                    active = matches[-1]
                    team_raw = active[0].upper()
                    
                    if "ZIM" in team_raw:
                        batting_team = "ZIM-W"
                        opponent = "ZIM-W"
                        home_team = "IND-W"
                    elif "IND" in team_raw:
                        batting_team = "IND-W"
                        opponent = "ZIM-W"
                        home_team = "IND-W"
                    elif "NEW" in team_raw or "NZ" in team_raw:
                        batting_team = "NZ"
                        opponent = "NZ"
                        home_team = "IND"
                    else:
                        batting_team = team_raw
                        opponent = "OPP"
                        home_team = "IND"

                    score = active[1]
                    if '/' not in score:
                        score = f"{score}/0"
                    overs = active[2].strip()

                    runs = int(score.split('/')[0])
                    overs_float = float(overs) if overs and float(overs) > 0 else 1.0
                    crr = round(runs / overs_float, 2)

                    return {
                        "home_team_short": home_team,
                        "away_team_short": opponent,
                        "live_score_runs_wickets": f"{batting_team} {score}",
                        "live_overs": f"({overs} ov)",
                        "current_run_rate": f"CRR: {crr}",
                        "live_status_string": "1st ODI • Vadodara (ZIM-W bat first)"
                    }
        except Exception as e:
            print(f"[Scrape Error: {url}] {e}")

    # Fallback for 1st ODI Vadodara (Match starting right now)
    return {
        "home_team_short": "IND-W",
        "away_team_short": "ZIM-W",
        "live_score_runs_wickets": "ZIM-W 0/0",
        "live_overs": "(0.0 ov)",
        "current_run_rate": "CRR: 0.00",
        "live_status_string": "1st ODI • Vadodara (ZIM-W bat first)"
    }


# MARK: - Vercel Handler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.end_headers()

        match = fetch_live_cricket_match()

        response_payload = {
            "status": "success",
            "payload": {
                "aps": {
                    "content-state": {
                        "scoreString": match.get("live_score_runs_wickets", "0/0"),
                        "oversString": match.get("live_overs", ""),
                        "currentRunRate": match.get("current_run_rate", "CRR: 0.00"),
                        "statusMessage": match.get("live_status_string", "Match Live"),
                        "homeTeam": match.get("home_team_short", "IND-W"),
                        "awayTeam": match.get("away_team_short", "ZIM-W")
                    }
                }
            }
        }

        self.wfile.write(json.dumps(response_payload).encode("utf-8"))
        return
