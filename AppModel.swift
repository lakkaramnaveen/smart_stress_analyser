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
    
    // MARK: - Stress & Emotion Tracking
    @Published var stressHistory: [Double] = [] // For graphing
    @Published var stressTimestamps: [Date] = []
    @Published var emotionalState: EmotionalState = .calm
    @Published var emotionIntensity: Double = 0.0 // 0.0 to 1.0
    @Published var detectedEmotion: String = "Calm" // Human readable
    
    // MARK: - Eye Tracking
    @Published var eyeGazeX: Double = 0.5 // 0.0 to 1.0 (normalized)
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
    
    // Internal values for evaluation
    private var currentNumericalEDA: Double = 0.0
    private var currentNumericalBreathing: Double = 0.0
    private var currentNumericalPulse: Double = 0.0
    
    // Customizable Thresholds
    private let edaStressThreshold: Double = 0.08
    private let erraticBreathingThreshold: Double = 22.0 // breaths per minute
    private let elevatedPulseThreshold: Double = 90.0 // bpm
    
    private var stressHistoryMaxPoints = 300 // 5 minutes of data at 1 sample/sec
    private var gameTimer: Timer?

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
        
        // Reset Bio-Feedback state on new session
        isBiofeedbackActive = false
        stressScore = 0.0
        currentNumericalEDA = 0.0
        currentNumericalBreathing = 0.0
        currentNumericalPulse = 0.0
        stressHistory = []
        stressTimestamps = []
        emotionalState = .calm
        emotionIntensity = 0.0
        
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
    }

    // MARK: - SmartSpectraRunnerDelegate
    func smartSpectraRunnerDidUpdateFrame(_ image: NSImage) {
        frame = image
    }

    func smartSpectraRunnerDidUpdateStatus(_ processing: String, validation: String) {
        if !processing.isEmpty {
            processingStatus = processing
        }
        if !validation.isEmpty {
            validationStatus = validation
        }
    }

    func smartSpectraRunnerDidUpdateBreathingTrace(
        _ breathingTrace: [NSNumber],
        arterialPressureTrace: [NSNumber],
        edaTrace: [NSNumber],
        timestampUs: Int64
    ) {
        append(breathingTrace, to: \.breathingTraceHistory)
        append(arterialPressureTrace, to: \.pulseTraceHistory)
        append(edaTrace, to: \.edaTraceHistory, maxPoints: 1024)
        updateEdaLevel(from: edaTrace)
        
        if !breathingTrace.isEmpty || !arterialPressureTrace.isEmpty || !edaTrace.isEmpty {
            hasLiveMetrics = true
            lastMetricTime = "\(timestampUs) us"
        }
    }

    func smartSpectraRunnerDidUpdateMetrics(_ metrics: [String], timestampUs: Int64) {
        guard !metrics.isEmpty else { return }

        updateVitalDisplays(from: metrics)
        let tilePrefixes = ["Pulse rate:", "Breathing rate:", "EDA level:"]
        self.metrics = metrics.filter { line in
            !tilePrefixes.contains(where: line.hasPrefix)
        }
        hasLiveMetrics = true
        lastMetricTime = "\(timestampUs) us"
    }

    func smartSpectraRunnerDidUpdateDiagnostics(_ diagnostics: String) {
        self.diagnostics = diagnostics
    }

    func smartSpectraRunnerDidFail(_ message: String) {
        errorMessage = message
        if isRunning {
            stop()
        }
        processingStatus = "failed"
    }

    deinit {
        runner.stop()
        gameTimer?.invalidate()
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
        
        // Track breathing for composure
        if valueKeyPath == \AppModel.breathingRateText {
            currentNumericalBreathing = numericValue
            evaluateComposure()
        }
        
        // Track pulse for emotional state
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
        
        // Record stress history for graphing
        recordStressDataPoint(stressScore)
        
        // Determine emotional state
        updateEmotionalState()
        
        // Trigger biofeedback if stress is too high
        if stressScore > 0.80 && !isBiofeedbackActive {
            triggerBiofeedback()
        }
    }
    
    private func updateEmotionalState() {
        // Map vital signs to emotional states
        let pulseNormalized = min(currentNumericalPulse / 120.0, 1.0) // 120 bpm max
        let edaNormalized = min(abs(currentNumericalEDA) / 0.1, 1.0)
        let breathingNormalized = min(currentNumericalBreathing / 25.0, 1.0)
        
        let emotionScore = (pulseNormalized + edaNormalized + breathingNormalized) / 3.0
        emotionIntensity = emotionScore
        
        // Classify emotion based on vitals
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
    }

    private func triggerBiofeedback() {
        DispatchQueue.main.async {
            self.isBiofeedbackActive = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
            self.isBiofeedbackActive = false
        }
    }
    
    // MARK: - Eye Tracking Simulation
    func updateEyeGaze(x: Double, y: Double, confidence: Double) {
        DispatchQueue.main.async {
            self.eyeGazeX = x
            self.eyeGazeY = y
            self.eyeTrackingConfidence = confidence
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
    
    // MARK: - Game Controls
    func startGame(mode: GameMode) {
        gameMode = mode
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
        gameScore += 10
        balloonsPoppedInSession += 1
    }
}

// MARK: - Supporting Types
enum GameMode {
    case none
    case balloonHunt
}

enum EmotionalState {
    case calm
    case focused
    case anxious
    case stressed
    
    var color: Color {
        switch self {
        case .calm:
            return Color(red: 0.40, green: 0.85, blue: 0.55) // mint
        case .focused:
            return Color(red: 0.31, green: 0.80, blue: 0.77) // teal
        case .anxious:
            return Color(red: 1.0, green: 0.82, blue: 0.35) // yellow
        case .stressed:
            return Color(red: 1.0, green: 0.42, blue: 0.42) // coral
        }
    }
}
