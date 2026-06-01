import AppKit
import SwiftUI

final class AppModel: NSObject, ObservableObject, SmartSpectraRunnerDelegate {
    // MARK: - SDK & UI Properties
    @Published var frame: NSImage?
    @Published var metrics: [String] = ["Waiting for metrics..."]
    @Published var pulseRateText = "--"
    @Published var pulseConfidenceText = ""
    @Published var breathingRateText = "--"
    @Published var breathingConfidenceText = ""
    @Published var edaLevelText = "--"
    @Published var pulseRateTrendHistory: [Double] = []
    @Published var pulseTraceHistory: [Double] = []
    @Published var breathingTraceHistory: [Double] = []
    @Published var edaTraceHistory: [Double] = []
    @Published var hasLiveMetrics = false
    @Published var processingStatus = "not started"
    @Published var validationStatus = "waiting"
    @Published var errorMessage = ""
    @Published var diagnostics = "Frames: 0 | accepted: 0 | blocked: 0"
    @Published var lastMetricTime = "never"
    @Published var apiKey: String
    @Published var isRunning = false

    // MARK: - Bio-Feedback State
    @Published var isBiofeedbackActive: Bool = false
    @Published var stressScore: Double = 0.0
    @Published var stressLevel: StressLevel = .calm // NEW: Better categorization
    
    // MARK: - Stress & Emotion Tracking
    @Published var stressHistory: [Double] = []
    @Published var stressTimestamps: [Date] = []
    @Published var emotionalState: EmotionalState = .calm
    @Published var emotionIntensity: Double = 0.0
    @Published var detectedEmotion: String = "Calm"
    
    // MARK: - Eye Tracking
    @Published var eyeGazeX: Double = 0.5
    @Published var eyeGazeY: Double = 0.5
    @Published var blinkDetected: Bool = false
    @Published var eyeTrackingConfidence: Double = 0.0
    @Published var isEyeTrackingAvailable: Bool = true
    
    // MARK: - Game State
    @Published var gameMode: GameMode = .none
    @Published var gameScore: Int = 0
    @Published var balloonsPoppedInSession: Int = 0
    @Published var gameTime: Double = 0.0
    @Published var isGameActive: Bool = false
    @Published var gameDifficulty: GameDifficulty = .medium // NEW
    
    // MARK: - Session Stats
    @Published var sessionStartTime: Date?
    @Published var totalSessionTime: Double = 0.0
    @Published var highestStressInSession: Double = 0.0
    @Published var averageStressInSession: Double = 0.0
    
    // MARK: - Eye Tracking Calibration
    @Published var isCalibrating: Bool = false
    @Published var calibrationPoints: [CGPoint] = []
    
    // Internal values
    private var currentNumericalEDA: Double = 0.0
    private var currentNumericalBreathing: Double = 0.0
    private var currentNumericalPulse: Double = 0.0
    
    // Customizable Thresholds - ADJUSTED FOR EXTREME STRESS ONLY
    private let edaStressThreshold: Double = 0.08
    private let erraticBreathingThreshold: Double = 22.0
    private let elevatedPulseThreshold: Double = 90.0
    
    // FIXED: Increased threshold from 0.80 to 0.95 for extreme stress only
    private let extremeStressThreshold: Double = 0.95
    private let criticalStressThreshold: Double = 0.85
    
    private var stressHistoryMaxPoints = 300
    private var gameTimer: Timer?
    private var sessionTimer: Timer?

    private let runner = SmartSpectraRunner()

    override init() {
        apiKey = ProcessInfo.processInfo.environment["SMARTSPECTRA_API_KEY"] ?? ""
        super.init()
        runner.delegate = self
    }

    // MARK: - Lifecycle Controls
    func start() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmedAPIKey

        errorMessage = ""
        metrics = ["Waiting for metrics..."]
        pulseRateText = "--"
        pulseConfidenceText = ""
        breathingRateText = "--"
        breathingConfidenceText = ""
        edaLevelText = "--"
        pulseRateTrendHistory = []
        pulseTraceHistory = []
        breathingTraceHistory = []
        edaTraceHistory = []
        hasLiveMetrics = false
        lastMetricTime = "never"
        diagnostics = "Frames: 0 | accepted: 0 | blocked: 0"
        
        // Reset session tracking
        isBiofeedbackActive = false
        stressScore = 0.0
        stressLevel = .calm
        currentNumericalEDA = 0.0
        currentNumericalBreathing = 0.0
        currentNumericalPulse = 0.0
        stressHistory = []
        stressTimestamps = []
        emotionalState = .calm
        emotionIntensity = 0.0
        sessionStartTime = Date()
        totalSessionTime = 0.0
        highestStressInSession = 0.0
        
        // Start session timer
        startSessionTimer()
        
        if let message = runner.start(withAPIKey: trimmedAPIKey) {
            errorMessage = message
            isRunning = false
            return
        }
        isRunning = true
    }

    func stop() {
        runner.stop()
        isRunning = false
        processingStatus = "stopped"
        isBiofeedbackActive = false
        stopGame()
        stopSessionTimer()
    }

    // MARK: - SmartSpectraRunnerDelegate
    func smartSpectraRunnerDidUpdateFrame(_ image: NSImage) {
        DispatchQueue.main.async {
            self.frame = image
        }
    }

    func smartSpectraRunnerDidUpdateStatus(_ processing: String, validation: String) {
        DispatchQueue.main.async {
            if !processing.isEmpty {
                self.processingStatus = processing
            }
            if !validation.isEmpty {
                self.validationStatus = validation
            }
        }
    }

    func smartSpectraRunnerDidUpdateBreathingTrace(
        _ breathingTrace: [NSNumber],
        arterialPressureTrace: [NSNumber],
        edaTrace: [NSNumber],
        timestampUs: Int64
    ) {
        DispatchQueue.main.async {
            self.append(breathingTrace, to: \.breathingTraceHistory)
            self.append(arterialPressureTrace, to: \.pulseTraceHistory)
            self.append(edaTrace, to: \.edaTraceHistory, maxPoints: 1024)
            self.updateEdaLevel(from: edaTrace)
            
            if !breathingTrace.isEmpty || !arterialPressureTrace.isEmpty || !edaTrace.isEmpty {
                self.hasLiveMetrics = true
                self.lastMetricTime = "\(timestampUs) us"
            }
        }
    }

    func smartSpectraRunnerDidUpdateMetrics(_ metrics: [String], timestampUs: Int64) {
        guard !metrics.isEmpty else { return }

        DispatchQueue.main.async {
            self.updateVitalDisplays(from: metrics)
            let tilePrefixes = ["Pulse rate:", "Breathing rate:", "EDA level:"]
            self.metrics = metrics.filter { line in
                !tilePrefixes.contains(where: line.hasPrefix)
            }
            self.hasLiveMetrics = true
            self.lastMetricTime = "\(timestampUs) us"
        }
    }

    func smartSpectraRunnerDidUpdateDiagnostics(_ diagnostics: String) {
        DispatchQueue.main.async {
            self.diagnostics = diagnostics
        }
    }

    func smartSpectraRunnerDidFail(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            if self.isRunning {
                self.stop()
            }
            self.processingStatus = "failed"
        }
    }

    deinit {
        runner.stop()
        gameTimer?.invalidate()
        sessionTimer?.invalidate()
    }

    // MARK: - Private Metric Parsers
    private func updateVitalDisplays(from metrics: [String]) {
        for metric in metrics {
            if metric.hasPrefix("Pulse rate:") {
                updateRate(
                    metric,
                    value: \.pulseRateText,
                    confidence: \.pulseConfidenceText,
                    trend: \.pulseRateTrendHistory
                )
            } else if metric.hasPrefix("Breathing rate:") {
                updateRate(metric, value: \.breathingRateText, confidence: \.breathingConfidenceText)
            } else if metric.hasPrefix("EDA level:") {
                updateEdaLevel(metric)
            }
        }
    }

    private func updateEdaLevel(_ line: String) {
        guard let colon = line.firstIndex(of: ":") else { return }
        
        let remainder = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard let firstToken = remainder.split(separator: " ").first,
              let numericValue = Double(firstToken) else { return }
        
        edaLevelText = formattedEdaValue(numericValue)
        currentNumericalEDA = numericValue
        evaluateComposure()
    }

    private func updateEdaLevel(from samples: [NSNumber]) {
        guard let latestSample = samples.last?.doubleValue else { return }
        
        edaLevelText = formattedEdaValue(latestSample)
        currentNumericalEDA = latestSample
        evaluateComposure()
    }

    private func formattedEdaValue(_ value: Double) -> String {
        String(format: "%+.3f", value)
    }

    private func updateRate(
        _ line: String,
        value valueKeyPath: ReferenceWritableKeyPath<AppModel, String>,
        confidence confidenceKeyPath: ReferenceWritableKeyPath<AppModel, String>,
        trend trendKeyPath: ReferenceWritableKeyPath<AppModel, [Double]>? = nil
    ) {
        guard let colon = line.firstIndex(of: ":") else { return }

        let remainder = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard let firstToken = remainder.split(separator: " ").first,
              let numericValue = Double(firstToken) else { return }

        self[keyPath: valueKeyPath] = "\(Int(numericValue.rounded()))"
        
        if let trendKeyPath {
            append(numericValue, to: trendKeyPath)
        }

        if let open = line.lastIndex(of: "("), let close = line.lastIndex(of: ")"), open < close {
            let confidence = line[line.index(after: open)..<close]
            self[keyPath: confidenceKeyPath] = String(confidence)
        }
        
        if valueKeyPath == \AppModel.breathingRateText {
            currentNumericalBreathing = numericValue
            evaluateComposure()
        }
        
        if valueKeyPath == \AppModel.pulseRateText {
            currentNumericalPulse = numericValue
            evaluateComposure()
        }
    }

    private func append(
        _ samples: [NSNumber],
        to historyKeyPath: ReferenceWritableKeyPath<AppModel, [Double]>,
        maxPoints: Int = 80
    ) {
        guard !samples.isEmpty else { return }
        var history = self[keyPath: historyKeyPath]
        history.append(contentsOf: samples.map(\.doubleValue))
        if history.count > maxPoints {
            history.removeFirst(history.count - maxPoints)
        }
        self[keyPath: historyKeyPath] = history
    }

    private func append(_ sample: Double, to historyKeyPath: ReferenceWritableKeyPath<AppModel, [Double]>) {
        var history = self[keyPath: historyKeyPath]
        history.append(sample)
        if history.count > 80 {
            history.removeFirst(history.count - 80)
        }
        self[keyPath: historyKeyPath] = history
    }
    
    // MARK: - Bio-Feedback & Emotional Detection Logic
    private func evaluateComposure() {
        guard currentNumericalBreathing > 0 else { return }

        let edaFactor = min(abs(currentNumericalEDA) / edaStressThreshold, 1.0)
        let breathFactor = min(currentNumericalBreathing / erraticBreathingThreshold, 1.0)
        
        stressScore = (edaFactor + breathFactor) / 2.0
        
        // Update stress level
        updateStressLevel()
        
        // Record stress history
        recordStressDataPoint(stressScore)
        
        // Update emotional state
        updateEmotionalState()
        
        // FIXED: Only trigger at extreme stress (0.95+) instead of 0.80
        if stressScore > extremeStressThreshold && !isBiofeedbackActive {
            triggerBiofeedback()
        }
    }
    
    private func updateStressLevel() {
        if stressScore < 0.3 {
            stressLevel = .calm
        } else if stressScore < 0.6 {
            stressLevel = .moderate
        } else if stressScore < 0.85 {
            stressLevel = .elevated
        } else {
            stressLevel = .critical
        }
    }
    
    private func updateEmotionalState() {
        let pulseNormalized = min(currentNumericalPulse / 120.0, 1.0)
        let edaNormalized = min(abs(currentNumericalEDA) / 0.1, 1.0)
        let breathingNormalized = min(currentNumericalBreathing / 25.0, 1.0)
        
        let emotionScore = (pulseNormalized + edaNormalized + breathingNormalized) / 3.0
        emotionIntensity = emotionScore
        
        if emotionScore < 0.3 {
            emotionalState = .calm
            detectedEmotion = "Calm"
        } else if emotionScore < 0.5 {
            emotionalState = .focused
            detectedEmotion = "Focused"
        } else if emotionScore < 0.7 {
            emotionalState = .anxious
            detectedEmotion = "Anxious"
        } else {
            emotionalState = .stressed
            detectedEmotion = "Stressed"
        }
    }
    
    private func recordStressDataPoint(_ value: Double) {
        var history = stressHistory
        var timestamps = stressTimestamps
        
        history.append(value)
        timestamps.append(Date())
        
        if history.count > stressHistoryMaxPoints {
            history.removeFirst(history.count - stressHistoryMaxPoints)
            timestamps.removeFirst(timestamps.count - stressHistoryMaxPoints)
        }
        
        stressHistory = history
        stressTimestamps = timestamps
        
        // Update session stats
        if value > highestStressInSession {
            highestStressInSession = value
        }
        
        if !history.isEmpty {
            averageStressInSession = history.reduce(0, +) / Double(history.count)
        }
    }

    private func triggerBiofeedback() {
        DispatchQueue.main.async {
            self.isBiofeedbackActive = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
            self.isBiofeedbackActive = false
        }
    }
    
    // MARK: - Session Management
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.totalSessionTime += 1.0
        }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    // MARK: - Eye Tracking
    func updateEyeGaze(x: Double, y: Double, confidence: Double) {
        DispatchQueue.main.async {
            self.eyeGazeX = max(0.0, min(1.0, x))
            self.eyeGazeY = max(0.0, min(1.0, y))
            self.eyeTrackingConfidence = max(0.0, min(1.0, confidence))
        }
    }
    
    func registerBlink() {
        DispatchQueue.main.async {
            self.blinkDetected = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.blinkDetected = false
            }
        }
    }
    
    // MARK: - Eye Tracking Calibration
    func startCalibration() {
        isCalibrating = true
        calibrationPoints = []
    }
    
    func recordCalibrationPoint() {
        calibrationPoints.append(CGPoint(x: eyeGazeX, y: eyeGazeY))
        if calibrationPoints.count >= 5 {
            finishCalibration()
        }
    }
    
    func finishCalibration() {
        isCalibrating = false
        // Calibration data stored in calibrationPoints
    }
    
    // MARK: - Game Controls
    func startGame(mode: GameMode, difficulty: GameDifficulty = .medium) {
        gameMode = mode
        gameDifficulty = difficulty
        gameScore = 0
        balloonsPoppedInSession = 0
        gameTime = 0.0
        isGameActive = true
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.gameTime += 0.016
        }
    }
    
    func stopGame() {
        gameTimer?.invalidate()
        isGameActive = false
        gameMode = .none
    }
    
    func recordBalloonPop() {
        gameScore += (Int(gameDifficulty.pointMultiplier) * 10)
        balloonsPoppedInSession += 1
    }
}

// MARK: - Supporting Types
enum GameMode {
    case none
    case balloonHunt
}

enum GameDifficulty: CustomStringConvertible {
    case easy
    case medium
    case hard
    case extreme
    
    var description: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }
    
    // ... keep your existing balloonSpawnInterval, balloonVelocityRange, etc.
    var balloonSpawnInterval: TimeInterval {
        switch self {
        case .easy: return 1.2
        case .medium: return 0.8
        case .hard: return 0.5
        case .extreme: return 0.3
        }
    }
    
    var balloonVelocityRange: ClosedRange<CGFloat> {
        switch self {
        case .easy: return 30...50
        case .medium: return 40...80
        case .hard: return 60...120
        case .extreme: return 100...180
        }
    }
    
    var pointMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.5
        case .extreme: return 5.0
        }
    }
}

enum StressLevel {
    case calm
    case moderate
    case elevated
    case critical
    
    var color: Color {
        switch self {
        case .calm:
            return Color(red: 0.40, green: 0.85, blue: 0.55) // mint
        case .moderate:
            return Color(red: 0.31, green: 0.80, blue: 0.77) // teal
        case .elevated:
            return Color(red: 1.0, green: 0.82, blue: 0.35) // amber
        case .critical:
            return Color(red: 1.0, green: 0.42, blue: 0.42) // coral
        }
    }
    
    var description: String {
        switch self {
        case .calm: return "Calm"
        case .moderate: return "Moderate"
        case .elevated: return "Elevated"
        case .critical: return "Critical"
        }
    }
}

enum EmotionalState {
    case calm
    case focused
    case anxious
    case stressed
    
    var color: Color {
        switch self {
        case .calm:
            return Color(red: 0.40, green: 0.85, blue: 0.55)
        case .focused:
            return Color(red: 0.31, green: 0.80, blue: 0.77)
        case .anxious:
            return Color(red: 1.0, green: 0.82, blue: 0.35)
        case .stressed:
            return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
    }
}
