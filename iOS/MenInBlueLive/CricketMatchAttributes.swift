import ActivityKit
import Foundation

public struct CricketMatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var scoreString: String          // e.g., "184/4"
        public var oversString: String          // e.g., "(18.2)"
        public var currentRunRate: String       // e.g., "CRR: 10.04"
        public var statusMessage: String        // e.g., "IND needs 14 off 10 balls"
        public var lastEvent: String?           // "FOUR", "SIX", "WICKET", or nil
        public var recentBalls: [String]        // e.g., ["1", "4", "0", "W", "6"]
        public var homeTeam: String             // e.g., "IND"
        public var awayTeam: String             // e.g., "NZ"
        public var homeFlag: String             // e.g., "🇮🇳"
        public var awayFlag: String             // e.g., "🇳🇿"

        public init(
            scoreString: String,
            oversString: String,
            currentRunRate: String,
            statusMessage: String,
            lastEvent: String? = nil,
            recentBalls: [String] = [],
            homeTeam: String = "IND",
            awayTeam: String = "AUS",
            homeFlag: String = "🇮🇳",
            awayFlag: String = "🇦🇺"
        ) {
            self.scoreString = scoreString
            self.oversString = oversString
            self.currentRunRate = currentRunRate
            self.statusMessage = statusMessage
            self.lastEvent = lastEvent
            self.recentBalls = recentBalls
            self.homeTeam = homeTeam
            self.awayTeam = awayTeam
            self.homeFlag = homeFlag
            self.awayFlag = awayFlag
        }
    }

    public var matchTitle: String               // e.g., "India Tour of Australia"
    
    public init(matchTitle: String) {
        self.matchTitle = matchTitle
    }
}
