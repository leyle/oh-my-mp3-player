//
//  Track.swift
//  LocalMP3Player
//
//  A model representing a single audio track in the playlist.
//

import Foundation
import AppKit

/// Represents a single audio track with metadata and waveform data
struct Track: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artwork: NSImage?
    var waveformData: [Float]
    
    /// Creates a new Track from a file URL with default metadata
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.album = "Unknown Album"
        self.duration = 0
        self.artwork = nil
        self.waveformData = []
    }
    
    /// Hashable conformance - tracks are equal if they have the same ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents the current playback state
enum PlaybackState {
    case stopped
    case playing
    case paused
}

/// Represents the loop mode
enum LoopMode {
    case none
    case single
    case all
}
