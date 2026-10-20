import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CricketWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CricketMatchAttributes.self) { context in
            // MARK: - Lock Screen & Expanded Banner
            VStack(spacing: 8) {
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
                    
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("LIVE").font(.system(size: 10, weight: .heavy)).foregroundColor(.red)
                    }
                }
                
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.state.scoreString)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                            .contentTransition(.numericText())
                        
                        Text(context.state.oversString)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(context.state.currentRunRate)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.15))
                        .cornerRadius(6)
                }
                
                HStack {
                    Text(context.state.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black)
            .activityBackgroundTint(Color.black.opacity(0.95))
            
        } dynamicIsland: { context in
            DynamicIsland {
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
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                        .contentTransition(.numericText())
                        .padding(.trailing, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.75))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(context.state.currentRunRate)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Text(context.state.homeFlag).font(.system(size: 12))
                    Text(context.state.homeTeam)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
            } compactTrailing: {
                Text(context.state.scoreString)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.4))
                    .contentTransition(.numericText())
            } minimal: {
                Text(context.state.homeFlag)
                    .font(.system(size: 12))
            }
            .keylineTint(Color.blue)
        }
    }
}
