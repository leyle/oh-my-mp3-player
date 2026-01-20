//
//  PlaylistItemView.swift
//  LocalMP3Player
//
//  A single track row in the playlist sidebar.
//

import SwiftUI

struct PlaylistItemView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    let track: Track
    
    private var isCurrentTrack: Bool {
        viewModel.currentTrack?.id == track.id
    }
    
    private var isPlaying: Bool {
        isCurrentTrack && viewModel.isPlaying
    }
    
    var body: some View {
        Button {
            Task {
                await viewModel.selectTrack(track)
            }
        } label: {
            HStack(spacing: 12) {
                // Track icon / Now playing indicator
                ZStack {
                    if isPlaying {
                        NowPlayingAnimation()
                    } else {
                        Image(systemName: "music.note")
                            .foregroundStyle(isCurrentTrack ? .primary : .secondary)
                    }
                }
                .frame(width: 20)
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(isCurrentTrack ? .semibold : .regular)
                        .foregroundStyle(isCurrentTrack ? .primary : .primary)
                        .lineLimit(1)
                    
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Duration
                if track.duration > 0 {
                    Text(formatDuration(track.duration))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isCurrentTrack
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .contextMenu {
            Button {
                Task {
                    await viewModel.selectTrack(track)
                }
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            
            Divider()
            
            Button(role: .destructive) {
                viewModel.removeTrack(track)
            } label: {
                Label("Remove from Playlist", systemImage: "trash")
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Animated bars for "now playing" indicator
struct NowPlayingAnimation: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: animating ? CGFloat.random(in: 6...14) : 6)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    List {
        PlaylistItemView(track: Track(url: URL(fileURLWithPath: "/test/song.mp3")))
            .environmentObject(AudioPlayerViewModel())
    }
    .listStyle(.sidebar)
    .frame(width: 250)
}
