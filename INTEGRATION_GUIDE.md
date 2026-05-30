# Composure v2.0 - Enhanced Bio-Adaptive Workspace
## Integration Guide & Feature Documentation

---

## 🎯 Overview

The enhanced Composure app introduces four major new capabilities:

1. **Real-time Breathing Pacer** - Interactive guidance with live metrics display
2. **Stress Visualization** - Real-time graph showing stress trajectory with AI insights
3. **Emotional Detection** - Automatic emotion classification based on biometric signals
4. **Balloon Hunt Game** - Eye-tracking enabled interactive game with blink-to-shoot mechanics

---

## 📁 Files & Architecture

### Core Files (Updated)
- `AppModel_Enhanced.swift` - Updated data model with eye tracking, game state, and emotion detection
- `ContentView_Enhanced.swift` - Main UI with tab-based sidebar navigation
- `BreathingPacerView_Enhanced.swift` - Interactive breathing guidance with live metrics

### New Feature Files
- `StressVisualizationView.swift` - Real-time stress tracking graph
- `EmotionalDetectorView.swift` - Emotional state analysis and display
- `BalloonHuntGameView.swift` - Interactive game with eye tracking integration

---

## 🔄 Data Flow Architecture

```
SmartSpectra SDK
    ↓
AppModel (Observable Object)
    ├─ Vital Signals (Heart, Breathing, EDA)
    ├─ Stress Calculation (edaFactor + breathFactor)
    ├─ Emotional State Classification
    ├─ Eye Gaze Data (x, y, confidence)
    ├─ Blink Events
    └─ Game State & Score
    ↓
Content Views
    ├─ Main Workspace (Video + Metrics)
    ├─ Sidebar Tabs
    │   ├─ Controls Panel
    │   ├─ Stress Visualization
    │   ├─ Emotional Detector
    │   └─ Game Panel
    └─ Overlays
        ├─ Breathing Pacer (when stress > 80%)
        └─ Balloon Hunt Game (fullscreen)
```

---

## 🫁 Enhanced Breathing Pacer

### Features
- **Real-time Metrics Display**: Shows current heart rate and breathing rate during breathing cycles
- **Breath Cycle Progress Bar**: Visual feedback on inhale/exhale timing (0-100%)
- **Stress Level Indicator**: Live stress score with emotional state color coding
- **Automatic Triggering**: Activates when combined stress score exceeds 80%
- **Auto-dismiss**: Automatically closes after 60 seconds (6 breathing cycles)

### Implementation Details
```swift
// Triggered automatically when:
if stressScore > 0.80 && !isBiofeedbackActive {
    triggerBiofeedback()  // Activates breathing pacer
    // Auto-dismisses after 60 seconds
}

// Breathing cycles: 4sec inhale + 6sec exhale = 10sec cycle
// Repeats every 10 seconds until dismissed
```

---

## 📊 Stress Visualization View

### Features
- **Real-time Graph**: Shows last 5 minutes of stress data (300 samples)
- **Statistics Cards**: Peak, Average, Minimum stress levels + Trend direction
- **AI Insights**: Dynamic recommendations based on stress level
- **Color Coding**:
  - 🟢 Green (< 30%) - Calm
  - 🟡 Amber (30-60%) - Moderate
  - 🔴 Red (> 60%) - Elevated

### Data Structure
```swift
@Published var stressHistory: [Double] = []        // 0.0 to 1.0
@Published var stressTimestamps: [Date] = []      // For time-based analysis
private var stressHistoryMaxPoints = 300           // 5 minutes @ 1 Hz
```

### Insights Logic
- < 30%: "Excellent composure. Great baseline."
- 30-60%: "Mild stress. Consider a brief pause."
- 60-80%: "Elevated stress. Use breathing pacer."
- > 80%: "High stress. Activate breathing guidance."

---

## 🧠 Emotional Detector

### Classification Algorithm
Emotional state is calculated from three vital factors:

```swift
pulseNormalized = min(currentPulse / 120.0, 1.0)
edaNormalized = min(abs(currentEDA) / 0.1, 1.0)
breathingNormalized = min(currentBreathing / 25.0, 1.0)

emotionScore = (pulseNormalized + edaNormalized + breathingNormalized) / 3.0

States:
- emotionScore < 0.3:  CALM      (Green)
- 0.3 - 0.5:           FOCUSED   (Teal)
- 0.5 - 0.7:           ANXIOUS   (Amber)
- > 0.7:               STRESSED  (Red)
```

### Features
- **Main Emotion Display**: Large visual with icon and intensity
- **Emotion Spectrum**: Shows all 4 emotion states with highlighting
- **Vital Signs Summary**: Quick view of contributing factors
- **AI Analysis**: Personalized feedback based on emotion and intensity

### View Components
- Emotional state icon (Leaf, Target, Exclamation, Flame)
- Intensity bar (0-100%)
- Contributing vitals (Heart, Breath, EDA)
- Dynamic analysis text

---

## 🎮 Balloon Hunt Game

### Core Mechanics

#### Eye Tracking Integration
```swift
// Eye gaze mapped to screen coordinates (0.0 to 1.0 normalized)
eyeGazeX: Double      // Horizontal position
eyeGazeY: Double      // Vertical position
eyeTrackingConfidence: Double  // 0.0 to 1.0 (tracking quality)

// Position on screen:
crosshairX = gameAreaMinX + (eyeGazeX * gameAreaWidth)
crosshairY = gameAreaMinY + (eyeGazeY * gameAreaHeight)
```

#### Blink Detection for Shooting
```swift
// When blink detected:
registerBlink()  // Sets blinkDetected = true for 100ms

// Collision detection checks if crosshair is within balloon radius
if distance < balloon.size / 2 {
    balloons.remove(at: index)
    model.recordBalloonPop()  // +10 points
}
```

#### Balloon Physics
```swift
struct Balloon {
    var x: CGFloat           // 0 to gameAreaWidth
    var y: CGFloat           // gameAreaHeight (bottom) to -50 (off-screen)
    let size: CGFloat        // 30-50 points
    let color: Color         // Random from 5 colors
    let velocity: CGFloat    // 40-80 points/sec (upward)
}

// Update each frame (60 FPS):
balloon.y -= velocity * deltaTime
```

### Game Features
- **Dynamic Spawning**: New balloon every 0.8 seconds
- **Score Tracking**: +10 points per balloon
- **Visual Crosshair**: Shows eye gaze position with blink indicator
- **Screen Management**: Balloons despawn at top, game limits to 15 on-screen
- **Real-time Stats**: Score, time, balloons popped

### Game Loop
```swift
startGame()
├─ Initialize game state (score = 0, time = 0)
├─ Start spawn timer (0.8 sec intervals)
└─ Start update loop (16ms = 60 FPS)

Update cycle:
├─ Move all balloons up
├─ Remove off-screen balloons
├─ Check blink collision detection
└─ Update UI

stopGame()
├─ Clear timers
└─ Reset game state
```

---

## 👁️ Eye Tracking Integration

### Mock/Simulation Mode
For testing without real eye tracking hardware:

```swift
// Enable simulation
model.simulateEyeTracking()  // Random eye movements every 16ms

// Simulate blinks
model.simulateBlink()        // Triggers blink event
```

### Real SDK Integration Points
When integrating with SmartSpectra eye tracking module:

```swift
// In AppModel delegate methods:
func smartSpectraRunnerDidUpdateEyeGaze(_ x: Double, _ y: Double, confidence: Double) {
    DispatchQueue.main.async {
        self.updateEyeGaze(x: x, y: y, confidence: confidence)
    }
}

func smartSpectraRunnerDidDetectBlink() {
    DispatchQueue.main.async {
        self.registerBlink()
    }
}
```

### Expected Data Format
- **X/Y Position**: Normalized coordinates (0.0 to 1.0)
- **Confidence**: Quality score (0.0 to 1.0)
- **Blink Duration**: Typically 100-150ms
- **Blink Frequency**: 15-20 blinks/minute in relaxed state

---

## 🎨 UI/UX Design System

### Color Palette
```swift
coral = Color(red: 1.0, green: 0.42, blue: 0.42)    // #FF6B6B
teal = Color(red: 0.31, green: 0.80, blue: 0.77)    // #4FCCC5
mint = Color(red: 0.40, green: 0.85, blue: 0.55)    // #66D88F
amber = Color(red: 1.0, green: 0.82, blue: 0.35)    // #FFD146
slate = Color(white: 0.15)                           // #262626
```

### Animation Timing
- **Breathing Cycles**: 4s inhale, 6s exhale
- **Transitions**: 0.3-0.5s easeInOut
- **Game Updates**: 16ms (60 FPS)
- **Blink Feedback**: 100ms pulse

---

## 📊 Performance Metrics

### Data Storage
- **Stress History**: 300 points (5 minutes @ 1 Hz)
- **Pulse Trace**: 80 points rolling buffer
- **Breathing Trace**: 80 points rolling buffer
- **EDA Trace**: 1024 points (longer baseline)

### Game Performance
- **Balloon Limit**: Max 15 on-screen
- **Update Rate**: 60 FPS (16ms per frame)
- **Spawn Rate**: 1 balloon per 0.8 seconds
- **Memory**: ~2-3 MB for all game state + history

---

## 🚀 Integration Checklist

### Step 1: Replace Files
- [ ] Replace `AppModel.swift` with `AppModel_Enhanced.swift`
- [ ] Replace `ContentView.swift` with `ContentView_Enhanced.swift`
- [ ] Replace `BreathingPacerView.swift` with `BreathingPacerView_Enhanced.swift`

### Step 2: Add New Files
- [ ] Add `StressVisualizationView.swift`
- [ ] Add `EmotionalDetectorView.swift`
- [ ] Add `BalloonHuntGameView.swift`

### Step 3: Update App Entry Point
```swift
@main
struct SmartSpectraSwiftApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 680)
        }
    }
}
```

### Step 4: Connect Eye Tracking (If Available)
Add to SmartSpectraRunner delegate:
```swift
func smartSpectraRunnerDidUpdateEyeGaze(...) { ... }
func smartSpectraRunnerDidDetectBlink() { ... }
```

### Step 5: Test
- [ ] Launch breathing pacer (trigger stress > 80%)
- [ ] Check stress graph updates in real-time
- [ ] Verify emotional state changes with vitals
- [ ] Play Balloon Hunt game
- [ ] Test eye tracking with simulation

---

## 🔧 Advanced Configuration

### Stress Thresholds
```swift
private let edaStressThreshold: Double = 0.08          // EDA level
private let erraticBreathingThreshold: Double = 22.0   // BPM
```

### Emotional State Normalization
```swift
pulseNormalized max: 120 BPM
edaNormalized max: 0.1 (EDA level)
breathingNormalized max: 25 BPM
```

### Game Tuning
- Balloon spawn interval: 0.8 seconds (adjust for difficulty)
- Balloon velocity: 40-80 pts/sec (adjust for difficulty)
- Balloon size: 30-50 points (visual size)

---

## 📱 Screen Requirements

- **Minimum Resolution**: 1040x680
- **Optimal Resolution**: 1920x1080
- **Sidebar Width**: 320 points
- **Game Area Width**: 600 points
- **Game Area Height**: 800 points

---

## 🐛 Troubleshooting

### Breathing Pacer Not Showing
- Check: `model.stressScore > 0.80`
- Check: `model.isBiofeedbackActive == true`
- Verify SDK is providing real-time vitals

### Stress Graph Not Updating
- Ensure `recordStressDataPoint()` is called
- Check history max size (300 points)
- Verify timestamps are being recorded

### Game Crosshair Not Moving
- Verify eye tracking is enabled
- Check `eyeGazeX` and `eyeGazeY` values (0.0-1.0)
- Ensure eye tracking confidence > 0.5

### Balloons Not Being Popped
- Check blink detection is firing
- Verify collision calculation distance < radius
- Confirm game is in active state

---

## 📚 References

### Vital Sign Ranges (Typical)
- **Heart Rate**: 60-100 BPM (resting), 100-140+ (stressed)
- **Breathing Rate**: 12-20 BPM (resting), 20-30+ (stressed)
- **EDA (Electrodermal Activity)**: 0.0-5.0 µS (varies widely)

### Eye Tracking Standards
- **Gaze Accuracy**: ±0.5-1.0 degrees
- **Sampling Rate**: 30-60 Hz typical
- **Latency**: 20-50ms typical

---

## 🎓 Learning Resources

- SwiftUI Animation Guide: https://developer.apple.com/tutorials/swiftui
- Core Motion for Haptics: https://developer.apple.com/documentation/coremotionhaptics
- Performance Optimization: https://developer.apple.com/videos/play/wwdc2023/10160/

---

**Version**: 2.0  
**Last Updated**: May 2026  
**Compatibility**: iOS 15+, macOS 12+
