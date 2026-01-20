//
//  LocalMP3PlayerApp.swift
//  LocalMP3Player
//
//  Main application entry point with menu commands.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct LocalMP3PlayerApp: App {
    @StateObject private var viewModel = AudioPlayerViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    viewModel.saveState()
                }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .commands {
            // File Menu
            CommandGroup(after: .newItem) {
                Button("Open Files...") {
                    openFiles()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Open Folder...") {
                    openFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                
                Divider()
            }
            
            // Playback Menu
            CommandMenu("Playback") {
                Button(viewModel.isPlaying ? "Pause" : "Play") {
                    viewModel.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Divider()
                
                Button("Next Track") {
                    viewModel.nextTrack()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!viewModel.hasNextTrack)
                
                Button("Previous Track") {
                    viewModel.previousTrack()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!viewModel.hasPreviousTrack)
                
                Divider()
                
                Button("Skip Forward 3s") {
                    viewModel.seekForward(by: 3)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                
                Button("Skip Backward 3s") {
                    viewModel.seekBackward(by: 3)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Divider()
                
                Button("Increase Speed") {
                    let newRate = min(viewModel.playbackRate + 0.25, 2.0)
                    viewModel.setRate(newRate)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Decrease Speed") {
                    let newRate = max(viewModel.playbackRate - 0.25, 0.5)
                    viewModel.setRate(newRate)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Reset Speed") {
                    viewModel.setRate(1.0)
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                Button("Toggle Loop") {
                    viewModel.toggleLoopMode()
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
    
    private func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        panel.message = "Select MP3 files to add to playlist"
        
        if panel.runModal() == .OK {
            Task {
                await viewModel.addFiles(urls: panel.urls)
            }
        }
    }
    
    private func openFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder containing MP3 files"
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            Task {
                let mp3Files = findMP3Files(in: folderURL)
                await viewModel.addFiles(urls: mp3Files)
            }
        }
    }
    
    private func findMP3Files(in folderURL: URL) -> [URL] {
        let fileManager = FileManager.default
        var mp3Files: [URL] = []
        
        if let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "mp3" {
                    mp3Files.append(fileURL)
                }
            }
        }
        
        return mp3Files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // State is saved via the onReceive in the SwiftUI view
    }
}
