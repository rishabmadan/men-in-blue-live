import Foundation
import ActivityKit
import Combine

/// Manages the lifecycle of the "Men in Blue Live" ActivityKit session,
/// listens for APNs push token updates, and synchronizes tokens with the backend.
public class LiveScoreManager: ObservableObject {
    public static let shared = LiveScoreManager()
    
    @Published public private(set) var currentActivityId: String? = nil
    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var statusText: String = "Idle"
    
    // Replace with your verified backend deployment domain
    private let backendBaseURL = "https://your-deployment-domain.vercel.app"
    private var tokenUpdateTask: Task<Void, Never>?
    
    public init() {}
    
    deinit {
        tokenUpdateTask?.cancel()
    }
    
    // MARK: - Match Initialization with Strict Country Filter
    
    /// Requests and starts a new Live Activity for an India cricket match.
    /// Rejects initialization if neither participant matches "India" or "IND".
    public func startTrackingMatch(
        home: String,
        away: String,
        matchType: String,
        initialState: CricketMatchAttributes.ContentState
    ) {
        let homeUpper = home.uppercased()
        let awayUpper = away.uppercased()
        
        // Strict Structural Country Filter: Refuse non-India fixtures
        let isIndiaInvolved = homeUpper.contains("IND") ||
                              homeUpper.contains("INDIA") ||
                              awayUpper.contains("IND") ||
                              awayUpper.contains("INDIA")
        
        guard isIndiaInvolved else {
            let rejectionMessage = "[Strict Country Filter] Neither '\(home)' nor '\(away)' matches India/IND. Live Activity refused."
            print(rejectionMessage)
            DispatchQueue.main.async {
                self.statusText = "Refused: Non-India match"
            }
            return
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[ActivityKit] Live Activities are disabled by the user or system policy.")
            DispatchQueue.main.async {
                self.statusText = "Live Activities disabled in Settings"
            }
            return
        }
        
        // Terminate any existing live trackers before spinning up a new match session
        stopAllActiveTrackers()
        
        let attributes = CricketMatchAttributes(
            homeTeam: home,
            awayTeam: away,
            matchType: matchType
        )
        
        do {
            // Request Live Activity with remote push token updates enabled
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: .token
            )
            
            DispatchQueue.main.async {
                self.currentActivityId = activity.id
                self.isTracking = true
                self.statusText = "Tracking \(home) vs \(away)"
            }
            print("[ActivityKit] Live Activity started with ID: \(activity.id)")
            
            // Listen for Apple's ephemeral push token updates
            listenForPushTokens(for: activity)
            
        } catch {
            print("[ActivityKit] Initialization failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.statusText = "Failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Ephemeral Push Token Stream Handling
    
    private func listenForPushTokens(for activity: Activity<CricketMatchAttributes>) {
        tokenUpdateTask?.cancel()
        tokenUpdateTask = Task {
            for await tokenData in activity.pushTokenUpdates {
                // Convert Apple's raw byte buffer into lowercase hex string
                let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
                print("[APNs] Received updated push token for activity: \(activity.id)")
                sendTokenToBackend(tokenStr: tokenString, activityId: activity.id)
            }
        }
    }
    
    // MARK: - Secure Backend Token Registration
    
    private func sendTokenToBackend(tokenStr: String, activityId: String) {
        guard let url = URL(string: "\(backendBaseURL)/api/register-token") else {
            print("[Network] Invalid backend URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        let payload: [String: String] = [
            "token": tokenStr,
            "activityId": activityId,
            "platform": "ios",
            "registeredAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("[Serialization] Failed to encode token payload: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Network Error] Token registration failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("[Network Success] APNs push token registered successfully with backend.")
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[Network Error] Backend returned status code \(code)")
            }
        }.resume()
    }
    
    // MARK: - Lifecycle Teardown
    
    /// Dismisses and ends all active ActivityKit trackers immediately.
    public func stopAllActiveTrackers() {
        tokenUpdateTask?.cancel()
        tokenUpdateTask = nil
        
        Task {
            for activity in Activity<CricketMatchAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        DispatchQueue.main.async {
            self.currentActivityId = nil
            self.isTracking = false
            self.statusText = "Idle"
        }
    }
}
