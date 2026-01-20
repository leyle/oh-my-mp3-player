
import Foundation
import Speech
import Combine

struct TranscriptionSegment: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let words: [TranscriptionWord]
    
    // Helper to check if a time falls within this segment
    func contains(_ time: TimeInterval) -> Bool {
        return time >= startTime && time < (startTime + duration)
    }
}

struct TranscriptionWord: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval
}

// ...

enum TranscriptionStatus: Equatable {
    case idle
    case transcribing(segments: [TranscriptionSegment])
    case completed(segments: [TranscriptionSegment])
    case error(String)
}

actor TranscriptionService {
    static let shared = TranscriptionService()
    
    private let recognizer: SFSpeechRecognizer?
    private var activeTask: SFSpeechRecognitionTask?
    
    private init() {
        // Use default locale or English if specified by user requirements
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    // MARK: - Core API
    
    func transcribe(url: URL) -> AsyncThrowingStream<[TranscriptionSegment], Error> {
        return AsyncThrowingStream { continuation in
            Task {
                // 1. Check Cache First
                if let cached = loadCache(for: url) {
                    continuation.yield(cached)
                    continuation.finish()
                    return
                }
                
                // 2. Request Authorization
                let authorized = await requestPermission()
                guard authorized else {
                    continuation.finish(throwing: NSError(domain: "Transcription", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission denied."]))
                    return
                }
                
                // 3. Setup Request
                guard let recognizer = self.recognizer, recognizer.isAvailable else {
                    continuation.finish(throwing: NSError(domain: "Transcription", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available."]))
                    return
                }
                
                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = true
                 request.requiresOnDeviceRecognition = false // Allow network if needed for better accuracy, or true for privacy/offline. Let's default to system choice.
                
                // 4. Start Task
                activeTask?.cancel()
                activeTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    guard let result = result else { return }
                    
                    // Group segments into phrases
                    var phrases: [TranscriptionSegment] = []
                    let rawSegments = result.bestTranscription.segments
                    
                    var currentPhraseWords: [TranscriptionWord] = []
                    var phraseStartTime: TimeInterval = 0
                    var lastWordEndTime: TimeInterval = 0
                    
                    // Keep track of phrase index for stable IDs
                    var phraseIndex = 0
                    
                    for (index, segment) in rawSegments.enumerated() {
                        let start = segment.timestamp
                        let duration = max(segment.duration, 0.3)
                        
                        // STABLE ID: Index-based. 
                        // The 'index' in rawSegments is the absolute word index.
                        // "word_0", "word_1" ... never changes for the same position.
                        let word = TranscriptionWord(
                            id: "word_\(index)", 
                            text: segment.substring,
                            startTime: start,
                            duration: duration
                        )
                        let end = start + duration
                        
                        let delay = start - lastWordEndTime
                        let isPause = (index > 0) && (delay > 0.8)
                        let isTooLong = currentPhraseWords.count > 20
                        
                        if index == 0 || isPause || isTooLong {
                            // Commit previous phrase
                            if !currentPhraseWords.isEmpty {
                                let text = currentPhraseWords.map { $0.text }.joined(separator: " ")
                                let phraseDuration = lastWordEndTime - phraseStartTime
                                phrases.append(TranscriptionSegment(
                                    // STABLE ID: Phrase index
                                    id: "phrase_\(phraseIndex)",
                                    text: text,
                                    startTime: phraseStartTime,
                                    duration: phraseDuration,
                                    words: currentPhraseWords
                                ))
                                phraseIndex += 1
                            }
                            
                            // Start new
                            currentPhraseWords = [word]
                            phraseStartTime = start
                        } else {
                            currentPhraseWords.append(word)
                        }
                        
                        lastWordEndTime = end
                    }
                    
                    // Commit final
                    if !currentPhraseWords.isEmpty {
                        let text = currentPhraseWords.map { $0.text }.joined(separator: " ")
                        let phraseDuration = lastWordEndTime - phraseStartTime
                        phrases.append(TranscriptionSegment(
                            id: "phrase_\(phraseIndex)",
                            text: text,
                            startTime: phraseStartTime,
                            duration: phraseDuration,
                            words: currentPhraseWords
                        ))
                    }
                    
                    continuation.yield(phrases)
                    
                    if result.isFinal {
                        // Cache result
                        Task { [weak self] in
                            await self?.saveCache(for: url, segments: phrases)
                        }
                        continuation.finish()
                    }
                }
            }
        }
    }
    
    func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }
    
    // MARK: - Permission
    
    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    // MARK: - Caching
    
    private var cacheDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("TranscriptionCache")
    }
    
    private func loadCache(for fileURL: URL) -> [TranscriptionSegment]? {
        guard let cacheDir = cacheDirectory else { return nil }
        // Use a hash of the file path or name as key
        let key = fileURL.lastPathComponent // Simple key for now
        let cacheFile = cacheDir.appendingPathComponent(key).appendingPathExtension("json")
        
        guard FileManager.default.fileExists(atPath: cacheFile.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: cacheFile)
            let segments = try JSONDecoder().decode([TranscriptionSegment].self, from: data)
            return segments
        } catch {
            print("Failed to load cache: \(error)")
            return nil
        }
    }
    
    private func saveCache(for fileURL: URL, segments: [TranscriptionSegment]) {
        guard let cacheDir = cacheDirectory else { return }
        
        do {
            if !FileManager.default.fileExists(atPath: cacheDir.path) {
                try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            }
            
            let key = fileURL.lastPathComponent
            let cacheFile = cacheDir.appendingPathComponent(key).appendingPathExtension("json")
            
            let data = try JSONEncoder().encode(segments)
            try data.write(to: cacheFile)
        } catch {
            print("Failed to save cache: \(error)")
        }
    }
    
    func deleteCache(for fileURL: URL) {
        guard let cacheDir = cacheDirectory else { return }
        let key = fileURL.lastPathComponent
        let cacheFile = cacheDir.appendingPathComponent(key).appendingPathExtension("json")
        
        try? FileManager.default.removeItem(at: cacheFile)
    }
}
