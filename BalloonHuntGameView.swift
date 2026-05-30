import SwiftUI

struct BalloonHuntGameView: View {
    @EnvironmentObject private var model: AppModel
    @State private var balloons: [Balloon] = []
    @State private var gameDisplayTimer: Timer?
    @State private var balloonSpawnTimer: Timer?
    @State private var gameStartTime: Date?
    @State private var lastBlinkTime: Date = Date()
    
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
                        
                        Text("Look & Blink to Pop")
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
                        blink: model.blinkDetected
                    )
                    
                    // Balloons
                    ForEach(balloons) { balloon in
                        BalloonView(balloon: balloon)
                            .position(
                                x: gameAreaMinX + balloon.x,
                                y: gameAreaMinY + balloon.y
                            )
                    }
                    
                    // Game info overlay
                    if balloons.isEmpty && model.gameTime > 5 {
                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.35))
                            
                            Text("Great Shot!")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("All balloons popped!")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
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
                
                // Instructions
                HStack(spacing: 8) {
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
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            // Eye Tracking Status
            if !model.isEyeTrackingAvailable {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                    
                    Text("Eye Tracking Offline")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text("Enable eye tracking to play")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(24)
                .background(Color.black.opacity(0.7))
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
        model.startGame(mode: .balloonHunt)
        gameStartTime = Date()
        
        // Spawn balloons
        spawnBalloon()
        balloonSpawnTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            spawnBalloon()
        }
        
        // Game update loop
        gameDisplayTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateGame()
        }
    }
    
    private func stopGame() {
        model.stopGame()
        gameDisplayTimer?.invalidate()
        balloonSpawnTimer?.invalidate()
    }
    
    private func spawnBalloon() {
        let newBalloon = Balloon(
            id: UUID(),
            x: CGFloat.random(in: 50...(gameAreaWidth - 50)),
            y: gameAreaHeight,
            size: CGFloat.random(in: 30...50),
            color: randomBalloonColor(),
            velocity: CGFloat.random(in: 40...80)
        )
        balloons.append(newBalloon)
    }
    
    private func updateGame() {
        // Update balloon positions
        balloons = balloons.map { balloon in
            var updated = balloon
            updated.y -= updated.velocity * 0.016 // 60 FPS
            return updated
        }
        
        // Remove balloons that left the screen
        balloons.removeAll { $0.y < -50 }
        
        // Limit balloons on screen
        if balloons.count > 15 {
            balloons.removeFirst()
        }
    }
    
    private func handleBlink() {
        // Check if blink is hitting any balloon
        let crosshairX = gameAreaMinX + (model.eyeGazeX * gameAreaWidth)
        let crosshairY = gameAreaMinY + (model.eyeGazeY * gameAreaHeight)
        
        for (index, balloon) in balloons.enumerated() {
            let balloonCenterX = gameAreaMinX + balloon.x
            let balloonCenterY = gameAreaMinY + balloon.y
            let distance = sqrt(pow(crosshairX - balloonCenterX, 2) + pow(crosshairY - balloonCenterY, 2))
            
            if distance < balloon.size / 2 {
                balloons.remove(at: index)
                model.recordBalloonPop()
                
                // Haptic feedback
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .default
                )
                
                break
            }
        }
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

// MARK: - Supporting Views & Models

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
            // Main balloon
            Circle()
                .fill(balloon.color)
                .frame(width: balloon.size, height: balloon.size)
                .overlay(
                    Circle()
                        .stroke(balloon.color.opacity(0.5), lineWidth: 1.5)
                )
            
            // Highlight/shine
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: balloon.size * 0.35, height: balloon.size * 0.35)
                .offset(x: -balloon.size * 0.15, y: -balloon.size * 0.15)
            
            // String
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
    
    var body: some View {
        ZStack {
            // Crosshair circle (outer)
            Circle()
                .stroke(Color(red: 0.31, green: 0.80, blue: 0.77).opacity(0.4), lineWidth: 1.5)
                .frame(width: 60, height: 60)
            
            // Crosshair circle (inner)
            Circle()
                .stroke(Color(red: 0.31, green: 0.80, blue: 0.77).opacity(0.6), lineWidth: 1)
                .frame(width: 30, height: 30)
            
            // Center dot
            Circle()
                .fill(Color(red: 0.40, green: 0.85, blue: 0.55))
                .frame(width: blink ? 12 : 8, height: blink ? 12 : 8)
            
            // Blink effect
            if blink {
                Circle()
                    .stroke(Color(red: 0.40, green: 0.85, blue: 0.55).opacity(0.6), lineWidth: 2)
                    .frame(width: 30, height: 30)
            }
        }
        .offset(
            x: x * 560 - 280,
            y: y * 760 - 380
        )
    }
}

// Mock eye tracking simulator for testing
extension AppModel {
    func simulateEyeTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            withAnimation(.linear(duration: 0.033)) {
                self.eyeGazeX = Double.random(in: 0.1...0.9)
                self.eyeGazeY = Double.random(in: 0.1...0.9)
                self.eyeTrackingConfidence = Double.random(in: 0.7...0.99)
            }
        }
    }
    
    func simulateBlink() {
        self.registerBlink()
    }
}
