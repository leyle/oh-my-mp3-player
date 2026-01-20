//
//  NowPlayingService.swift
//  LocalMP3Player
//
//  Integration with macOS Now Playing (Control Center).
//

import Foundation
import MediaPlayer
import AppKit

/// Service for updating macOS Now Playing info (Control Center integration)
class NowPlayingService {
    
    static let shared = NowPlayingService()
    
    private init() {
        setupRemoteCommandCenter()
    }
    
    // Callback closures for remote commands
    var onPlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?
    
    // MARK: - Setup Remote Commands
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play/Pause
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlayPause?()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPlayPause?()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onPlayPause?()
            return .success
        }
        
        // Next/Previous
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNextTrack?()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPreviousTrack?()
            return .success
        }
        
        // Seek
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.onSeek?(positionEvent.positionTime)
            }
            return .success
        }
    }
    
    // MARK: - Update Now Playing Info
    
    /// Update the Now Playing information displayed in Control Center
    func updateNowPlaying(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        currentTime: TimeInterval,
        isPlaying: Bool,
        artwork: NSImage?
    ) {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        
        if let album = album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Add artwork if available
        if let artwork = artwork {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                return artwork
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mpArtwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Clear the Now Playing info
    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
