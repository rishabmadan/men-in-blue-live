import ActivityKit
import WidgetKit
import SwiftUI
import Foundation

// MARK: - Activity Attributes & Content State

public struct CricketMatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var scoreString: String        // e.g., "184/4"
        public var oversString: String        // e.g., "(18.2)"
        public var currentRunRate: String     // e.g., "CRR: 10.04"
        public var statusMessage: String      // e.g., "IND needs 12 off 10 balls"
        
        public init(scoreString: String, oversString: String, currentRunRate: String, statusMessage: String) {
            self.scoreString = scoreString
            self.oversString = oversString
            self.currentRunRate = currentRunRate
            self.statusMessage = statusMessage
        }
    }
    
    // Fixed non-changing match metadata
    public var homeTeam: String               // e.g., "IND" or "India"
    public var awayTeam: String               // e.g., "AUS" or "Australia"
    public var matchType: String              // e.g., "T20I", "ODI", "TEST"
    
    public init(homeTeam: String, awayTeam: String, matchType: String) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.matchType = matchType
    }
}

// MARK: - Widget & Dynamic Island Implementation

@main
struct CricketWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CricketMatchAttributes.self) { context in
            // MARK: Lock Screen & StandBy Mode Banner
            HStack(spacing: 14) {
                // Left Column: Match Details & Teams
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(context.attributes.matchType)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text("\(context.attributes.homeTeam) vs \(context.attributes.awayTeam)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(context.state.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Right Column: Live Score & Run Rate
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.state.scoreString)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        
                        Text(context.state.oversString)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(white: 0.6))
                    }
                    
                    Text(context.state.currentRunRate)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.75))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black)
            .activityBackgroundTint(Color.black.opacity(0.95))
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("🇮🇳")
                                .font(.system(size: 16))
                            Text(context.attributes.homeTeam)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Text("vs \(context.attributes.awayTeam)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.6))
                    }
                    .padding(.leading, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.scoreString)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        
                        Text(context.state.oversString)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color(white: 0.6))
                    }
                    .padding(.trailing, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center) {
                        Text(context.state.statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.75))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(context.state.currentRunRate)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(white: 0.15))
                            .cornerRadius(4)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // MARK: Compact Leading
                HStack(spacing: 3) {
                    Text("🇮🇳")
                        .font(.system(size: 12))
                    Text(context.attributes.homeTeam)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                // MARK: Compact Trailing
                Text(context.state.scoreString)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
            } minimal: {
                // MARK: Minimal Presentation
                Text("🏏")
                    .font(.system(size: 12))
            }
            .keylineTint(Color.blue)
        }
    }
}
