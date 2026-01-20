//
//  AudioService.swift
//  LocalMP3Player
//
//  Low-level audio service using AVFoundation for playback control.
//

import Foundation
import AVFoundation
import Combine

/// Protocol for audio service delegate callbacks
protocol AudioServiceDelegate: AnyObject {
    func audioServiceDidFinishPlaying()
    func audioServiceDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval)
}

/// Low-level audio service wrapping AVAudioPlayer
class AudioService: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CVDisplayLink?
    private var timer: Timer?
    
    weak var delegate: AudioServiceDelegate?
    
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    
    // MARK: - Playback Control
    
    /// Load an audio file from URL
    func load(url: URL) throws {
        stop()
        
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.prepareToPlay()
        
        duration = audioPlayer?.duration ?? 0
        currentTime = 0
    }
    
    /// Start or resume playback
    func play() {
        guard let player = audioPlayer else { return }
        player.rate = playbackRate
        player.play()
        isPlaying = true
        startTimer()
    }
    
    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    /// Stop playback and reset position
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    /// Toggle between play and pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
    }
    
    /// Seek forward by a number of seconds
    func seekForward(by seconds: TimeInterval = 5) {
        seek(to: currentTime + seconds)
    }
    
    /// Seek backward by a number of seconds
    func seekBackward(by seconds: TimeInterval = 5) {
        seek(to: currentTime - seconds)
    }
    
    /// Set the playback rate (0.5 to 2.0)
    func setRate(_ rate: Float) {
        let clampedRate = max(0.5, min(rate, 2.0))
        playbackRate = clampedRate
        if isPlaying {
            audioPlayer?.rate = clampedRate
        }
    }
    
    // MARK: - Timer for Time Updates
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        delegate?.audioServiceDidUpdateTime(currentTime: currentTime, duration: duration)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        delegate?.audioServiceDidFinishPlaying()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
        stopTimer()
    }
}
