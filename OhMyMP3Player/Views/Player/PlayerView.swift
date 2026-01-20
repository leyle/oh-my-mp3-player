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
    
    @State private var scrubbingTime: TimeInterval? // Track scrubbing time for instant feedback
    
    var body: some View {
        GeometryReader { geometry in
            if let track = viewModel.currentTrack {
                VStack(spacing: 0) {
                    // Breadcrumb header: Playlist / Track
                    PlaylistBreadcrumbHeader(
                        playlistName: viewModel.currentPlaylist?.name,
                        trackTitle: track.title,
                        onPlaylistTap: {
                            if let playlist = viewModel.currentPlaylist {
                                onPlaylistTap?(playlist)
                            }
                        }
                    )
                    
                    Divider()
                    
                    // Main content area - waveform fills available space
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
        .background(Color(nsColor: .windowBackgroundColor))
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

#Preview {
    PlayerView()
        .environmentObject(AudioPlayerViewModel())
        .frame(width: 500, height: 500)
}
