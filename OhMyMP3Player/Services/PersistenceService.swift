//
//  PersistenceService.swift
//  LocalMP3Player
//
//  Service for saving and loading playlist data.
//

import Foundation

/// Service for persisting playlist and app state
class PersistenceService {
    
    static let shared = PersistenceService()
    
    private let playlistKey = "savedPlaylist"
    private let currentTrackIndexKey = "currentTrackIndex"
    private let currentTimeKey = "currentTime"
    private let playbackRateKey = "playbackRate"
    private let loopModeKey = "loopMode"
    
    private init() {}
    
    // MARK: - Playlist Persistence
    
    /// Save playlist URLs to UserDefaults
    func savePlaylist(urls: [URL]) {
        let bookmarks = urls.compactMap { url -> Data? in
            try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        UserDefaults.standard.set(bookmarks, forKey: playlistKey)
    }
    
    /// Load playlist URLs from UserDefaults
    func loadPlaylist() -> [URL] {
        guard let bookmarks = UserDefaults.standard.array(forKey: playlistKey) as? [Data] else {
            return []
        }
        
        return bookmarks.compactMap { bookmark -> URL? in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return nil
            }
            
            // Start accessing security-scoped resource
            _ = url.startAccessingSecurityScopedResource()
            
            return url
        }
    }
    
    // MARK: - Playback State
    
    /// Save current track index
    func saveCurrentTrackIndex(_ index: Int?) {
        if let index = index {
            UserDefaults.standard.set(index, forKey: currentTrackIndexKey)
        } else {
            UserDefaults.standard.removeObject(forKey: currentTrackIndexKey)
        }
    }
    
    /// Load current track index
    func loadCurrentTrackIndex() -> Int? {
        let index = UserDefaults.standard.integer(forKey: currentTrackIndexKey)
        return index >= 0 ? index : nil
    }
    
    /// Save current playback time
    func saveCurrentTime(_ time: TimeInterval) {
        UserDefaults.standard.set(time, forKey: currentTimeKey)
    }
    
    /// Load current playback time
    func loadCurrentTime() -> TimeInterval {
        return UserDefaults.standard.double(forKey: currentTimeKey)
    }
    
    /// Save playback rate
    func savePlaybackRate(_ rate: Float) {
        UserDefaults.standard.set(rate, forKey: playbackRateKey)
    }
    
    /// Load playback rate
    func loadPlaybackRate() -> Float {
        let rate = UserDefaults.standard.float(forKey: playbackRateKey)
        return rate > 0 ? rate : 1.0
    }
    
    /// Save loop mode
    func saveLoopMode(_ mode: LoopMode) {
        let modeValue: Int
        switch mode {
        case .none: modeValue = 0
        case .single: modeValue = 1
        case .all: modeValue = 2
        }
        UserDefaults.standard.set(modeValue, forKey: loopModeKey)
    }
    
    /// Load loop mode
    func loadLoopMode() -> LoopMode {
        let modeValue = UserDefaults.standard.integer(forKey: loopModeKey)
        switch modeValue {
        case 1: return .single
        case 2: return .all
        default: return .none
        }
    }
    
    // MARK: - Clear All
    
    /// Clear all saved data
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: playlistKey)
        UserDefaults.standard.removeObject(forKey: currentTrackIndexKey)
        UserDefaults.standard.removeObject(forKey: currentTimeKey)
        UserDefaults.standard.removeObject(forKey: playbackRateKey)
        UserDefaults.standard.removeObject(forKey: loopModeKey)
    }
}
