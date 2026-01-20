//
//  ContentView.swift
//  OhMyMP3Player
//
//  Main content view with NavigationSplitView layout.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var viewModel: AudioPlayerViewModel
    @StateObject private var playlistManager = PlaylistManager.shared
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var sidebarNavigationPlaylist: Playlist?
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(navigateToPlaylist: $sidebarNavigationPlaylist)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            PlayerView(onPlaylistTap: { playlist in
                // Navigate sidebar to this playlist
                sidebarNavigationPlaylist = playlist
            })
        }
        .navigationTitle("")
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            viewModel.togglePlayPause()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.seekBackward(by: 3)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.seekForward(by: 3)
            return .handled
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                defer { group.leave() }
                
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension.lowercased() == "mp3" else {
                    return
                }
                
                urls.append(url)
            }
        }
        
        group.notify(queue: .main) {
            // Add to current playlist if one is selected
            if let playlistId = playlistManager.selectedPlaylistId,
               let playlist = playlistManager.playlist(withId: playlistId) {
                playlistManager.addTracks(urls, to: playlist)
            }
        }
    }
}

#Preview {
    ContentView(viewModel: AudioPlayerViewModel())
        .environmentObject(AudioPlayerViewModel())
}
