import SwiftUI

@main
struct MenInBlueLiveApp: App {
    @StateObject private var scoreManager = LiveScoreManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scoreManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var scoreManager: LiveScoreManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("🏏 🇮🇳")
                        .font(.system(size: 48))
                    Text("Men in Blue Live")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(scoreManager.statusText)
                        .font(.subheadline)
                        .foregroundColor(Color.gray)
                }

                Button(action: {
                    if scoreManager.isTracking {
                        scoreManager.stopTracking()
                    } else {
                        scoreManager.startTrackingMatch(home: "IND", away: "AUS", matchType: "Live")
                    }
                }) {
                    Text(scoreManager.isTracking ? "Stop Tracking" : "Start Tracking India Match")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(scoreManager.isTracking ? Color.red : Color.blue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)
            }
            .padding()
        }
    }
}
