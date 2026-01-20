//
//  WaveformView.swift
//  OhMyMP3Player
//
//  Simplified single waveform with click/drag to seek.
//

import SwiftUI

// MARK: - Main Waveform View (Simplified)

struct MainWaveformView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    @ObservedObject var progress: PlaybackProgress
    let waveformData: [Float]
    @Binding var scrubbingTime: TimeInterval? // Instant feedback for time display
    
    @State private var isDragging = false
    @State private var dragPercentage: Double = 0
    @State private var lastSeekTime: Date = .distantPast
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                
                // Waveform - directly in the ZStack, no extra padding
                Canvas { context, size in
                    drawWaveform(context: context, size: size)
                }
                .padding(8)
                
                // Playhead line
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
                    .offset(x: playheadOffset(width: width))
                    .shadow(color: .accentColor.opacity(0.5), radius: 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let percentage = value.location.x / width
                        let clampedPercentage = max(0, min(1, percentage))
                        dragPercentage = clampedPercentage
                        
                        // Update external scrubbing time for display
                        if progress.duration > 0 {
                            scrubbingTime = clampedPercentage * progress.duration
                        }
                        
                        // Throttle seeking to avoid audio glitches/lag (max 10 times per second)
                        let now = Date.now
                        if now.timeIntervalSince(lastSeekTime) > 0.1 {
                            viewModel.seekToProgress(clampedPercentage)
                            lastSeekTime = now
                        }
                    }
                    .onEnded { value in
                        let percentage = value.location.x / width
                        let clampedPercentage = max(0, min(1, percentage))
                        viewModel.seekToProgress(clampedPercentage)
                        isDragging = false
                        scrubbingTime = nil // Reset display to actual playback time
                    }
            )
        }
    }
    
    private func playheadOffset(width: CGFloat) -> CGFloat {
        if isDragging {
            return (CGFloat(dragPercentage) - 0.5) * width
        }
        
        guard progress.duration > 0 else { return -width/2 }
        let percentage = progress.currentTime / progress.duration
        return (CGFloat(percentage) - 0.5) * width
    }
    
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        guard !waveformData.isEmpty else { return }
        
        // Resample waveform data to fit view width
        let targetBarCount = min(waveformData.count, Int(size.width / 4)) // ~4px per bar
        let barSpacing: CGFloat = 2
        let barWidth: CGFloat = max(2, (size.width - barSpacing * CGFloat(targetBarCount - 1)) / CGFloat(targetBarCount))
        
        let centerY = size.height / 2
        let maxBarHeight = centerY * 0.9
        
        
        let samplesPerBar = max(1, waveformData.count / targetBarCount)
        let currentPercentage: Double
        if isDragging {
            currentPercentage = dragPercentage
        } else {
            currentPercentage = progress.duration > 0 ? progress.currentTime / progress.duration : 0
        }
        
        for i in 0..<targetBarCount {
            // Get max amplitude for this bar's sample range
            let startIdx = i * samplesPerBar
            let endIdx = min(startIdx + samplesPerBar, waveformData.count)
            
            var maxAmp: Float = 0.1
            for j in startIdx..<endIdx {
                maxAmp = max(maxAmp, waveformData[j])
            }
            
            let barHeight = max(3, CGFloat(maxAmp) * maxBarHeight)
            let x = CGFloat(i) * (barWidth + barSpacing)
            
            let barRect = CGRect(
                x: x,
                y: centerY - barHeight,
                width: barWidth,
                height: barHeight * 2
            )
            
            let barPath = RoundedRectangle(cornerRadius: barWidth / 2)
                .path(in: barRect)
            
            // Calculate if this bar is "played"
            let barProgress = Double(i) / Double(targetBarCount)
            let color: Color = barProgress < currentPercentage
                ? Color.accentColor.opacity(0.8)
                : Color.secondary.opacity(0.4)
            
            context.fill(barPath, with: .color(color))
        }
    }
}

// MARK: - Inline Time Display

struct InlineTimeDisplay: View {
    @ObservedObject var progress: PlaybackProgress
    var scrubbingTime: TimeInterval? = nil
    
    var body: some View {
        HStack {
            // Start time (left)
            Text("0:00")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            
            Spacer()
            
            // Current time (center, large) -- Show scrubbing time if available
            Text(formatTimeWithMs(scrubbingTime ?? progress.currentTime))
                .font(.system(size: 28, weight: .medium, design: .monospaced))
            
            Spacer()
            
            // Total duration (right)
            Text(formatTime(progress.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
    }
    
    private func formatTimeWithMs(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "00:00.00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centiseconds = Int((time - Double(totalSeconds)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Playlist Breadcrumb Header

struct PlaylistBreadcrumbHeader: View {
    let playlistName: String?
    let trackTitle: String
    let onPlaylistTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 8) {
            // Playlist name (clickable)
            if let playlistName = playlistName {
                Button {
                    onPlaylistTap?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.caption)
                        Text(playlistName)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                
                Text("/")
                    .foregroundStyle(.tertiary)
            }
            
            // Track title with icon
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(trackTitle)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// Legacy support
struct CompactTrackHeader: View {
    let title: String
    let artist: String
    let artwork: NSImage?
    
    var body: some View {
        PlaylistBreadcrumbHeader(
            playlistName: nil,
            trackTitle: title,
            onPlaylistTap: nil
        )
    }
}

// MARK: - Legacy views kept for compatibility

struct ScrollableWaveformView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    let waveformData: [Float]
    let duration: TimeInterval
    
    var body: some View {
        // MainWaveformView(waveformData: waveformData, duration: duration)
        EmptyView()
    }
}

struct WaveformOverviewView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    let waveformData: [Float]
    let duration: TimeInterval
    
    var body: some View {
        EmptyView()
    }
}

struct LargeTimeDisplay: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    var body: some View {
        EmptyView()
    }
}

struct WaveformView: View {
    let waveformData: [Float]
    let progress: Double
    
    var body: some View {
        EmptyView()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CompactTrackHeader(
            title: "Sample Track",
            artist: "Artist Name",
            artwork: nil
        )
        
        MainWaveformView(
            progress: PlaybackProgress(),
            waveformData: (0..<300).map { _ in Float.random(in: 0.1...1.0) },
            scrubbingTime: .constant(nil)
        )
        .frame(height: 180)
        .padding(.horizontal, 16)
        .environmentObject(AudioPlayerViewModel())
        
        InlineTimeDisplay(progress: PlaybackProgress())
    }
    .padding()
    .frame(width: 500)
}
