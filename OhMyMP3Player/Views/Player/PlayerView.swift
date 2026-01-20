//
//  PlayerView.swift
//  OhMyMP3Player
//
//  Simplified player with single large waveform.
//

import SwiftUI
import UniformTypeIdentifiers

struct PlayerView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    var onPlaylistTap: ((Playlist) -> Void)?
    
    @State private var isTranscriptMode = false
    @State private var scrubbingTime: TimeInterval? // Track scrubbing time
    
    var body: some View {
        GeometryReader { geometry in
            if let track = viewModel.currentTrack {
                VStack(spacing: 0) {
                    // Breadcrumb header: Playlist / Track
                    PlaylistBreadcrumbHeader(
                        playlistName: viewModel.currentPlaylist?.name,
                        trackTitle: track.url.lastPathComponent,
                        onPlaylistTap: {
                            if let playlist = viewModel.currentPlaylist {
                                onPlaylistTap?(playlist)
                            }
                        },
                        isTranscriptMode: $isTranscriptMode
                    )
                    
                    Divider()
                    
                    // Main content area
                    if isTranscriptMode {
                        TranscriptContainer(
                            viewModel: viewModel,
                            progress: viewModel.progress
                        )
                        .frame(maxHeight: .infinity)
                        
                        Divider()
                        
                        // Compact Progress Bar
                        VStack(spacing: 4) {
                            CompactInternalScrubber(
                                progress: viewModel.progress,
                                scrubbingTime: $scrubbingTime,
                                onSeek: { percentage in
                                    viewModel.seekToProgress(percentage)
                                }
                            )
                            .frame(height: 24)
                            
                            InlineTimeDisplay(
                                progress: viewModel.progress,
                                scrubbingTime: scrubbingTime
                            )
                        }
                        .padding(.vertical, 8)
                        
                    } else {
                        // Waveform Mode
                        VStack(spacing: 0) {
                            // Single large waveform - fills available space
                            MainWaveformView(
                                progress: viewModel.progress,
                                waveformData: track.waveformData,
                                scrubbingTime: $scrubbingTime
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // Inline time display: 0:00 — current — duration
                            InlineTimeDisplay(
                                progress: viewModel.progress,
                                scrubbingTime: scrubbingTime
                            )
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                        }
                    }
                    
                    Divider()
                    
                    // Playback Controls
                    VStack(spacing: 12) {
                        PlaybackControlsView()
                        SpeedControlView()
                    }
                    .padding(.vertical, 16)
                }
            } else {
                emptyStateView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea(edges: .top))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No Track Selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Add MP3 files to your playlist to start playing")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Button {
                openFilePicker()
            } label: {
                Label("Add Files", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        
        if panel.runModal() == .OK {
            Task {
                await viewModel.addFiles(urls: panel.urls)
            }
        }
    }
}

// MARK: - Transcript Container

struct TranscriptContainer: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @ObservedObject var progress: PlaybackProgress
    
    var body: some View {
        Group {
            switch viewModel.transcriptionState {
            case .idle:
                VStack {
                    Text("Transcription available")
                        .foregroundStyle(.secondary)
                    Button("Start Transcribing") {
                        viewModel.startTranscription()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .onAppear {
                    // Auto-start when switched to this view
                    viewModel.startTranscription()
                }
                
            case .transcribing(let segments):
                if segments.isEmpty {
                     ProgressView("Transcribing...")
                } else {
                    TranscriptView(
                        segments: segments,
                        currentTime: progress.currentTime,
                        onSeek: { time in viewModel.seek(to: time) }
                    )
                }
                
            case .completed(let segments):
                ZStack(alignment: .topTrailing) {
                    TranscriptView(
                        segments: segments,
                        currentTime: progress.currentTime,
                        onSeek: { time in viewModel.seek(to: time) }
                    )
                    
                    Button(action: {
                        viewModel.regenerateTranscription()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .padding()
                    .help("Regenerate Transcription")
                }
                
            case .error(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text("Transcription Failed")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        
                    Button("Retry") {
                        viewModel.regenerateTranscription()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                .padding()
            }
        }
    }
}

// MARK: - Compact Scrubber

struct CompactInternalScrubber: View {
    @ObservedObject var progress: PlaybackProgress
    @Binding var scrubbingTime: TimeInterval?
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)
                
                // Progress
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, progressWidth(totalWidth: width)), height: 4)
                
                // Knob
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 2)
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, progressWidth(totalWidth: width)) - 6)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let percentage = max(0, min(1, value.location.x / width))
                        if progress.duration > 0 {
                            scrubbingTime = percentage * progress.duration
                        }
                        onSeek(percentage)
                    }
                    .onEnded { value in
                        isDragging = false
                        let percentage = max(0, min(1, value.location.x / width))
                        onSeek(percentage)
                        scrubbingTime = nil
                    }
            )
        }
        .padding(.horizontal)
    }
    
    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        guard progress.duration > 0 else { return 0 }
        
        let current: TimeInterval
        if let scrub = scrubbingTime {
            current = scrub
        } else {
            current = progress.currentTime
        }
        
        let percentage = current / progress.duration
        return totalWidth * CGFloat(percentage)
    }
}

#Preview {
    PlayerView()
        .environmentObject(AudioPlayerViewModel())
        .frame(width: 500, height: 500)
}
