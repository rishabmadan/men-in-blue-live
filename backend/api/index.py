from http.server import BaseHTTPRequestHandler
import json
import urllib.request
import ssl
import re


def abbreviate_team(name: str) -> str:
    """Dynamically converts any international team name to its standard short code."""
    name_clean = name.strip()
    upper = name_clean.upper()
    is_women = "WOMEN" in upper or "-W" in upper

    base = upper.replace("WOMEN", "").replace("-W", "").strip()

    mapping = {
        "INDIA": "IND", "NEW ZEALAND": "NZ", "ZIMBABWE": "ZIM",
        "AUSTRALIA": "AUS", "ENGLAND": "ENG", "SOUTH AFRICA": "SA",
        "PAKISTAN": "PAK", "BANGLADESH": "BAN", "SRI LANKA": "SL",
        "AFGHANISTAN": "AFG", "WEST INDIES": "WI", "IRELAND": "IRE"
    }

    code = "OPP"
    for key, val in mapping.items():
        if key in base:
            code = val
            break
    if code == "OPP":
        words = base.split()
        code = "".join(w[0] for w in words)[:3].upper() if len(words) > 1 else base[:3].upper()

    return f"{code}-W" if is_women else code


def fetch_live_cricket_match() -> dict:
    ctx = ssl._create_unverified_context()
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }

    # Live score aggregation hubs (never hardcoded to a specific match)
    urls = [
        "https://sports.ndtv.com/cricket/live-scores",
        "https://indianexpress.com/section/sports/cricket/live-score/"
    ]

    for url in urls:
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, context=ctx, timeout=3.5) as resp:
                raw_html = resp.read().decode("utf-8", errors="ignore")
                clean = re.sub(r'<[^>]+>', ' ', raw_html)
                clean = re.sub(r'\s+', ' ', clean)

                # STRICT FILTER: Only inspect the "Live Score" section,
                # completely cutting off "Recent Cricket Scores" (yesterday's matches)
                live_text = ""
                if "Live Score" in clean:
                    sub = clean[clean.find("Live Score"):]
                    parts = re.split(r'Recent\s+Cricket\s+Scores|Upcoming\s+Matches', sub, flags=re.I)
                    live_text = parts[0] if parts else sub
                else:
                    live_text = clean

                # Only proceed if an Indian team is actively listed in the LIVE section
                if not re.search(r'\b(India|IND|IND-W|INDW)\b', live_text, re.I):
                    continue

                # 1. Dynamically extract the fixture: "[Team A] vs [Team B]"
                fixture_match = re.search(
                    r'\b([A-Za-z\s\-]+?)\s+(?:vs|v)\s+([A-Za-z\s\-]+?)(?:,|\bMatch|\b1st|\b2nd|\b3rd|\b4th|\b5th|\bODI|\bT20|\bTest)',
                    live_text,
                    re.I
                )

                team1_name = "India"
                team2_name = "Opponent"
                if fixture_match:
                    t1, t2 = fixture_match.group(1).strip(), fixture_match.group(2).strip()
                    if "IND" in t1.upper() or "INDIA" in t1.upper():
                        team1_name, team2_name = t1, t2
                    else:
                        team1_name, team2_name = t2, t1

                home_code = abbreviate_team(team1_name)
                away_code = abbreviate_team(team2_name)

                # 2. Extract scores from the live block
                score_pattern = r'\b([A-Za-z\s\-]+?)\s*[:\-]?\s*(\d+/\d+|\d+)\s*\(([\d\.]+)(?:\s*ov)?\)'
                scores = re.findall(score_pattern, live_text, re.I)

                # Match scores to our two active teams
                valid_scores = []
                for s in scores:
                    t_str = s[0].upper()
                    if any(k in t_str for k in [home_code, away_code, "INDIA", "IND", team2_name.upper()[:4]]):
                        valid_scores.append(s)

                if valid_scores:
                    latest = valid_scores[-1]
                    batting_raw = latest[0].strip()
                    batting_code = abbreviate_team(batting_raw)
                    score_val = latest[1]
                    if '/' not in score_val:
                        score_val = f"{score_val}/0"
                    overs_val = latest[2].strip()

                    runs = int(score_val.split('/')[0])
                    overs_float = float(overs_val) if overs_val and float(overs_val) > 0 else 1.0
                    crr = round(runs / overs_float, 2)

                    return {
                        "home_team_short": home_code,
                        "away_team_short": away_code,
                        "live_score_runs_wickets": f"{batting_code} {score_val}",
                        "live_overs": f"({overs_val} ov)",
                        "current_run_rate": f"CRR: {crr}",
                        "live_status_string": f"{home_code} vs {away_code} • Live"
                    }
                else:
                    # Match toss / start announced, but 0 balls bowled yet
                    return {
                        "home_team_short": home_code,
                        "away_team_short": away_code,
                        "live_score_runs_wickets": f"{away_code} 0/0",
                        "live_overs": "(0.0 ov)",
                        "current_run_rate": "CRR: 0.00",
                        "live_status_string": f"{home_code} vs {away_code} • Match Starting"
                    }
        except Exception as e:
            print(f"[Scrape Error: {url}] {e}")

    # Completely idle state when no Indian match is live
    return {
        "home_team_short": "IND",
        "away_team_short": "OFF",
        "live_score_runs_wickets": "Off Field",
        "live_overs": "",
        "current_run_rate": "CRR: 0.00",
        "live_status_string": "No Live India Match"
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
                        "homeTeam": match.get("home_team_short", "IND"),
                        "awayTeam": match.get("away_team_short", "OPP")
                    }
                }
            }
        }

        self.wfile.write(json.dumps(response_payload).encode("utf-8"))
        return
