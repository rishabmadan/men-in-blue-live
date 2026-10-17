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
    
    // MARK: - Start Tracking (Local Polling, No APNs Needed)
    
    public func startTrackingMatch(home: String, away: String, matchType: String) {
        let homeUpper = home.uppercased()
        let awayUpper = away.uppercased()
        
        // Strict structural country filter
        guard homeUpper.contains("IND") || homeUpper.contains("INDIA") ||
              awayUpper.contains("IND") || awayUpper.contains("INDIA") else {
            self.statusText = "Refused: Non-India match"
            return
        }
        
        stopTracking()
        setupBackgroundKeepAlive()
        
        let attributes = CricketMatchAttributes(homeTeam: home, awayTeam: away, matchType: matchType)
        let initialContent = CricketMatchAttributes.ContentState(
            scoreString: "0/0",
            oversString: "(0.0)",
            currentRunRate: "CRR: 0.00",
            statusMessage: "Starting Men in Blue Live..."
        )
        
        do {
            // pushType is nil: purely local updates, zero Apple developer keys needed
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialContent, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
            self.isTracking = true
            self.statusText = "Tracking Live"
            
            // Poll Cricbuzz immediately, then every 30 seconds
            fetchAndRefreshScore()
            timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.fetchAndRefreshScore()
            }
        } catch {
            self.statusText = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Direct Score Fetching from Cricbuzz
    
    private func fetchAndRefreshScore() {
        guard let url = URL(string: "https://www.cricbuzz.com/api/cricket-match/live-scores") else { return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let typeMatches = json["typeMatches"] as? [[String: Any]] else { return }
            
            for category in typeMatches {
                for series in category["seriesMatches"] as? [[String: Any]] ?? [] {
                    let wrapper = series["seriesAdWrapper"] as? [String: Any] ?? [:]
                    for match in wrapper["matches"] as? [[String: Any]] ?? [] {
                        let info = match["matchInfo"] as? [String: Any] ?? [:]
                        let t1 = (info["team1"] as? [String: Any])?["teamSName"] as? String ?? ""
                        let t2 = (info["team2"] as? [String: Any])?["teamSName"] as? String ?? ""
                        
                        if t1.contains("IND") || t2.contains("IND") {
                            let scores = match["matchScore"] as? [String: Any] ?? [:]
                            let isT1 = t1.contains("IND")
                            let teamScore = (isT1 ? scores["team1Score"] : scores["team2Score"]) as? [String: Any]
                            let inngs = (teamScore?["inngs2"] ?? teamScore?["inngs1"]) as? [String: Any] ?? [:]
                            
                            let runs = inngs["runs"] as? Int ?? 0
                            let wickets = inngs["wickets"] as? Int ?? 0
                            let overs = inngs["overs"] as? Double ?? 0.0
                            let status = info["status"] as? String ?? "Live"
                            let crr = overs > 0 ? String(format: "CRR: %.2f", Double(runs) / overs) : "CRR: 0.00"
                            
                            let newState = CricketMatchAttributes.ContentState(
                                scoreString: "\(runs)/\(wickets)",
                                oversString: "(\(overs))",
                                currentRunRate: crr,
                                statusMessage: status
                            )
                            
                            Task {
                                await self?.currentActivity?.update(ActivityContent(state: newState, staleDate: nil))
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
