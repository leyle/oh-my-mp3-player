//
//  SidebarView.swift
//  OhMyMP3Player
//
//  Sidebar with multi-playlist navigation.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

enum SidebarNavigationState {
    case playlistList
    case playlistDetail(Playlist)
    case trash
}

struct SidebarView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    @StateObject private var playlistManager = PlaylistManager.shared
    @State private var navigationState: SidebarNavigationState = .playlistList
    @State private var showNewPlaylistSheet = false
    @State private var newPlaylistName = ""
    @State private var isEditMode = false
    @State private var selectedTracks: Set<URL> = []
    
    // Binding for external navigation (from player header)
    @Binding var navigateToPlaylist: Playlist?
    
    init(navigateToPlaylist: Binding<Playlist?> = .constant(nil)) {
        self._navigateToPlaylist = navigateToPlaylist
    }
    
    var body: some View {
        VStack(spacing: 0) {
            switch navigationState {
            case .playlistList:
                playlistListView
            case .playlistDetail(let playlist):
                playlistDetailView(playlist: playlist)
            case .trash:
                trashView
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showNewPlaylistSheet) {
            newPlaylistSheet
        }
        .onChange(of: navigateToPlaylist) { _, newPlaylist in
            if let playlist = newPlaylist {
                navigationState = .playlistDetail(playlist)
                navigateToPlaylist = nil
            }
        }
    }
    
    // MARK: - Playlist List View
    
    private var playlistListView: some View {
        List {
            Section {
                ForEach(playlistManager.playlists) { playlist in
                    Button {
                        navigationState = .playlistDetail(playlist)
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundStyle(Color.accentColor)
                            Text(playlist.name)
                            Spacer()
                            Text("\(playlist.trackURLs.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Rename...") {
                            // TODO: Rename sheet
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            playlistManager.deletePlaylist(playlist)
                        }
                    }
                }
                
                // New Playlist button
                Button {
                    newPlaylistName = ""
                    showNewPlaylistSheet = true
                } label: {
                    Label("New Playlist...", systemImage: "plus")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Playlists")
            }
            
            // Trash section
            if !playlistManager.trashedPlaylists.isEmpty {
                Section {
                    Button {
                        navigationState = .trash
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                            Text("Trash")
                            Spacer()
                            Text("\(playlistManager.trashedPlaylists.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Playlist Detail View
    
    private func playlistDetailView(playlist: Playlist) -> some View {
        VStack(spacing: 0) {
            // Header with back button and edit toggle
            HStack {
                Button {
                    isEditMode = false
                    selectedTracks.removeAll()
                    navigationState = .playlistList
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(playlist.name)
                    .font(.title3)
                
                Spacer()
                
                // Edit button
                Button {
                    withAnimation {
                        isEditMode.toggle()
                        if !isEditMode {
                            selectedTracks.removeAll()
                        }
                    }
                } label: {
                    Text(isEditMode ? "Done" : "Edit")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isEditMode ? Color.accentColor : .primary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Track list
            if let currentPlaylist = playlistManager.playlist(withId: playlist.id) {
                if isEditMode {
                    // Edit mode: multi-select and drag-to-reorder
                    List(selection: $selectedTracks) {
                        ForEach(currentPlaylist.trackURLs, id: \.self) { url in
                            HStack {
                                PlaylistTrackRow(url: url, isPlaying: viewModel.currentTrack?.url == url)
                            }
                            .tag(url)
                        }
                        .onMove { source, destination in
                            playlistManager.moveTrack(from: source, to: destination, in: currentPlaylist)
                        }
                    }
                    .id(currentPlaylist.trackURLs.count)  // Force refresh when count changes
                } else {
                    // Normal mode: tap to play
                    List {
                        ForEach(currentPlaylist.trackURLs, id: \.self) { url in
                            PlaylistTrackRow(url: url, isPlaying: viewModel.currentTrack?.url == url)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playTrack(url: url, fromPlaylist: currentPlaylist)
                                }
                                .contextMenu {
                                    Button("Remove from Playlist", role: .destructive) {
                                        if let index = currentPlaylist.trackURLs.firstIndex(of: url) {
                                            playlistManager.removeTrack(at: index, from: currentPlaylist)
                                        }
                                    }
                                }
                        }
                    }
                }
                
                if currentPlaylist.trackURLs.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No tracks")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            
            // Bottom buttons
            VStack(spacing: 8) {
                Divider()
                
                if isEditMode && !selectedTracks.isEmpty {
                    // Delete selected button
                    Button(role: .destructive) {
                        deleteSelectedTracks(from: playlist)
                    } label: {
                        Label("Delete \(selectedTracks.count) Selected", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                } else {
                    Button {
                        openFilePicker(for: playlist)
                    } label: {
                        Label("Add Files", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }
    
    private func deleteSelectedTracks(from playlist: Playlist) {
        guard let currentPlaylist = playlistManager.playlist(withId: playlist.id) else { return }
        
        // Find indices to remove (in reverse to maintain correct indices)
        let indicesToRemove = currentPlaylist.trackURLs.enumerated()
            .filter { selectedTracks.contains($0.element) }
            .map { $0.offset }
            .sorted(by: >)
        
        for index in indicesToRemove {
            playlistManager.removeTrack(at: index, from: currentPlaylist)
        }
        
        selectedTracks.removeAll()
    }
    
    // MARK: - Trash View
    
    private var trashView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    navigationState = .playlistList
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Trash")
                    .font(.title3)
                
                Spacer()
                
                Text("Back")
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            List {
                ForEach(playlistManager.trashedPlaylists) { playlist in
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.secondary)
                        Text(playlist.name)
                        Spacer()
                    }
                    .contextMenu {
                        Button("Restore") {
                            playlistManager.restorePlaylist(playlist)
                            if playlistManager.trashedPlaylists.isEmpty {
                                navigationState = .playlistList
                            }
                        }
                        Divider()
                        Button("Delete Permanently", role: .destructive) {
                            playlistManager.permanentlyDeletePlaylist(playlist)
                            if playlistManager.trashedPlaylists.isEmpty {
                                navigationState = .playlistList
                            }
                        }
                    }
                }
            }
            
            if !playlistManager.trashedPlaylists.isEmpty {
                VStack(spacing: 8) {
                    Divider()
                    Button(role: .destructive) {
                        playlistManager.emptyTrash()
                        navigationState = .playlistList
                    } label: {
                        Label("Empty Trash", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - New Playlist Sheet
    
    private var newPlaylistSheet: some View {
        VStack(spacing: 16) {
            Text("New Playlist")
                .font(.headline)
            
            TextField("Playlist Name", text: $newPlaylistName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    createPlaylist()
                }
            
            HStack {
                Button("Cancel") {
                    showNewPlaylistSheet = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create") {
                    createPlaylist()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(newPlaylistName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func createPlaylist() {
        guard !newPlaylistName.isEmpty else { return }
        let playlist = playlistManager.createPlaylist(name: newPlaylistName)
        navigationState = .playlistDetail(playlist)
        showNewPlaylistSheet = false
    }
    
    // MARK: - Actions
    
    private func openFilePicker(for playlist: Playlist) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        
        if panel.runModal() == .OK {
            playlistManager.addTracks(panel.urls, to: playlist)
        }
    }
    
    private func playTrack(url: URL, fromPlaylist playlist: Playlist) {
        Task {
            await viewModel.loadPlaylistAndPlay(playlist: playlist, startingAt: url)
        }
    }
    
    // Navigate to playlist (called from player header)
    func navigateToPlaylist(_ playlist: Playlist) {
        navigationState = .playlistDetail(playlist)
    }
}

// MARK: - Playlist Track Row With Reorder

struct PlaylistTrackRowWithReorder: View {
    let url: URL
    let index: Int
    let totalCount: Int
    let isPlaying: Bool
    let onTap: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            PlaylistTrackRow(url: url, isPlaying: isPlaying)
            
            // Reorder buttons - only show on hover
            if isHovering {
                HStack(spacing: 2) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)
                    .opacity(index == 0 ? 0.3 : 1)
                    
                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == totalCount - 1)
                    .opacity(index == totalCount - 1 ? 0.3 : 1)
                }
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Remove from Playlist", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Playlist Track Row

struct PlaylistTrackRow: View {
    let url: URL
    let isPlaying: Bool
    @State private var duration: TimeInterval?
    
    var body: some View {
        HStack {
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "music.note")
                .foregroundStyle(isPlaying ? Color.accentColor : Color.secondary)
                .frame(width: 20)
            
            Text(url.lastPathComponent)
                .lineLimit(2)
                .fontWeight(isPlaying ? .semibold : .regular)
                .help(url.lastPathComponent)  // Tooltip for full name
            
            Spacer()
            
            // Duration
            if let duration = duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .task {
            await loadDuration()
        }
    }
    
    private func loadDuration() async {
        // Ensure we have security-scoped access
        BookmarkManager.shared.startAccessing(url)
        
        let asset = AVURLAsset(url: url)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0 {
                duration = seconds
            }
        } catch {
            // Ignore errors
        }
    }
    
    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
            .environmentObject(AudioPlayerViewModel())
    } detail: {
        Text("Player")
    }
}
