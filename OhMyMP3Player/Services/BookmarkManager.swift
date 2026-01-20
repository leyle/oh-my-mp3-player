//
//  BookmarkManager.swift
//  OhMyMP3Player
//
//  Manages security-scoped bookmarks for persistent file access.
//

import Foundation

class BookmarkManager {
    static let shared = BookmarkManager()
    
    private let bookmarksKey = "SecurityScopedBookmarks"
    private var bookmarkedURLs: [URL: Data] = [:]
    private var accessedURLs: Set<URL> = []
    
    init() {
        loadBookmarks()
    }
    
    // MARK: - Public API
    
    /// Save a security-scoped bookmark for a URL
    func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            bookmarkedURLs[url] = bookmarkData
            saveBookmarks()
        } catch {
            print("Error creating bookmark for \(url): \(error)")
        }
    }
    
    /// Start accessing a security-scoped resource
    @discardableResult
    func startAccessing(_ url: URL) -> Bool {
        // Try direct access first
        if url.startAccessingSecurityScopedResource() {
            accessedURLs.insert(url)
            return true
        }
        
        // Try to resolve from bookmark
        if let bookmarkData = bookmarkedURLs[url] {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    // Re-create bookmark
                    saveBookmark(for: resolvedURL)
                }
                
                if resolvedURL.startAccessingSecurityScopedResource() {
                    accessedURLs.insert(resolvedURL)
                    return true
                }
            } catch {
                print("Error resolving bookmark for \(url): \(error)")
            }
        }
        
        return false
    }
    
    /// Stop accessing a security-scoped resource
    func stopAccessing(_ url: URL) {
        if accessedURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            accessedURLs.remove(url)
        }
    }
    
    /// Stop accessing all resources
    func stopAccessingAll() {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }
    
    // MARK: - Persistence
    
    private func saveBookmarks() {
        var bookmarksDict: [String: Data] = [:]
        for (url, data) in bookmarkedURLs {
            bookmarksDict[url.absoluteString] = data
        }
        UserDefaults.standard.set(bookmarksDict, forKey: bookmarksKey)
    }
    
    private func loadBookmarks() {
        guard let bookmarksDict = UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] else {
            return
        }
        
        for (urlString, data) in bookmarksDict {
            if let url = URL(string: urlString) {
                bookmarkedURLs[url] = data
            }
        }
    }
}
