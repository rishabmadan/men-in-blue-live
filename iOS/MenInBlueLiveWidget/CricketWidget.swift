import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CricketWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CricketMatchAttributes.self) { context in
            // MARK: - Lock Screen & Expanded Banner
            VStack(spacing: 10) {
                // Top Row: Match Header & Event Celebration Badge
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Text("\(context.state.homeFlag) \(context.state.homeTeam)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("vs")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        Text("\(context.state.awayFlag) \(context.state.awayTeam)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Animated Event Badge (FOUR / SIX / WICKET)
                    if let event = context.state.lastEvent {
                        eventBadgeView(event: event)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                            Text("LIVE").font(.system(size: 10, weight: .heavy)).foregroundColor(.red)
                        }
                    }
                }
                
                // Middle Row: Score + Smooth Number Rolling Transition
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.state.scoreString)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                            .contentTransition(.numericText()) // Rolls numbers smoothly
                        
                        Text(context.state.oversString)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(context.state.currentRunRate)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.15))
                        .cornerRadius(6)
                }
                
                // Bottom Row: Over Ball Pills (e.g. 1, 4, •, W, 6) & Status
                HStack {
                    Text(context.state.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Recent Balls Pills
                    if !context.state.recentBalls.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(context.state.recentBalls.suffix(6).enumerated()), id: \.offset) { _, ball in
                                ballPill(ball: ball)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black)
            .activityBackgroundTint(Color.black.opacity(0.95))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Dynamic Island Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Text(context.state.homeFlag).font(.system(size: 16))
                        Text(context.state.homeTeam)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.scoreString)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        .contentTransition(.numericText())
                        .padding(.trailing, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let event = context.state.lastEvent {
                            eventBadgeView(event: event)
                        } else {
                            Text(context.state.statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(white: 0.75))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(context.state.currentRunRate)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact Leading: 🇮🇳 IND
                HStack(spacing: 3) {
                    Text(context.state.homeFlag).font(.system(size: 12))
                    Text(context.state.homeTeam)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
            } compactTrailing: {
                // Compact Trailing: Score or Event Alert
                if let event = context.state.lastEvent, event == "WICKET" {
                    Text("OUT!")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.red)
                } else {
                    Text(context.state.scoreString)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        .contentTransition(.numericText())
                }
            } minimal: {
                Text(context.state.homeFlag)
                    .font(.system(size: 12))
            }
            .keylineTint(Color.blue)
        }
    }
    
    // MARK: - Helper UI Badges
    
    @ViewBuilder
    private func eventBadgeView(event: String) -> some View {
        switch event.uppercased() {
        case "FOUR", "4":
            Text("💥 FOUR!")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.cyan)
                .cornerRadius(6)
        case "SIX", "6":
            Text("🚀 SIX!")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.purple)
                .cornerRadius(6)
        case "WICKET", "W":
            Text("🔴 WICKET!")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.red)
                .cornerRadius(6)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func ballPill(ball: String) -> some View {
        let isBoundary = ball == "4" || ball == "6"
        let isWicket = ball.uppercased() == "W"
        
        Text(ball)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(isWicket ? .white : (isBoundary ? .black : .white))
            .frame(width: 18, height: 18)
            .background(
                isWicket ? Color.red : (ball == "6" ? Color.purple : (ball == "4" ? Color.cyan : Color(white: 0.2)))
            )
            .clipShape(Circle())
    }
}
