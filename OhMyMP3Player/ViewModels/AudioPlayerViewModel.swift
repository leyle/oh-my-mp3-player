//
//  AudioPlayerViewModel.swift
//  LocalMP3Player
//
//  Main view model managing playlist and playback state.
//

import Foundation
import SwiftUI
import Combine

/// Object to hold high-frequency playback progress data
@MainActor
class PlaybackProgress: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
}

/// Main view model for the audio player
@MainActor
class AudioPlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var playlist: [Track] = []
    @Published var currentTrack: Track?
    @Published var currentTrackIndex: Int?
    
    @Published var playbackState: PlaybackState = .stopped
    // currentTime and duration are now in progress object
    let progress = PlaybackProgress()
    
    @Published var playbackRate: Float = 1.0
    @Published var loopMode: LoopMode = .none
    
    @Published var isLoadingTrack: Bool = false
    @Published var currentPlaylist: Playlist?  // Which playlist the current track belongs to
    
    // MARK: - Services
    
    private let audioService = AudioService()
    private let nowPlayingService = NowPlayingService.shared
    private let persistenceService = PersistenceService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var isPlaying: Bool {
        playbackState == .playing
    }
    
    // Convenience for legacy access, but won't trigger view updates on self
    var currentTime: TimeInterval { progress.currentTime }
    var duration: TimeInterval { progress.duration }
    
    var hasNextTrack: Bool {
        guard let index = currentTrackIndex else { return false }
        return index < playlist.count - 1
    }
    
    var hasPreviousTrack: Bool {
        guard let index = currentTrackIndex else { return false }
        return index > 0
    }
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        setupNowPlayingCallbacks()
        audioService.delegate = self
        loadSavedState()
    }
    
    private func setupNowPlayingCallbacks() {
        nowPlayingService.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        nowPlayingService.onNextTrack = { [weak self] in
            self?.nextTrack()
        }
        nowPlayingService.onPreviousTrack = { [weak self] in
            self?.previousTrack()
        }
        nowPlayingService.onSeek = { [weak self] time in
            self?.seek(to: time)
        }
    }
    
    private func loadSavedState() {
        // Load saved playback settings
        playbackRate = persistenceService.loadPlaybackRate()
        loopMode = persistenceService.loadLoopMode()
        
        // Load saved playlist
        Task {
            let savedURLs = persistenceService.loadPlaylist()
            await addFilesWithoutAutoPlay(urls: savedURLs)
            
            // Restore current track position (without playing)
            if let savedIndex = persistenceService.loadCurrentTrackIndex(),
               savedIndex < playlist.count {
                let track = playlist[savedIndex]
                try? audioService.load(url: track.url)
                currentTrack = track
                currentTrackIndex = savedIndex
                progress.duration = audioService.duration
                
                // Find which playlist this track belongs to
                currentPlaylist = PlaylistManager.shared.playlist(containingTrack: track.url)
                
                let savedTime = persistenceService.loadCurrentTime()
                if savedTime > 0 && savedTime < progress.duration {
                    audioService.seek(to: savedTime)
                    progress.currentTime = savedTime
                }
                // Do NOT play - just restore position
            }
        }
    }
    
    /// Save current state for persistence
    func saveState() {
        let urls = playlist.map { $0.url }
        persistenceService.savePlaylist(urls: urls)
        persistenceService.saveCurrentTrackIndex(currentTrackIndex)
        persistenceService.saveCurrentTime(progress.currentTime)
        persistenceService.savePlaybackRate(playbackRate)
        persistenceService.saveLoopMode(loopMode)
    }
    
    private func updateNowPlaying() {
        guard let track = currentTrack else {
            nowPlayingService.clearNowPlaying()
            return
        }
        
        nowPlayingService.updateNowPlaying(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: progress.duration,
            currentTime: progress.currentTime,
            isPlaying: isPlaying,
            artwork: track.artwork
        )
    }
    
    private func setupBindings() {
        audioService.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.playbackState = isPlaying ? .playing : .paused
            }
            .store(in: &cancellables)
            
        // Note: we don't bind currentTime/duration from audioService here anymore
        // because we handle it in delegate callbacks more efficiently
    }
    
    // MARK: - Playlist Management
    
    /// Add files to the playlist
    func addFiles(urls: [URL]) async {
        for url in urls {
            guard url.pathExtension.lowercased() == "mp3" else { continue }
            
            var track = Track(url: url)
            
            // Load metadata and waveform in background
            await MetadataService.updateTrack(&track)
            await WaveformGenerator.updateTrackWaveform(&track)
            
            playlist.append(track)
            
            // Auto-play first track if nothing is playing
            if currentTrack == nil && playlist.count == 1 {
                await loadAndPlay(track: track)
            }
        }
    }
    
    /// Add files without auto-playing (used for restoring saved playlist)
    private func addFilesWithoutAutoPlay(urls: [URL]) async {
        for url in urls {
            guard url.pathExtension.lowercased() == "mp3" else { continue }
            
            var track = Track(url: url)
            
            // Load metadata and waveform in background
            await MetadataService.updateTrack(&track)
            await WaveformGenerator.updateTrackWaveform(&track)
            
            playlist.append(track)
            // Do NOT auto-play
        }
    }
    
    /// Remove a track from the playlist
    func removeTrack(_ track: Track) {
        guard let index = playlist.firstIndex(of: track) else { return }
        
        let wasCurrentTrack = currentTrack?.id == track.id
        playlist.remove(at: index)
        
        if wasCurrentTrack {
            audioService.stop()
            
            if !playlist.isEmpty {
                // Play next track or previous if we removed the last one
                let nextIndex = min(index, playlist.count - 1)
                Task {
                    await loadAndPlay(track: playlist[nextIndex])
                }
            } else {
                currentTrack = nil
                currentTrackIndex = nil
                playbackState = .stopped
            }
        } else if let currentIndex = currentTrackIndex, index < currentIndex {
            // Adjust current index if we removed a track before it
            self.currentTrackIndex = currentIndex - 1
        }
    }
    
    /// Clear all tracks from the playlist
    func clearPlaylist() {
        audioService.stop()
        playlist.removeAll()
        currentTrack = nil
        currentTrackIndex = nil
        playbackState = .stopped
        progress.currentTime = 0
        progress.duration = 0
    }
    
    /// Select and play a track
    func selectTrack(_ track: Track) async {
        await loadAndPlay(track: track)
    }
    
    /// Load playlist and start playing from a specific track URL
    func loadPlaylistAndPlay(playlist: Playlist, startingAt url: URL) async {
        currentPlaylist = playlist
        
        // Create minimal tracks immediately (just URLs, no metadata yet)
        self.playlist = playlist.trackURLs.map { Track(url: $0) }
        
        // Find and play the starting track immediately
        if let startIndex = self.playlist.firstIndex(where: { $0.url == url }) {
            // Start security-scoped access via BookmarkManager
            BookmarkManager.shared.startAccessing(url)
            
            // Load metadata and waveform for clicked track only
            var track = self.playlist[startIndex]
            await MetadataService.updateTrack(&track)
            await WaveformGenerator.updateTrackWaveform(&track)
            self.playlist[startIndex] = track
            await loadAndPlay(track: track)
        }
        
        // Load remaining metadata in background (non-blocking)
        Task {
            for i in 0..<self.playlist.count {
                if self.playlist[i].url != url && i < self.playlist.count {
                    BookmarkManager.shared.startAccessing(self.playlist[i].url)
                    var track = self.playlist[i]
                    await MetadataService.updateTrack(&track)
                    await WaveformGenerator.updateTrackWaveform(&track)
                    if i < self.playlist.count {
                        self.playlist[i] = track
                    }
                }
            }
        }
    }
    
    // MARK: - Playback Control
    
    /// Load and start playing a track
    private func loadAndPlay(track: Track) async {
        isLoadingTrack = true
        
        do {
            try audioService.load(url: track.url)
            currentTrack = track
            currentTrackIndex = playlist.firstIndex(of: track)
            progress.duration = audioService.duration
            audioService.setRate(playbackRate)
            audioService.play()
            updateNowPlaying()
        } catch {
            print("Error loading track: \(error.localizedDescription)")
        }
        
        isLoadingTrack = false
        saveState()
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        if currentTrack == nil, let firstTrack = playlist.first {
            Task {
                await loadAndPlay(track: firstTrack)
            }
            return
        }
        
        audioService.togglePlayPause()
        updateNowPlaying()
    }
    
    /// Play the next track
    func nextTrack() {
        guard let index = currentTrackIndex, index < playlist.count - 1 else {
            if loopMode == .all, let firstTrack = playlist.first {
                Task { await loadAndPlay(track: firstTrack) }
            }
            return
        }
        
        Task {
            await loadAndPlay(track: playlist[index + 1])
        }
    }
    
    /// Play the previous track
    func previousTrack() {
        // If we're more than 3 seconds in, restart the current track
        if progress.currentTime > 3 {
            seek(to: 0)
            return
        }
        
        guard let index = currentTrackIndex, index > 0 else { return }
        
        Task {
            await loadAndPlay(track: playlist[index - 1])
        }
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        audioService.seek(to: time)
    }
    
    /// Seek to a progress percentage (0.0 to 1.0)
    func seekToProgress(_ percentage: Double) {
        let time = percentage * progress.duration
        seek(to: time)
    }
    
    /// Seek forward
    func seekForward(by seconds: TimeInterval = 3) {
        audioService.seekForward(by: seconds)
    }
    
    /// Seek backward
    func seekBackward(by seconds: TimeInterval = 3) {
        audioService.seekBackward(by: seconds)
    }
    
    /// Set playback rate
    func setRate(_ rate: Float) {
        playbackRate = rate
        audioService.setRate(rate)
    }
    
    /// Toggle loop mode
    func toggleLoopMode() {
        switch loopMode {
        case .none:
            loopMode = .single
        case .single:
            loopMode = .all
        case .all:
            loopMode = .none
        }
    }
    
    /// Set specific loop mode
    func setLoopMode(_ mode: LoopMode) {
        loopMode = mode
    }
}

// MARK: - AudioServiceDelegate

extension AudioPlayerViewModel: AudioServiceDelegate {
    nonisolated func audioServiceDidFinishPlaying() {
        Task { @MainActor in
            handleTrackFinished()
        }
    }
    
    nonisolated func audioServiceDidUpdateTime(currentTime: TimeInterval, duration: TimeInterval) {
        Task { @MainActor in
            self.progress.currentTime = currentTime
            self.progress.duration = duration
            // Update Now Playing every 5 seconds to avoid excessive updates
            if Int(currentTime) % 5 == 0 {
                updateNowPlaying()
            }
        }
    }
    
    private func handleTrackFinished() {
        switch loopMode {
        case .single:
            // Repeat current track
            seek(to: 0)
            audioService.play()
        case .all:
            // Play next track, or loop back to first
            if hasNextTrack {
                nextTrack()
            } else if let firstTrack = playlist.first {
                Task { await loadAndPlay(track: firstTrack) }
            }
        case .none:
            // Stop and go back to beginning
            seek(to: 0)
            playbackState = .stopped
        }
    }
}

