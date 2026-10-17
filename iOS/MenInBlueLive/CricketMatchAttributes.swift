import ActivityKit
import Foundation

public struct CricketMatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var scoreString: String        // e.g., "184/4"
        public var oversString: String        // e.g., "(18.2)"
        public var currentRunRate: String     // e.g., "CRR: 10.04"
        public var statusMessage: String      // e.g., "IND needs 14 off 10 balls"

        public init(scoreString: String, oversString: String, currentRunRate: String, statusMessage: String) {
            self.scoreString = scoreString
            self.oversString = oversString
            self.currentRunRate = currentRunRate
            self.statusMessage = statusMessage
        }
    }

    public var homeTeam: String               // e.g., "IND"
    public var awayTeam: String               // e.g., "AUS"
    public var matchType: String              // e.g., "T20I", "ODI", "TEST"

    public init(homeTeam: String, awayTeam: String, matchType: String) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.matchType = matchType
    }
}
