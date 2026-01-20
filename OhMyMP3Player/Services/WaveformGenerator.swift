//
//  WaveformGenerator.swift
//  LocalMP3Player
//
//  Generates waveform data from audio files using Accelerate framework.
//

import Foundation
import AVFoundation
import Accelerate

/// Generates waveform visualization data from audio files
class WaveformGenerator {
    
    /// Number of bars to generate for the waveform
    static let barCount = 600
    
    /// Generate waveform data from an audio file URL
    /// - Parameter url: The URL of the audio file
    /// - Returns: An array of normalized amplitude values (0.0 to 1.0)
    static func generateWaveform(from url: URL) async -> [Float] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let waveform = generateWaveformSync(from: url)
                continuation.resume(returning: waveform)
            }
        }
    }
    
    /// Synchronous waveform generation
    private static func generateWaveformSync(from url: URL) -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return Array(repeating: 0.5, count: barCount)
        }
        
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return Array(repeating: 0.5, count: barCount)
        }
        
        do {
            try audioFile.read(into: buffer)
        } catch {
            print("Error reading audio file: \(error)")
            return Array(repeating: 0.5, count: barCount)
        }
        
        guard let channelData = buffer.floatChannelData?[0] else {
            return Array(repeating: 0.5, count: barCount)
        }
        
        let samples = Int(buffer.frameLength)
        let samplesPerBar = samples / barCount
        
        guard samplesPerBar > 0 else {
            return Array(repeating: 0.5, count: barCount)
        }
        
        var waveformData = [Float](repeating: 0, count: barCount)
        
        // Process each bar
        for i in 0..<barCount {
            let startSample = i * samplesPerBar
            let endSample = min(startSample + samplesPerBar, samples)
            let count = endSample - startSample
            
            guard count > 0 else { continue }
            
            // Calculate RMS (Root Mean Square) for this segment
            var sum: Float = 0
            vDSP_svesq(channelData.advanced(by: startSample), 1, &sum, vDSP_Length(count))
            let rms = sqrt(sum / Float(count))
            
            waveformData[i] = rms
        }
        
        // Normalize to 0.0 - 1.0 range
        var maxValue: Float = 0
        vDSP_maxv(waveformData, 1, &maxValue, vDSP_Length(barCount))
        
        if maxValue > 0 {
            var scale = 1.0 / maxValue
            vDSP_vsmul(waveformData, 1, &scale, &waveformData, 1, vDSP_Length(barCount))
        }
        
        return waveformData
    }
    
    /// Generate waveform and update a Track
    static func updateTrackWaveform(_ track: inout Track) async {
        track.waveformData = await generateWaveform(from: track.url)
    }
}
