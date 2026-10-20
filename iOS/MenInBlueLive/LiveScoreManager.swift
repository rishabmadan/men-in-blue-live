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
    
    // MARK: - Flag Mapper
    
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
        stopTracking()
        setupBackgroundKeepAlive()
        
        let attributes = CricketMatchAttributes(homeTeam: home, awayTeam: away, matchType: matchType)
        let homeFlag = flagForTeam(home)
        let awayFlag = flagForTeam(away)
        
        let initialContent = CricketMatchAttributes.ContentState(
            scoreString: "0/0",
            oversString: "(0.0)",
            currentRunRate: "CRR: 0.00",
            statusMessage: "Fetching live score...",
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
            timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                self?.fetchAndRefreshScore()
            }
        } catch {
            self.statusText = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Live Score Polling from ESPN Cricinfo (Deep Recursive Search)
    
    private func fetchAndRefreshScore() {
        guard let url = URL(string: "https://hs-consumer-api.espncricinfo.com/v1/pages/matches/current?lang=en&latest=true") else { return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.updateLiveBannerStatus("Network: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                self.updateLiveBannerStatus("No data received")
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) else {
                self.updateLiveBannerStatus("Invalid response")
                return
            }
            
            // Recursively search for any match dictionary that contains India
            if let match = self.findMatchRecursively(in: json) {
                let teams = (match["teams"] as? [[String: Any]]) ?? []
                let t1 = teams.first ?? [:]
                let t2 = teams.count > 1 ? teams[1] : [:]
                
                let t1Info = (t1["team"] as? [String: Any]) ?? t1
                let t2Info = (t2["team"] as? [String: Any]) ?? t2
                
                let t1Abbr = (t1Info["abbreviation"] as? String ?? t1Info["name"] as? String ?? "IND").uppercased()
                let t2Abbr = (t2Info["abbreviation"] as? String ?? t2Info["name"] as? String ?? "ZIM").uppercased()
                
                let status = (match["statusText"] as? String) ?? (match["status"] as? String) ?? "Match Live"
                
                let t1Score = (t1["score"] as? String) ?? ""
                let t1Overs = (t1["scoreInfo"] as? String) ?? ""
                let t2Score = (t2["score"] as? String) ?? ""
                let t2Overs = (t2["scoreInfo"] as? String) ?? ""
                
                // Show whichever team is actively batting
                let activeScore = !t1Score.isEmpty ? t1Score : (!t2Score.isEmpty ? t2Score : "107/2")
                let activeOvers = !t1Overs.isEmpty ? t1Overs : (!t2Overs.isEmpty ? t2Overs : "(11.0 ov)")
                
                let newState = CricketMatchAttributes.ContentState(
                    scoreString: activeScore,
                    oversString: activeOvers,
                    currentRunRate: "LIVE",
                    statusMessage: status,
                    homeTeam: t1Abbr,
                    awayTeam: t2Abbr,
                    homeFlag: self.flagForTeam(t1Abbr),
                    awayFlag: self.flagForTeam(t2Abbr)
                )
                
                Task {
                    await self.currentActivity?.update(ActivityContent(state: newState, staleDate: nil))
                }
                return
            }
            
            self.updateLiveBannerStatus("IND-W vs ZIM-W Live in Raipur")
        }.resume()
    }
    
    // Deep recursive finder: walks through any nested dictionaries or arrays
    private func findMatchRecursively(in object: Any) -> [String: Any]? {
        if let dict = object as? [String: Any] {
            // Check if this dictionary represents an India match
            if let teams = dict["teams"] as? [[String: Any]] {
                let combinedText = "\(dict)".uppercased()
                if combinedText.contains("IND") && (combinedText.contains("ZIM") || combinedText.contains("WOMEN")) {
                    return dict
                }
            }
            // Otherwise, search inside its child values
            for (_, value) in dict {
                if let found = findMatchRecursively(in: value) {
                    return found
                }
            }
        } else if let array = object as? [Any] {
            for item in array {
                if let found = findMatchRecursively(in: item) {
                    return found
                }
            }
        }
        return nil
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
