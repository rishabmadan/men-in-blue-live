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
            timer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
                self?.fetchAndRefreshScore()
            }
        } catch {
            self.statusText = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Live Score Polling from Vercel Backend
    
    private func fetchAndRefreshScore() {
        // REPLACE THIS URL with your live Vercel domain
        guard let url = URL(string: "https://men-in-blue-live-dopx2-weld.vercel.app/api/cron-update") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.updateLiveBannerStatus("Net: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                self.updateLiveBannerStatus("No data received")
                return
            }
            
            // Check HTTP status code
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                self.updateLiveBannerStatus("Server HTTP \(http.statusCode)")
                return
            }
            
            // Parse clean JSON payload delivered by Vercel
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.updateLiveBannerStatus("Invalid JSON")
                return
            }
            
            // Extract the payload dictionary
            var payload = json["payload"] as? [String: Any]
            if payload == nil, let bodyStr = json["body"] as? String, let bodyData = bodyStr.data(using: .utf8) {
                payload = (try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any])?["payload"] as? [String: Any]
            }
            
            guard let validPayload = payload,
                  let aps = validPayload["aps"] as? [String: Any],
                  let content = aps["content-state"] as? [String: Any] else {
                let status = json["status"] as? String ?? "No live match data"
                self.updateLiveBannerStatus(status)
                return
            }
            
            let score = content["scoreString"] as? String ?? "0/0"
            let overs = content["oversString"] as? String ?? "(0.0)"
            let crr = content["currentRunRate"] as? String ?? "CRR: 0.00"
            let status = content["statusMessage"] as? String ?? "Match Live"
            
            let home = content["homeTeam"] as? String ?? "IND-W"
            let away = content["awayTeam"] as? String ?? "ZIM-W"
            
            let newState = CricketMatchAttributes.ContentState(
                scoreString: score,
                oversString: overs,
                currentRunRate: crr,
                statusMessage: status,
                homeTeam: home,
                awayTeam: away,
                homeFlag: self.flagForTeam(home),
                awayFlag: self.flagForTeam(away)
            )
            
            Task {
                await self.currentActivity?.update(ActivityContent(state: newState, staleDate: nil))
            }
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
