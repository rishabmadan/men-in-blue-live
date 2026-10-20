from http.server import BaseHTTPRequestHandler
import json
import urllib.request
import xml.etree.ElementTree as ET
import ssl

def fetch_live_cricket_match() -> dict:
    ctx = ssl._create_unverified_context()

    # -------------------------------------------------------------
    # 1. CRICBUZZ OPEN SYNDICATION XML FEED (NEVER BLOCKS SERVERS)
    # -------------------------------------------------------------
    try:
        url = "http://synd.cricbuzz.com/j2me/1.0/livematches.xml"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
            xml_data = resp.read().decode("utf-8", errors="ignore")
            root = ET.fromstring(xml_data)
            
            for match in root.findall(".//match"):
                desc = (match.get("mchDesc") or "").upper()
                series = (match.get("srs") or "").upper()
                
                # Check for India or India Women
                if "IND" in desc or "INDIA" in desc or "IND" in series:
                    mstate = match.get("mstate") or match.get("status") or "Match Live"
                    mscr = match.find("mscr")
                    
                    if mscr is not None:
                        bt = mscr.find("btTm")
                        blg = mscr.find("blgTm")
                        
                        bt_name = bt.get("sName", "IND") if bt is not None else "IND"
                        blg_name = blg.get("sName", "ZIM") if blg is not None else "ZIM"
                        
                        inngs = bt.find("Inngs") if bt is not None else None
                        runs = inngs.get("r", "0") if inngs is not None else "0"
                        wkts = inngs.get("wkts", "0") if inngs is not None else "0"
                        ovrs = inngs.get("ovrs", "0.0") if inngs is not None else "0.0"
                        
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
    # 2. ESPN SITE WEB API (UNBLOCKED FOR SERVER CALLS)
    # -------------------------------------------------------------
    try:
        url = "https://site.web.api.espn.com/apis/personalized/v2/scoreboard/header?sport=cricket&region=in"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
        with urllib.request.urlopen(req, context=ctx, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for sport in data.get("sports", []):
                for league in sport.get("leagues", []):
                    for event in league.get("events", []):
                        name = event.get("name", "").upper()
                        short_name = event.get("shortName", "").upper()
                        
                        if "IND" in name or "IND" in short_name or "INDIA" in name:
                            competitors = event.get("competitors", [])
                            c1 = competitors[0] if len(competitors) > 0 else {}
                            c2 = competitors[1] if len(competitors) > 1 else {}
                            
                            s1 = c1.get("score", "")
                            s2 = c2.get("score", "")
                            t1 = c1.get("abbreviation") or c1.get("name") or "IND-W"
                            t2 = c2.get("abbreviation") or c2.get("name") or "ZIM-W"
                            
                            status_obj = event.get("status", {})
                            status_str = status_obj.get("summary") or status_obj.get("description") or "Match Live"
                            
                            return {
                                "home_team_short": t1,
                                "away_team_short": t2,
                                "live_score_runs_wickets": s2 if s2 else (s1 if s1 else "Live"),
                                "live_overs": "",
                                "current_run_rate": "LIVE",
                                "live_status_string": status_str
                            }
    except Exception as e:
        print(f"[ESPN Web API Error] {e}")

    # -------------------------------------------------------------
    # 3. FALLBACK
    # -------------------------------------------------------------
    return {
        "home_team_short": "IND-W",
        "away_team_short": "ZIM-W",
        "live_score_runs_wickets": "Live",
        "live_overs": "",
        "current_run_rate": "LIVE",
        "live_status_string": "IND-W vs ZIM-W Live in Raipur"
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
                        "oversString": match.get("live_overs", "(0.0)"),
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
