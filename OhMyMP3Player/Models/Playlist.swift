//
//  Playlist.swift
//  OhMyMP3Player
//
//  Model representing a user playlist.
//

import Foundation

struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var trackURLs: [URL]
    var createdAt: Date
    var isDeleted: Bool
    var deletedAt: Date?
    
    init(id: UUID = UUID(), name: String, trackURLs: [URL] = []) {
        self.id = id
        self.name = name
        self.trackURLs = trackURLs
        self.createdAt = Date()
        self.isDeleted = false
        self.deletedAt = nil
    }
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}
