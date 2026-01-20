//
//  ProgressSliderView.swift
//  LocalMP3Player
//
//  Time progress slider with current/total time display.
//

import SwiftUI

struct ProgressSliderView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    private var displayProgress: Double {
        isDragging ? dragProgress : viewModel.progress
    }
    
    private var displayTime: TimeInterval {
        isDragging ? dragProgress * viewModel.duration : viewModel.currentTime
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress track
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * displayProgress, height: 4)
                    
                    // Thumb
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .offset(x: (geometry.size.width - 12) * displayProgress)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = value.location.x / geometry.size.width
                            dragProgress = max(0, min(1, progress))
                        }
                        .onEnded { value in
                            let progress = value.location.x / geometry.size.width
                            let clampedProgress = max(0, min(1, progress))
                            viewModel.seekToProgress(clampedProgress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 12)
            
            // Time labels
            HStack {
                Text(formatTime(displayTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text(formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ProgressSliderView()
        .environmentObject(AudioPlayerViewModel())
        .padding()
        .frame(width: 400)
}
