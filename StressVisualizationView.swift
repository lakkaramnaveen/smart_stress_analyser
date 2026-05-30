import SwiftUI

struct StressVisualizationView: View {
    @EnvironmentObject private var model: AppModel
    
    private let teal = Color(red: 0.31, green: 0.80, blue: 0.77)
    private let mint = Color(red: 0.40, green: 0.85, blue: 0.55)
    private let coral = Color(red: 1.0, green: 0.42, blue: 0.42)
    private let amber = Color(red: 1.0, green: 0.82, blue: 0.35)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stress Trajectory")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text("Last 5 minutes of data")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(String(format: "%.1f%%", model.stressScore * 100))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(stressColor)
                }
            }
            
            // Graph
            ZStack(alignment: .bottomLeading) {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        stressColor.opacity(0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 180)
                .cornerRadius(12)
                
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        Divider()
                            .opacity(0.1)
                        Spacer()
                    }
                }
                .frame(height: 180)
                
                // Data path
                if model.stressHistory.count > 1 {
                    StressGraph(data: model.stressHistory, color: stressColor)
                        .frame(height: 180)
                } else {
                    VStack {
                        Spacer()
                        Text("Collecting data...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                }
                
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    Text("100%")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Spacer()
                    
                    Text("50%")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Spacer()
                    
                    Text("0%")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(height: 180)
                .padding(.trailing, -25)
            }
            .frame(height: 180)
            .padding(.horizontal, 20)
            
            // Statistics Row
            HStack(spacing: 12) {
                StatsCard(
                    icon: "arrow.up",
                    label: "Peak",
                    value: String(format: "%.0f%%", (model.stressHistory.max() ?? 0) * 100),
                    color: coral
                )
                
                StatsCard(
                    icon: "line.3.horizontal",
                    label: "Average",
                    value: String(format: "%.0f%%", (model.stressHistory.isEmpty ? 0 : model.stressHistory.reduce(0, +) / Double(model.stressHistory.count)) * 100),
                    color: teal
                )
                
                StatsCard(
                    icon: "arrow.down",
                    label: "Min",
                    value: String(format: "%.0f%%", (model.stressHistory.min() ?? 0) * 100),
                    color: mint
                )
                
                StatsCard(
                    icon: "bolt.fill",
                    label: "Trend",
                    value: trendDirection,
                    color: trendColor
                )
            }
            .padding(.horizontal, 20)
            
            // AI Insights
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(teal)
                    
                    Text("AI Insight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                
                Text(stressInsight)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    private var stressColor: Color {
        if model.stressScore < 0.3 {
            return mint
        } else if model.stressScore < 0.6 {
            return amber
        } else {
            return coral
        }
    }
    
    private var trendDirection: String {
        guard model.stressHistory.count > 10 else { return "—" }
        
        let recent = model.stressHistory.suffix(5).reduce(0, +) / 5.0
        let older = model.stressHistory.dropLast(5).suffix(5).reduce(0, +) / 5.0
        
        let change = recent - older
        if abs(change) < 0.05 {
            return "→"
        } else if change > 0 {
            return "↑"
        } else {
            return "↓"
        }
    }
    
    private var trendColor: Color {
        let recent = model.stressHistory.suffix(5).reduce(0, +) / 5.0
        let older = model.stressHistory.dropLast(5).suffix(5).reduce(0, +) / 5.0
        let change = recent - older
        
        if abs(change) < 0.05 { return teal }
        else if change > 0 { return coral }
        else { return mint }
    }
    
    private var stressInsight: String {
        let stressLevel = model.stressScore
        let emotion = model.detectedEmotion
        
        if stressLevel < 0.3 {
            return "Great composure! Your vitals indicate a calm, focused state. Keep maintaining this."
        } else if stressLevel < 0.6 {
            return "Mild stress detected. Consider taking a slow breath or brief pause to reset."
        } else if stressLevel < 0.8 {
            return "Elevated stress. Try the breathing pacer or take a moment away from the screen."
        } else {
            return "High stress detected. Activate breathing guidance and focus on relaxation techniques."
        }
    }
}

// MARK: - Supporting Views

struct StressGraph: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Filled area under the curve
                // ... inside StressGraph struct
                Canvas { context, size in // Ensure both parameters are defined
                    guard data.count > 1 else { return }
                    
                    var path = Path()
                    let width = size.width
                    let height = size.height
                    
                    // Draw the path using the 'size' argument provided by the Canvas
                    for (index, value) in data.enumerated() {
                        let x = (width / CGFloat(data.count - 1)) * CGFloat(index)
                        let y = height * (1.0 - CGFloat(value))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    // Create a fill path
                    var fillPath = path
                    fillPath.addLine(to: CGPoint(x: width, y: height))
                    fillPath.addLine(to: CGPoint(x: 0, y: height))
                    fillPath.closeSubpath()
                    
                    context.fill(fillPath, with: .color(color.opacity(0.2)))
                    context.stroke(path, with: .color(color), lineWidth: 2.5)
                }
                
                // Latest data point indicator
                if let lastValue = data.last {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .offset(
                            x: geometry.size.width - 4,
                            y: geometry.size.height * (1.0 - CGFloat(lastValue)) - 4
                        )
                }
            }
            .padding(.leading, 4)
        }
    }
}

struct StatsCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
