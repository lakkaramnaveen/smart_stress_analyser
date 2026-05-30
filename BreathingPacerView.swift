import SwiftUI

struct BreathingPacerView: View {
    @Binding var isActive: Bool
    @EnvironmentObject private var model: AppModel
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.3
    @State private var instruction: String = "Get Ready..."
    @State private var timer: Timer?
    @State private var breathCycleProgress: Double = 0.0

    private let brandTeal = Color(red: 0.31, green: 0.80, blue: 0.77)
    private let brandMint = Color(red: 0.40, green: 0.85, blue: 0.55)
    private let coral = Color(red: 1.0, green: 0.42, blue: 0.42)

    var body: some View {
        ZStack {
            // Glassy background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(0.92)
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Composure Lost.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("Let's bring your heart rate back down.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // Main Breathing Orb with Metrics
                ZStack {
                    // Background glow layers
                    Circle()
                        .fill(brandTeal.opacity(0.3))
                        .frame(width: 280, height: 280)
                        .blur(radius: 30)
                        .scaleEffect(scale * 0.95)
                    
                    Circle()
                        .fill(brandMint.opacity(0.5))
                        .frame(width: 200, height: 200)
                        .blur(radius: 15)
                        .scaleEffect(scale)
                    
                    // Inner circle with border
                    Circle()
                        .fill(brandMint.opacity(0.2))
                        .frame(width: 160, height: 160)
                    
                    Circle()
                        .stroke(brandTeal.opacity(0.6), lineWidth: 2)
                        .frame(width: 160, height: 160)
                    
                    // Center content
                    VStack(spacing: 16) {
                        Text(instruction)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .transition(.opacity)
                        
                        // Real-time metrics during breathing
                        HStack(spacing: 12) {
                            MetricBadge(
                                icon: "heart.fill",
                                value: model.pulseRateText,
                                unit: "bpm",
                                color: coral
                            )
                            
                            MetricBadge(
                                icon: "wind",
                                value: model.breathingRateText,
                                unit: "brpm",
                                color: brandMint
                            )
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                }
                .opacity(opacity)
                .frame(height: 320)
                
                // Breath Cycle Progress Bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Breath Cycle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(breathCycleProgress * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(brandTeal)
                    }
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [brandMint, brandTeal]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, 280 * breathCycleProgress))
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 280)
                }
                .padding(.horizontal, 20)
                
                // Stress Level Indicator
                VStack(spacing: 6) {
                    HStack {
                        Text("Stress Level")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "%.1f%%", model.stressScore * 100))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(model.emotionalState.color)
                    }
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(model.emotionalState.color)
                            .frame(width: max(0, 280 * model.stressScore))
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 280)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(model.emotionalState.color)
                            .frame(width: 8, height: 8)
                        
                        Text(model.detectedEmotion)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action Button
                Button(action: { stopBreathingCycle() }) {
                    Text("Resume Session")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                }
                .tint(.white)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            startBreathingCycle()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Animation Engine
    private func startBreathingCycle() {
        performBreath()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            performBreath()
        }
    }
    
    private func performBreath() {
        // Inhale (4 seconds)
        withAnimation(.easeInOut(duration: 4.0)) {
            scale = 1.2
            opacity = 1.0
            instruction = "Breathe In..."
            breathCycleProgress = 0.4
        }
        
        // Exhale (6 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 6.0)) {
                scale = 0.5
                opacity = 0.3
                instruction = "Breathe Out..."
                breathCycleProgress = 1.0
            }
        }
        
        // Reset for next cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            breathCycleProgress = 0.0
        }
    }
    
    private func stopBreathingCycle() {
        timer?.invalidate()
        withAnimation(.easeOut(duration: 0.5)) {
            isActive = false
        }
    }
}

// MARK: - Supporting Components
struct MetricBadge: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(unit)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(8)
        .frame(minWidth: 50)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
}
