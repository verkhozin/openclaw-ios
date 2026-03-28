import SwiftUI

struct UsageCard: View {
    let sessionPercent: Double
    let weeklyPercent: Double
    
    var body: some View {
        HStack(spacing: Theme.paddingL) {
            UsageRing(
                label: "Session",
                percent: sessionPercent,
                color: ringColor(sessionPercent)
            )
            
            UsageRing(
                label: "Weekly",
                percent: weeklyPercent,
                color: ringColor(weeklyPercent)
            )
        }
        .padding(Theme.paddingM)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
    
    private func ringColor(_ percent: Double) -> Color {
        if percent > 80 { return Theme.error }
        if percent > 60 { return Theme.warning }
        return Theme.accent
    }
}

struct UsageRing: View {
    let label: String
    let percent: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: percent / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: percent)
                
                Text("\(Int(percent))%")
                    .font(Theme.fontMonoSmall)
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(width: 80, height: 80)
            
            Text(label)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
        }
    }
}
