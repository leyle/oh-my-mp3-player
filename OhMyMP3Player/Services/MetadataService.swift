//
//  MetadataService.swift
//  LocalMP3Player
//
//  Service for extracting ID3 metadata from audio files.
//

import Foundation
import AVFoundation
import AppKit

/// Service for extracting metadata from audio files
class MetadataService {
    
    /// Extract metadata from an audio file URL
    /// - Parameter url: The URL of the audio file
    /// - Returns: A tuple containing title, artist, album, duration, and artwork
    static func extractMetadata(from url: URL) async -> (title: String?, artist: String?, album: String?, duration: TimeInterval, artwork: NSImage?) {
        let asset = AVURLAsset(url: url)
        
        var title: String?
        var artist: String?
        var album: String?
        var artwork: NSImage?
        var duration: TimeInterval = 0
        
        do {
            // Get duration
            let durationTime = try await asset.load(.duration)
            duration = CMTimeGetSeconds(durationTime)
            
            // Get metadata
            let metadata = try await asset.load(.metadata)
            
            for item in metadata {
                guard let key = item.commonKey?.rawValue else { continue }
                
                switch key {
                case "title":
                    title = try await item.load(.stringValue)
                case "artist":
                    artist = try await item.load(.stringValue)
                case "albumName":
                    album = try await item.load(.stringValue)
                case "artwork":
                    if let data = try await item.load(.dataValue) {
                        artwork = NSImage(data: data)
                    }
                default:
                    break
                }
            }
            
            // Also try ID3 specific metadata if common metadata is missing
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let formatMetadata = try await asset.loadMetadata(for: format)
                for item in formatMetadata {
                    if title == nil, item.identifier == .id3MetadataTitleDescription {
                        title = try await item.load(.stringValue)
                    }
                    if artist == nil, item.identifier == .id3MetadataLeadPerformer {
                        artist = try await item.load(.stringValue)
                    }
                    if album == nil, item.identifier == .id3MetadataAlbumTitle {
                        album = try await item.load(.stringValue)
                    }
                    if artwork == nil, item.identifier == .id3MetadataAttachedPicture {
                        if let data = try await item.load(.dataValue) {
                            artwork = NSImage(data: data)
                        }
                    }
                }
            }
        } catch {
            print("Error loading metadata: \(error.localizedDescription)")
        }
        
        return (title, artist, album, duration, artwork)
    }
    
    /// Update a Track with extracted metadata
    static func updateTrack(_ track: inout Track) async {
        let metadata = await extractMetadata(from: track.url)
        
        if let title = metadata.title, !title.isEmpty {
            track.title = title
        }
        if let artist = metadata.artist, !artist.isEmpty {
            track.artist = artist
        }
        if let album = metadata.album, !album.isEmpty {
            track.album = album
        }
        track.duration = metadata.duration
        track.artwork = metadata.artwork
    }
}
