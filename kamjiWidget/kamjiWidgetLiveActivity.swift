import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct kamjiWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            ZStack {
                // SİMSİYAH ARKAPLAN
                Color.black.ignoresSafeArea()
                
                // HAFİF BİR YIN-YANG GRADYANI (Resim yerine kodla)
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.1), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "yinyang")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    
                    if context.state.isPaused {
                        Text(formatShortTime(context.state.totalWorkedSeconds))
                            .font(.system(size: 48, weight: .thin, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        let simulatedStart = Date().addingTimeInterval(-Double(context.state.totalWorkedSeconds))
                        Text(timerInterval: simulatedStart...Date().addingTimeInterval(3600 * 24), countsDown: false)
                            .font(.system(size: 48, weight: .light, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 15) {
                        Button(intent: ToggleTimerIntent()) {
                            Text(context.state.isPaused ? "Devam Et" : "Duraklat")
                                .font(.footnote).fontWeight(.medium)
                                .foregroundColor(context.state.isPaused ? .black : .white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(context.state.isPaused ? Color.white : Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        Button(intent: EndTimerIntent()) {
                            Text("Sonlandır")
                                .font(.footnote).fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .activitySystemActionForegroundColor(.white)
            .activityBackgroundTint(Color.black)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isPaused ? "Duraklatıldı" : "Odak").foregroundColor(.white)
                }
            } compactLeading: {
                Image(systemName: "yinyang").foregroundColor(.white)
            } compactTrailing: {
                Text("...")
            } minimal: {
                Image(systemName: "yinyang").foregroundColor(.white)
            }
        }
    }
    
    func formatShortTime(_ seconds: Int) -> String {
        let h = seconds / 3600; let m = (seconds % 3600) / 60; let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
