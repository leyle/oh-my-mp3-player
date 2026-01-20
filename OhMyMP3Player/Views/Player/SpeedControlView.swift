//
//  SpeedControlView.swift
//  LocalMP3Player
//
//  Playback speed slider control.
//

import SwiftUI

struct SpeedControlView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    
    // Balanced: 2 on each side of 1x
    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.5, 2.0]
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tortoise.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Speed buttons
            HStack(spacing: 4) {
                ForEach(speedOptions, id: \.self) { speed in
                    Button {
                        viewModel.setRate(speed)
                    } label: {
                        Text(formatSpeed(speed))
                            .font(.caption2)
                            .fontWeight(viewModel.playbackRate == speed ? .bold : .regular)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.playbackRate == speed
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        viewModel.playbackRate == speed
                            ? Color.accentColor
                            : Color.secondary
                    )
                }
            }
            
            Image(systemName: "hare.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func formatSpeed(_ speed: Float) -> String {
        if speed == floor(speed) {
            return String(format: "%.0fx", speed)
        } else {
            return String(format: "%.2gx", speed)
        }
    }
}

#Preview {
    SpeedControlView()
        .environmentObject(AudioPlayerViewModel())
        .padding()
}
