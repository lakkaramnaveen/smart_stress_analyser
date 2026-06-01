import SwiftUI

enum ComposureMode: String, CaseIterable {
    case focus = "Focus Guardian"
    case pitch = "Pitch Coach"
}

enum SidebarTab: String, CaseIterable {
    case controls = "Controls"
    case stress = "Stress"
    case emotions = "Emotions"
    case game = "Game"
    
    var icon: String {
        switch self {
        case .controls: return "gear"
        case .stress: return "chart.line.uptrend.xyaxis"
        case .emotions: return "brain.head.profile"
        case .game: return "gamecontroller.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var activeMode: ComposureMode = .focus
    @State private var activeSidebarTab: SidebarTab = .controls
    @State private var showGameFullscreen: Bool = false

    private let coral = Color(red: 1.0, green: 0.42, blue: 0.42)
    private let teal = Color(red: 0.31, green: 0.80, blue: 0.77)
    private let mint = Color(red: 0.40, green: 0.85, blue: 0.55)
    private let slate = Color(white: 0.15)

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                mainWorkspace
                Divider()
                sidebarControls
                    .frame(width: 320)
            }
            
            // Fullscreen game overlay
            if showGameFullscreen {
                BalloonHuntGameView()
                    .environmentObject(model)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(1000)
            }
            
            // Breathing pacer overlay (only at critical stress)
            if model.isBiofeedbackActive {
                BreathingPacerView(isActive: $model.isBiofeedbackActive)
                    .environmentObject(model)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut, value: model.isBiofeedbackActive)
    }
    
    // MARK: - Main Visual Area
    private var mainWorkspace: some View {
        ZStack {
            Color.black

            if let frame = model.frame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: activeMode == .focus ? 20 : 0)
                    .opacity(activeMode == .focus ? 0.4 : 1.0)
            } else {
                placeholderView
            }

            VStack {
                HStack {
                    validationPill
                    Spacer()
                    HStack(spacing: 8) {
                        modeIndicator
                        stressLevelIndicator
                    }
                }
                .padding(18)

                Spacer()
                
                if activeMode == .focus {
                    focusMetricsOverlay
                } else {
                    pitchCoachOverlay
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar Controls
    private var sidebarControls: some View {
        VStack(spacing: 0) {
            // Tab Navigation
            HStack(spacing: 4) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Button(action: { activeSidebarTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(activeSidebarTab == tab ? .white : .white.opacity(0.5))
                        .padding(.vertical, 8)
                    }
                    .background(activeSidebarTab == tab ? Color.white.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.04))
            
            Divider()
            
            // Tab Content
            ZStack {
                switch activeSidebarTab {
                case .controls:
                    controlsPanel
                case .stress:
                    ScrollView {
                        StressVisualizationView()
                            .environmentObject(model)
                            .padding(12)
                    }
                case .emotions:
                    ScrollView {
                        EmotionalDetectorView()
                            .environmentObject(model)
                            .padding(12)
                    }
                case .game:
                    gamePanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(slate)
    }
    
    private var controlsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Composure")
                        .font(.title.weight(.bold))
                    Text("Bio-Adaptive Workspace")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // Mode Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Mode")
                        .font(.headline)
                    Picker("Mode", selection: $activeMode) {
                        ForEach(ComposureMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Stress Level Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stress Status")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Level")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text(model.stressLevel.description)
                                .font(.callout.weight(.bold))
                                .foregroundStyle(model.stressLevel.color)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Score")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text(String(format: "%.0f%%", model.stressScore * 100))
                                .font(.callout.weight(.bold))
                                .foregroundStyle(model.stressLevel.color)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }

                // Authentication
                VStack(alignment: .leading, spacing: 8) {
                    Text("SmartSpectra API")
                        .font(.headline)
                    SecureField("API Key", text: $model.apiKey)
                        .textFieldStyle(.roundedBorder)
                }

                // Engine Controls
                HStack(spacing: 12) {
                    Button(action: { model.start() }) {
                        Label(activeMode == .pitch ? "Start Session" : "Enable Tracking", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(teal)
                    .disabled(model.isRunning)

                    Button(action: { model.stop() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.isRunning)
                }

                // Error Display
                if !model.errorMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Error")
                                .font(.caption.weight(.semibold))
                        }
                        Text(model.errorMessage)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }

                // Session Info
                if model.isRunning {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Stats")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Duration")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(formatTime(model.totalSessionTime))
                                    .font(.caption.weight(.bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Peak Stress")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(String(format: "%.0f%%", model.highestStressInSession * 100))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(coral)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }
    
    private var gamePanel: some View {
        VStack(spacing: 16) {
            // Game Difficulty Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    ForEach([GameDifficulty.easy, .medium, .hard, .extreme], id: \.self) { difficulty in
                        let isSelected = model.gameDifficulty == difficulty
                        Button(action: { model.gameDifficulty = difficulty }) {
                            Text(difficultyLabel(difficulty))
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(isSelected ? Color(red: 0.31, green: 0.80, blue: 0.77) : Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            
            // Game Stats Summary
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Stats")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Text("Balloon Hunt")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                
                Divider()
                    .opacity(0.1)
                
                VStack(spacing: 12) {
                    StatsRow(icon: "balloon.fill", label: "Balloons Popped", value: "\(model.balloonsPoppedInSession)", color: coral)
                    StatsRow(icon: "star.fill", label: "Current Score", value: "\(model.gameScore)", color: mint)
                    StatsRow(icon: "timer", label: "Game Time", value: formatTime(model.gameTime), color: teal)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            
            // Eye Tracking Status
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: model.isEyeTrackingAvailable ? "eye" : "eye.slash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(model.isEyeTrackingAvailable ? mint : coral)
                    
                    Text("Eye Tracking")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    if model.isEyeTrackingAvailable {
                        Text("\(Int(model.eyeTrackingConfidence * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(mint)
                    } else {
                        Text("Offline")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(coral)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                
                HStack {
                    Image(systemName: "eyes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(teal)
                    
                    Text("Blink Detection")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    if model.blinkDetected {
                        Text("●")
                            .font(.title3)
                            .foregroundStyle(teal)
                    } else {
                        Text("○")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            
            Divider()
                .opacity(0.1)
            
            // Start Game Button - FIXED
            Button(action: { showGameFullscreen = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                    Text("Launch Balloon Hunt")
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [mint.opacity(0.8), teal.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(!model.isRunning)
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("How to Play")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(teal)
                            .frame(width: 20)
                        
                        Text("Look at balloons floating up")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "eyes")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(coral)
                            .frame(width: 20)
                        
                        Text("Blink to shoot and pop them")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(mint)
                            .frame(width: 20)
                        
                        Text("Earn points (more in higher difficulty)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.top, 4)
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    // MARK: - Subviews & Overlays
    
    private var focusMetricsOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VitalTile(
                    title: "Cognitive Load",
                    value: model.breathingRateText,
                    unit: "brpm",
                    confidence: model.breathingConfidenceText,
                    icon: "wind",
                    color: mint,
                    points: model.breathingTraceHistory
                )
                
                VitalTile(
                    title: "Heart Rate",
                    value: model.pulseRateText,
                    unit: "bpm",
                    confidence: model.pulseConfidenceText,
                    icon: "heart.fill",
                    color: coral,
                    points: model.pulseTraceHistory.isEmpty ? model.pulseRateTrendHistory : model.pulseTraceHistory
                )
            }
        }
        .padding(18)
        .background(gradientBackdrop)
    }

    private var pitchCoachOverlay: some View {
        VStack(spacing: 12) {
            VitalTile(
                title: "Stress Response",
                value: model.edaLevelText,
                unit: "µS",
                confidence: "",
                icon: "waveform.path.ecg",
                color: teal,
                points: model.edaTraceHistory
            )
        }
        .padding(18)
        .background(gradientBackdrop)
    }
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 44))
            Text("Camera offline")
                .font(.title3)
        }
        .foregroundStyle(.secondary)
    }

    private var validationPill: some View {
        Text(model.validationStatus.isEmpty ? "Waiting..." : model.validationStatus)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
    }

    private var modeIndicator: some View {
        Text(activeMode.rawValue)
            .font(.caption.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(teal, in: Capsule())
    }
    
    private var stressLevelIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.stressLevel.color)
                .frame(width: 8, height: 8)
            
            Text(model.stressLevel.description)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(model.stressLevel.color.opacity(0.2), in: Capsule())
    }

    private var gradientBackdrop: some View {
        LinearGradient(colors: [.clear, .black.opacity(0.8), .black], startPoint: .top, endPoint: .bottom)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func difficultyLabel(_ difficulty: GameDifficulty) -> String {
        switch difficulty {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }
}

// MARK: - Supporting Components

struct VitalTile: View {
    let title: String
    let value: String
    let unit: String
    let confidence: String
    let icon: String
    let color: Color
    let points: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3.weight(.semibold))
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                if !confidence.isEmpty {
                    Text(confidence)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.54))
                }
            }

            Sparkline(points: points, color: color)
                .frame(height: 46)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 152)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Sparkline: View {
    let points: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    for fraction in [0.25, 0.5, 0.75] {
                        let y = proxy.size.height * (1.0 - fraction)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)

                if points.count >= 2 {
                    SparklinePath(points: points)
                        .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    SparklinePath(points: points)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .padding(4)
        }
    }
}

struct SparklinePath: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2,
              let minValue = points.min(),
              let maxValue = points.max() else {
            return path
        }

        let range = maxValue - minValue
        for (index, value) in points.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(points.count - 1)
            let normalized = range > 0 ? (value - minValue) / range : 0.5
            let y = rect.maxY - rect.height * CGFloat(normalized)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

struct StatsRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
    }
}
