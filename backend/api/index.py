from http.server import BaseHTTPRequestHandler
import json
import time
import urllib.request
import xml.etree.ElementTree as ET
import ssl


def fetch_simulated_live_cricket_match() -> dict:
    now = int(time.time())
    balls = (now // 15) % 120  # Advances 1 ball every 15s
    overs = f"{balls // 6}.{balls % 6}"
    runs = 45 + int(balls * 1.4)
    wickets = min(balls // 25, 9)
    crr = round(runs / max(float(balls) / 6.0, 0.1), 2)

    return {
        "home_team_short": "IND",
        "away_team_short": "NZ",
        "live_score_runs_wickets": f"{runs}/{wickets}",
        "live_overs": f"({overs})",
        "current_run_rate": f"CRR: {crr}",
        "live_status_string": "Live Test Mode • Ticking"
    }


def fetch_live_cricket_match() -> dict:
    ctx = ssl._create_unverified_context()

    # -------------------------------------------------------------
    # 1. CRICBUZZ OPEN SYNDICATION XML FEED
    # -------------------------------------------------------------
    try:
        url = "http://synd.cricbuzz.com/j2me/1.0/livematches.xml"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
            xml_data = resp.read().decode("utf-8", errors="ignore")
            root = ET.fromstring(xml_data)

            # Pass 1: Look for India match. Pass 2: Look for ANY live match.
            for target_india in [True, False]:
                for match in root.findall(".//match"):
                    desc = (match.get("mchDesc") or "").upper()
                    series = (match.get("srs") or "").upper()
                    is_ind = "IND" in desc or "INDIA" in desc or "IND" in series

                    if target_india and not is_ind:
                        continue

                    mstate = match.get("mstate") or match.get("status") or "Match Live"
                    mscr = match.find("mscr")

                    if mscr is not None:
                        bt = mscr.find("btTm")
                        blg = mscr.find("blgTm")

                        bt_name = bt.get("sName", "BAT") if bt is not None else "BAT"
                        blg_name = blg.get("sName", "BOWL") if blg is not None else "BOWL"

                        inngs = bt.find("Inngs") if bt is not None else None
                        if inngs is not None and inngs.get("r"):
                            runs = inngs.get("r", "0")
                            wkts = inngs.get("wkts", "0")
                            ovrs = inngs.get("ovrs", "0.0")

                            return {
                                "home_team_short": bt_name,
                                "away_team_short": blg_name,
                                "live_score_runs_wickets": f"{runs}/{wkts}",
                                "live_overs": f"({ovrs} ov)",
                                "current_run_rate": "LIVE",
                                "live_status_string": mstate
                            }
    except Exception as e:
        print(f"[Cricbuzz XML Error] {e}")

    # -------------------------------------------------------------
    # 2. ESPN SITE WEB API
    # -------------------------------------------------------------
    try:
        url = "https://site.web.api.espn.com/apis/personalized/v2/scoreboard/header?sport=cricket&region=in"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
        with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for target_india in [True, False]:
                for sport in data.get("sports", []):
                    for league in sport.get("leagues", []):
                        for event in league.get("events", []):
                            name = event.get("name", "").upper()
                            short_name = event.get("shortName", "").upper()
                            is_ind = "IND" in name or "IND" in short_name or "INDIA" in name

                            if target_india and not is_ind:
                                continue

                            competitors = event.get("competitors", [])
                            if competitors:
                                c1 = competitors[0]
                                c2 = competitors[1] if len(competitors) > 1 else {}

                                s1 = c1.get("score", "")
                                s2 = c2.get("score", "")
                                score_val = s2 if s2 else (s1 if s1 else "")

                                if score_val:
                                    t1 = c1.get("abbreviation") or c1.get("name") or "TEAM1"
                                    t2 = c2.get("abbreviation") or c2.get("name") or "TEAM2"
                                    status_obj = event.get("status", {})
                                    status_str = status_obj.get("summary") or status_obj.get("description") or "Match Live"

                                    return {
                                        "home_team_short": t1,
                                        "away_team_short": t2,
                                        "live_score_runs_wickets": score_val,
                                        "live_overs": "",
                                        "current_run_rate": "LIVE",
                                        "live_status_string": status_str
                                    }
    except Exception as e:
        print(f"[ESPN Web API Error] {e}")

    # -------------------------------------------------------------
    # 3. FALLBACK TO TICKING SIMULATOR
    # -------------------------------------------------------------
    return fetch_simulated_live_cricket_match()


# MARK: - Vercel Handler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        query = self.path.lower()
        match = fetch_simulated_live_cricket_match() if "simulate" in query or "testing" in query else fetch_live_cricket_match()

        response_payload = {
            "status": "success",
            "payload": {
                "aps": {
                    "content-state": {
                        "scoreString": match.get("live_score_runs_wickets", "0/0"),
                        "oversString": match.get("live_overs", "(0.0)"),
                        "currentRunRate": match.get("current_run_rate", "CRR: 0.00"),
                        "statusMessage": match.get("live_status_string", "Match Live"),
                        "homeTeam": match.get("home_team_short", "IND"),
                        "awayTeam": match.get("away_team_short", "NZ")
                    }
                }
            }
        }

        self.wfile.write(json.dumps(response_payload).encode("utf-8"))
        return
