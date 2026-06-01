import SwiftUI

struct BalloonHuntGameView: View {
    @EnvironmentObject private var model: AppModel
    @State private var balloons: [Balloon] = []
    @State private var gameDisplayTimer: Timer?
    @State private var balloonSpawnTimer: Timer?
    @State private var gameStartTime: Date?
    @State private var showGameComplete = false
    
    private let gameAreaWidth: CGFloat = 600
    private let gameAreaHeight: CGFloat = 800
    private var gameAreaMinX: CGFloat { (1040 - 320 - gameAreaWidth) / 2 }
    private var gameAreaMinY: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Game background with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.16),
                    Color(red: 0.12, green: 0.15, blue: 0.20)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Game Header
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Balloon Hunt")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("Difficulty: \(model.gameDifficulty.description)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Score")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("\(model.gameScore)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color(red: 0.31, green: 0.80, blue: 0.77))
                        }
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Time")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text(formatTime(model.gameTime))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color(red: 0.40, green: 0.85, blue: 0.55))
                        }
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Popped")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("\(model.balloonsPoppedInSession)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                
                // Game Canvas
                ZStack {
                    // Eye tracking visualization
                    EyeTrackingCrosshair(
                        x: model.eyeGazeX,
                        y: model.eyeGazeY,
                        blink: model.blinkDetected,
                        confidence: model.eyeTrackingConfidence
                    )
                    
                    // Balloons
                    ForEach(balloons) { balloon in
                        BalloonView(balloon: balloon)
                            .position(
                                x: gameAreaMinX + balloon.x,
                                y: gameAreaMinY + balloon.y
                            )
                    }
                    
                    // Game complete overlay
                    if showGameComplete {
                        VStack(spacing: 16) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                            
                            Text("Perfect!")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("\(model.balloonsPoppedInSession) balloons in \(formatTime(model.gameTime))")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Text("Final Score: \(model.gameScore)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color(red: 0.31, green: 0.80, blue: 0.77))
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: gameAreaHeight)
                .background(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.15, green: 0.20, blue: 0.25),
                            Color(red: 0.08, green: 0.12, blue: 0.16)
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 300
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(12)
                
                // Instructions & Difficulty Info
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Look at balloons")
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eyes")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Blink to shoot")
                                .font(.caption)
                        }
                    }
                    
                    // Eye tracking status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(model.eyeTrackingConfidence > 0.7 ? Color(red: 0.40, green: 0.85, blue: 0.55) : Color(red: 1.0, green: 0.82, blue: 0.35))
                            .frame(width: 6, height: 6)
                        
                        Text("Eye Tracking: \(Int(model.eyeTrackingConfidence * 100))%")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(model.blinkDetected ? "Blink! 👁️" : "Ready")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(model.blinkDetected ? Color(red: 1.0, green: 0.82, blue: 0.35) : .white.opacity(0.6))
                    }
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            // Eye Tracking Status Overlay
            if !model.isEyeTrackingAvailable {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                    
                    Text("Eye Tracking Offline")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text("Using simulated eye tracking")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Button(action: { enableMockTracking() }) {
                        Text("Enable Mock Tracking")
                            .font(.caption.weight(.semibold))
                            .padding(8)
                            .background(Color(red: 0.31, green: 0.80, blue: 0.77))
                            .cornerRadius(6)
                    }
                    .foregroundStyle(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .onAppear {
            startGame()
        }
        .onDisappear {
            stopGame()
        }
        .onChange(of: model.blinkDetected) { newValue in
            if newValue {
                handleBlink()
            }
        }
    }
    
    private func startGame() {
        model.startGame(mode: .balloonHunt, difficulty: model.gameDifficulty)
        gameStartTime = Date()
        showGameComplete = false
        balloons = []
        
        // Spawn first balloon immediately
        spawnBalloon()
        
        // Schedule balloon spawning based on difficulty
        balloonSpawnTimer = Timer.scheduledTimer(
            withTimeInterval: model.gameDifficulty.balloonSpawnInterval,
            repeats: true
        ) { _ in
            spawnBalloon()
        }
        
        // Game update loop at 60 FPS
        gameDisplayTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateGame()
        }
    }
    
    private func stopGame() {
        model.stopGame()
        gameDisplayTimer?.invalidate()
        balloonSpawnTimer?.invalidate()
        balloons = []
    }
    
    private func spawnBalloon() {
        guard balloons.count < 20 else { return } // Max 20 balloons
        
        let velocityRange = model.gameDifficulty.balloonVelocityRange
        let newBalloon = Balloon(
            id: UUID(),
            x: CGFloat.random(in: 30...(gameAreaWidth - 30)),
            y: gameAreaHeight + 20,
            size: CGFloat.random(in: 25...55),
            color: randomBalloonColor(),
            velocity: CGFloat.random(in: velocityRange)
        )
        balloons.append(newBalloon)
    }
    
    private func updateGame() {
        // Update balloon positions
        balloons = balloons.map { balloon in
            var updated = balloon
            updated.y -= updated.velocity * 0.016 // 60 FPS delta
            return updated
        }
        
        // Remove balloons that left the screen
        balloons.removeAll { $0.y < -100 }
        
        // Check if all balloons are gone after minimum game time
        if balloons.isEmpty && model.gameTime > 3.0 {
            DispatchQueue.main.async {
                showGameComplete = true
            }
            // Auto-close after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                stopGame()
            }
        }
    }
    
    private func handleBlink() {
        // Calculate crosshair position in game area
        let crosshairX = gameAreaMinX + (model.eyeGazeX * gameAreaWidth)
        let crosshairY = gameAreaMinY + (model.eyeGazeY * gameAreaHeight)
        
        var balloonPopped = false
        
        for (index, balloon) in balloons.enumerated() {
            let balloonCenterX = gameAreaMinX + balloon.x
            let balloonCenterY = gameAreaMinY + balloon.y
            
            let dx = crosshairX - balloonCenterX
            let dy = crosshairY - balloonCenterY
            let distance = sqrt(dx * dx + dy * dy)
            
            // Check collision
            if distance < (balloon.size / 2.0) {
                balloons.remove(at: index)
                model.recordBalloonPop()
                triggerHapticFeedback()
                balloonPopped = true
                break
            }
        }
        
        if !balloonPopped && model.eyeTrackingConfidence > 0.6 {
            // Soft haptic for "near miss"
            triggerWeakHapticFeedback()
        }
    }
    
    private func triggerHapticFeedback() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.alignment, performanceTime: .now)
    }
    
    private func triggerWeakHapticFeedback() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.generic, performanceTime: .default)
    }
    
    private func enableMockTracking() {
        model.isEyeTrackingAvailable = true
        model.simulateEyeTracking()
    }
    
    private func randomBalloonColor() -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.42, blue: 0.42),    // coral
            Color(red: 0.31, green: 0.80, blue: 0.77),   // teal
            Color(red: 0.40, green: 0.85, blue: 0.55),   // mint
            Color(red: 1.0, green: 0.82, blue: 0.35),    // amber
            Color(red: 0.60, green: 0.60, blue: 1.0)     // blue
        ]
        return colors.randomElement() ?? colors[0]
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Game Models & Supporting Views

struct Balloon: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    let velocity: CGFloat
}

struct BalloonView: View {
    let balloon: Balloon
    @State private var wobbleOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Main balloon with gradient
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            balloon.color.opacity(0.9),
                            balloon.color.opacity(0.7)
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: balloon.size
                    )
                )
                .frame(width: balloon.size, height: balloon.size)
                .overlay(
                    Circle()
                        .stroke(balloon.color.opacity(0.5), lineWidth: 1.5)
                )
            
            // Highlight/shine effect
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: balloon.size * 0.35, height: balloon.size * 0.35)
                .offset(x: -balloon.size * 0.15, y: -balloon.size * 0.15)
            
            // String with wobble effect
            VStack(spacing: 0) {
                Spacer()
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: wobbleOffset, y: balloon.size * 0.4))
                }
                .stroke(balloon.color.opacity(0.6), lineWidth: 1)
                .frame(height: balloon.size * 0.4)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                wobbleOffset = 3
            }
        }
    }
}

struct EyeTrackingCrosshair: View {
    let x: Double
    let y: Double
    let blink: Bool
    let confidence: Double
    
    private var crosshairColor: Color {
        if confidence > 0.8 {
            return Color(red: 0.40, green: 0.85, blue: 0.55) // mint - good tracking
        } else if confidence > 0.5 {
            return Color(red: 1.0, green: 0.82, blue: 0.35) // amber - moderate
        } else {
            return Color(red: 1.0, green: 0.42, blue: 0.42) // coral - poor
        }
    }
    
    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(crosshairColor.opacity(0.3), lineWidth: 1.5)
                .frame(width: 60, height: 60)
            
            // Middle circle
            Circle()
                .stroke(crosshairColor.opacity(0.5), lineWidth: 1)
                .frame(width: 40, height: 40)
            
            // Inner circle
            Circle()
                .stroke(crosshairColor.opacity(0.7), lineWidth: 1)
                .frame(width: 20, height: 20)
            
            // Center dot
            Circle()
                .fill(crosshairColor)
                .frame(width: blink ? 14 : 8, height: blink ? 14 : 8)
            
            // Blink pulse effect
            if blink {
                Circle()
                    .stroke(crosshairColor, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .opacity(0.6)
            }
            
            // Confidence ring
            Circle()
                .stroke(crosshairColor.opacity(0.2), lineWidth: 2)
                .frame(width: 80, height: 80)
        }
        .offset(
            x: x * 560 - 280,
            y: y * 760 - 380
        )
    }
}

// MARK: - Mock Eye Tracking Extension

extension AppModel {
    func simulateEyeTracking() {
        // We create the timer and capture it implicitly via the closure's parameter
        Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] timer in
            guard let self = self, self.isGameActive else {
                timer.invalidate() // Now this correctly references the timer instance
                return
            }
            
            withAnimation(.linear(duration: 0.033)) {
                self.eyeGazeX = Double.random(in: 0.1...0.9)
                self.eyeGazeY = Double.random(in: 0.1...0.9)
                self.eyeTrackingConfidence = Double.random(in: 0.75...0.99)
            }
        }
    }
    
    func simulateBlink() {
        self.registerBlink()
    }
}
