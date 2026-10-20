import Foundation
import ActivityKit
import AVFoundation

public class LiveScoreManager: ObservableObject {
    public static let shared = LiveScoreManager()
    
    @Published public private(set) var currentActivity: Activity<CricketMatchAttributes>?
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var statusText: String = "Idle"
    
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    public init() {}
    
    // MARK: - Country Flag Mapper
    
    private func flagForTeam(_ code: String) -> String {
        let clean = code.uppercased()
        if clean.contains("IND") { return "🇮🇳" }
        if clean.contains("ZIM") { return "🇿🇼" }
        if clean.contains("AUS") { return "🇦🇺" }
        if clean.contains("ENG") { return "🇬🇧" }
        if clean.contains("NZ") { return "🇳🇿" }
        if clean.contains("PAK") { return "🇵🇰" }
        if clean.contains("SA") { return "🇿🇦" }
        if clean.contains("SL") { return "🇱🇰" }
        if clean.contains("BAN") { return "🇧🇩" }
        if clean.contains("AFG") { return "🇦🇫" }
        if clean.contains("WI") { return "🏝️" }
        return "🏏"
    }
    
    // MARK: - Start Tracking
    
    public func startTrackingMatch(home: String, away: String, matchType: String) {
        let homeUpper = home.uppercased()
        let awayUpper = away.uppercased()
        
        guard homeUpper.contains("IND") || homeUpper.contains("INDIA") ||
              awayUpper.contains("IND") || awayUpper.contains("INDIA") else {
            self.statusText = "Refused: Non-India match"
            return
        }
        
        stopTracking()
        setupBackgroundKeepAlive()
        
        let attributes = CricketMatchAttributes(homeTeam: home, awayTeam: away, matchType: matchType)
        let homeFlag = flagForTeam(home)
        let awayFlag = flagForTeam(away)
        
        let initialContent = CricketMatchAttributes.ContentState(
            scoreString: "0/0",
            oversString: "(0.0)",
            currentRunRate: "CRR: 0.00",
            statusMessage: "Connecting to Cricbuzz...",
            homeTeam: home,
            awayTeam: away,
            homeFlag: homeFlag,
            awayFlag: awayFlag
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialContent, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
            self.isTracking = true
            self.statusText = "Tracking Live"
            
            fetchAndRefreshScore()
            timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.fetchAndRefreshScore()
            }
        } catch {
            self.statusText = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Live Score Polling from Cricbuzz
    
    private func fetchAndRefreshScore() {
        guard let url = URL(string: "https://www.cricbuzz.com/api/cricket-match/live-scores") else { return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self,
                  let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let typeMatches = json["typeMatches"] as? [[String: Any]] else { return }
            
            for category in typeMatches {
                for series in category["seriesMatches"] as? [[String: Any]] ?? [] {
                    let wrapper = series["seriesAdWrapper"] as? [String: Any] ?? [:]
                    for match in wrapper["matches"] as? [[String: Any]] ?? [] {
                        let info = match["matchInfo"] as? [String: Any] ?? [:]
                        let t1Raw = (info["team1"] as? [String: Any])?["teamSName"] as? String ?? ""
                        let t2Raw = (info["team2"] as? [String: Any])?["teamSName"] as? String ?? ""
                        let t1NameRaw = (info["team1"] as? [String: Any])?["teamName"] as? String ?? ""
                        let t2NameRaw = (info["team2"] as? [String: Any])?["teamName"] as? String ?? ""
                        
                        let t1 = t1Raw.uppercased()
                        let t2 = t2Raw.uppercased()
                        let t1Name = t1NameRaw.uppercased()
                        let t2Name = t2NameRaw.uppercased()
                        
                        let isIndia = t1.contains("IND") || t2.contains("IND") ||
                                      t1Name.contains("IND") || t2Name.contains("IND")
                        
                        if isIndia {
                            let scores = match["matchScore"] as? [String: Any] ?? [:]
                            let s1 = scores["team1Score"] as? [String: Any]
                            let s2 = scores["team2Score"] as? [String: Any]
                            
                            let s1Inngs = (s1?["inngs2"] as? [String: Any]) ?? (s1?["inngs1"] as? [String: Any])
                            let s2Inngs = (s2?["inngs2"] as? [String: Any]) ?? (s2?["inngs1"] as? [String: Any])
                            
                            let inngs = s2Inngs ?? s1Inngs ?? [:]
                            
                            let runs = inngs["runs"] as? Int ?? 0
                            let wickets = inngs["wickets"] as? Int ?? 0
                            let overs = inngs["overs"] as? Double ?? 0.0
                            let status = info["status"] as? String ?? "Match Live"
                            let crr = overs > 0 ? String(format: "CRR: %.2f", Double(runs) / overs) : "CRR: 0.00"
                            
                            var scoreText = "\(runs)/\(wickets)"
                            if let teamScore = (s2Inngs != nil ? s2 : s1) {
                                if let firstInngs = teamScore["inngs1"] as? [String: Any],
                                   teamScore["inngs2"] != nil {
                                    let r1 = firstInngs["runs"] as? Int ?? 0
                                    scoreText = "\(r1) & \(runs)/\(wickets)"
                                }
                            }
                            
                            let displayT1 = t1Raw.isEmpty ? "IND" : t1Raw
                            let displayT2 = t2Raw.isEmpty ? "OPP" : t2Raw
                            
                            let newState = CricketMatchAttributes.ContentState(
                                scoreString: scoreText,
                                oversString: "(\(overs))",
                                currentRunRate: crr,
                                statusMessage: status,
                                homeTeam: displayT1,
                                awayTeam: displayT2,
                                homeFlag: self.flagForTeam(displayT1),
                                awayFlag: self.flagForTeam(displayT2)
                            )
                            
                            Task {
                                await self.currentActivity?.update(ActivityContent(state: newState, staleDate: nil))
                            }
                            return
                        }
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Background Audio Keep-Alive
    
    private func setupBackgroundKeepAlive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    public func stopTracking() {
        timer?.invalidate()
        timer = nil
        Task {
            for activity in Activity<CricketMatchAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        isTracking = false
        statusText = "Idle"
    }
}
