import ActivityKit
import Foundation

public struct CricketMatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var scoreString: String
        public var oversString: String
        public var currentRunRate: String
        public var statusMessage: String
        public var homeTeam: String
        public var awayTeam: String
        public var homeFlag: String
        public var awayFlag: String
        public var lastEvent: String?
        public var recentBalls: [String]

        public init(
            scoreString: String,
            oversString: String,
            currentRunRate: String,
            statusMessage: String,
            homeTeam: String = "IND",
            awayTeam: String = "AUS",
            homeFlag: String = "🇮🇳",
            awayFlag: String = "🇦🇺",
            lastEvent: String? = nil,
            recentBalls: [String] = []
        ) {
            self.scoreString = scoreString
            self.oversString = oversString
            self.currentRunRate = currentRunRate
            self.statusMessage = statusMessage
            self.homeTeam = homeTeam
            self.awayTeam = awayTeam
            self.homeFlag = homeFlag
            self.awayFlag = awayFlag
            self.lastEvent = lastEvent
            self.recentBalls = recentBalls
        }
    }

    public var homeTeam: String
    public var awayTeam: String
    public var matchType: String

    public init(homeTeam: String = "IND", awayTeam: String = "AUS", matchType: String = "Live") {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.matchType = matchType
    }
}
