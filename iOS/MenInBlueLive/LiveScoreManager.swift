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
            statusMessage: "Fetching live match...",
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
            
            // Poll Cricinfo immediately, then every 30 seconds
            fetchAndRefreshScore()
            timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.fetchAndRefreshScore()
            }
        } catch {
            self.statusText = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Live Score Polling from ESPN Cricinfo (Open, Anti-Bot Free)
    
    private func fetchAndRefreshScore() {
        guard let url = URL(string: "https://hs-consumer-api.espncricinfo.com/v1/pages/matches/current?lang=en&latest=true") else { return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                self.updateLiveBannerStatus("Network Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let matches = json["matches"] as? [[String: Any]] else {
                self.updateLiveBannerStatus("Connecting...")
                return
            }
            
            for match in matches {
                guard let teams = match["teams"] as? [[String: Any]], teams.count >= 2 else { continue }
                
                let t1Info = teams[0]["team"] as? [String: Any] ?? [:]
                let t2Info = teams[1]["team"] as? [String: Any] ?? [:]
                
                let t1Abbr = (t1Info["abbreviation"] as? String ?? "").uppercased()
                let t2Abbr = (t2Info["abbreviation"] as? String ?? "").uppercased()
                let t1Name = (t1Info["name"] as? String ?? "").uppercased()
                let t2Name = (t2Info["name"] as? String ?? "").uppercased()
                
                // Matches IND, IND-W, India, India Women
                let isIndia = t1Abbr.contains("IND") || t2Abbr.contains("IND") ||
                              t1Name.contains("IND") || t2Name.contains("IND")
                
                if isIndia {
                    let status = match["statusText"] as? String ?? "Match Live"
                    
                    let t1Score = teams[0]["score"] as? String ?? ""
                    let t1Overs = teams[0]["scoreInfo"] as? String ?? ""
                    let t2Score = teams[1]["score"] as? String ?? ""
                    let t2Overs = teams[1]["scoreInfo"] as? String ?? ""
                    
                    // Display the active team's score
                    let activeScore = !t2Score.isEmpty ? t2Score : (!t1Score.isEmpty ? t1Score : "0/0")
                    let activeOvers = !t2Overs.isEmpty ? t2Overs : (!t1Overs.isEmpty ? t1Overs : "(0.0)")
                    
                    let displayT1 = (t1Info["abbreviation"] as? String) ?? "IND"
                    let displayT2 = (t2Info["abbreviation"] as? String) ?? "ZIM"
                    
                    let newState = CricketMatchAttributes.ContentState(
                        scoreString: activeScore,
                        oversString: activeOvers,
                        currentRunRate: "LIVE",
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
            
            self.updateLiveBannerStatus("No live India match right now")
        }.resume()
    }
    
    private func updateLiveBannerStatus(_ message: String) {
        Task {
            guard let current = self.currentActivity else { return }
            var state = current.content.state
            state.statusMessage = message
            await current.update(ActivityContent(state: state, staleDate: nil))
        }
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
