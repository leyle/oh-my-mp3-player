//
//  PlaybackControlsView.swift
//  OhMyMP3Player
//
//  Main playback control buttons with loop mode selector on left.
//

import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Loop mode buttons (left side)
            HStack(spacing: 2) {
                LoopModeButton(
                    icon: "stop.circle",
                    isSelected: viewModel.loopMode == .none,
                    help: "Stop at end",
                    action: { viewModel.setLoopMode(.none) }
                )
                
                LoopModeButton(
                    icon: "repeat.1",
                    isSelected: viewModel.loopMode == .single,
                    help: "Repeat current track",
                    action: { viewModel.setLoopMode(.single) }
                )
                
                LoopModeButton(
                    icon: "repeat",
                    isSelected: viewModel.loopMode == .all,
                    help: "Repeat all",
                    action: { viewModel.setLoopMode(.all) }
                )
            }
            
            Spacer()
            
            // Main controls (center)
            HStack(spacing: 24) {
                // Previous track
                Button {
                    viewModel.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.playlist.isEmpty)
                
                // Play/Pause
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .offset(x: viewModel.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.playlist.isEmpty && viewModel.currentTrack == nil)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isPlaying)
                
                // Next track
                Button {
                    viewModel.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasNextTrack && viewModel.loopMode != .all)
            }
            
            Spacer()
            
            // Empty spacer for balance (same width as loop buttons)
            HStack(spacing: 2) {
                Color.clear.frame(width: 30, height: 30)
                Color.clear.frame(width: 30, height: 30)
                Color.clear.frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Loop Mode Button

struct LoopModeButton: View {
    let icon: String
    let isSelected: Bool
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview {
    PlaybackControlsView()
        .environmentObject(AudioPlayerViewModel())
        .padding()
        .frame(width: 500)
}
