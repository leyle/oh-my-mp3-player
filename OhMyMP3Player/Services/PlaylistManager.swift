//
//  PlaylistManager.swift
//  OhMyMP3Player
//
//  Service for managing multiple playlists with persistence.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class PlaylistManager: ObservableObject {
    
    static let shared = PlaylistManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var trashedPlaylists: [Playlist] = []
    @Published var selectedPlaylistId: UUID?
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let playlistsDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        // Setup playlists directory in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("OhMyMP3Player", isDirectory: true)
        playlistsDirectory = appDirectory.appendingPathComponent("Playlists", isDirectory: true)
        
        // Create directories if needed
        try? fileManager.createDirectory(at: playlistsDirectory, withIntermediateDirectories: true)
        
        loadPlaylists()
    }
    
    // MARK: - Playlist CRUD
    
    /// Create a new playlist
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }
    
    /// Rename a playlist
    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        savePlaylists()
    }
    
    /// Delete playlist (move to trash)
    func deletePlaylist(_ playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        var deletedPlaylist = playlists.remove(at: index)
        deletedPlaylist.isDeleted = true
        deletedPlaylist.deletedAt = Date()
        trashedPlaylists.append(deletedPlaylist)
        savePlaylists()
    }
    
    /// Restore playlist from trash
    func restorePlaylist(_ playlist: Playlist) {
        guard let index = trashedPlaylists.firstIndex(where: { $0.id == playlist.id }) else { return }
        var restoredPlaylist = trashedPlaylists.remove(at: index)
        restoredPlaylist.isDeleted = false
        restoredPlaylist.deletedAt = nil
        playlists.append(restoredPlaylist)
        savePlaylists()
    }
    
    /// Permanently delete playlist from trash
    func permanentlyDeletePlaylist(_ playlist: Playlist) {
        trashedPlaylists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    /// Empty trash
    func emptyTrash() {
        trashedPlaylists.removeAll()
        savePlaylists()
    }
    
    // MARK: - Track Management
    
    /// Add tracks to a playlist
    func addTracks(_ urls: [URL], to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        for url in urls {
            // Always save security-scoped bookmark (even for existing files to fix missing bookmarks)
            BookmarkManager.shared.saveBookmark(for: url)
            
            if !playlists[index].trackURLs.contains(url) {
                playlists[index].trackURLs.append(url)
            }
        }
        savePlaylists()
    }
    
    /// Remove a track from a playlist
    func removeTrack(at trackIndex: Int, from playlist: Playlist) {
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }),
              trackIndex < playlists[playlistIndex].trackURLs.count else { return }
        playlists[playlistIndex].trackURLs.remove(at: trackIndex)
        savePlaylists()
    }
    
    /// Reorder tracks in a playlist
    func moveTrack(from source: IndexSet, to destination: Int, in playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].trackURLs.move(fromOffsets: source, toOffset: destination)
        savePlaylists()
    }
    
    /// Get playlist by ID
    func playlist(withId id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }
    
    /// Get playlist containing a track URL
    func playlist(containingTrack url: URL) -> Playlist? {
        playlists.first { $0.trackURLs.contains(url) }
    }
    
    // MARK: - Persistence
    
    private func savePlaylists() {
        let allPlaylists = playlists + trashedPlaylists
        let url = playlistsDirectory.appendingPathComponent("playlists.json")
        
        do {
            let data = try JSONEncoder().encode(allPlaylists)
            try data.write(to: url)
        } catch {
            print("Error saving playlists: \(error)")
        }
    }
    
    private func loadPlaylists() {
        let url = playlistsDirectory.appendingPathComponent("playlists.json")
        
        guard fileManager.fileExists(atPath: url.path) else {
            // Create default playlist if none exist
            let _ = createPlaylist(name: "My Playlist")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let allPlaylists = try JSONDecoder().decode([Playlist].self, from: data)
            
            playlists = allPlaylists.filter { !$0.isDeleted }
            trashedPlaylists = allPlaylists.filter { $0.isDeleted }
            
            // Select first playlist by default
            if selectedPlaylistId == nil, let first = playlists.first {
                selectedPlaylistId = first.id
            }
        } catch {
            print("Error loading playlists: \(error)")
            // Create default playlist on error
            let _ = createPlaylist(name: "My Playlist")
        }
    }
}
