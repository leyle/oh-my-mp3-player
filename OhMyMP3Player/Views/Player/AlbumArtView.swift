//
//  AlbumArtView.swift
//  LocalMP3Player
//
//  Album artwork display with gradient fallback.
//

import SwiftUI

struct AlbumArtView: View {
    let artwork: NSImage?
    
    var body: some View {
        Group {
            if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Gradient fallback when no artwork
                LinearGradient(
                    colors: [
                        Color(hue: 0.75, saturation: 0.6, brightness: 0.7),
                        Color(hue: 0.85, saturation: 0.5, brightness: 0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

#Preview("With Artwork") {
    AlbumArtView(artwork: nil)
        .frame(width: 300, height: 300)
        .padding()
}

#Preview("No Artwork") {
    AlbumArtView(artwork: nil)
        .frame(width: 300, height: 300)
        .padding()
}
