
import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptionSegment]
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        TranscriptSegmentRow(
                            segment: segment,
                            isActivePhrase: segment.contains(currentTime),
                            currentTime: currentTime
                        )
                        .id(segment.id)
                    }
                }
                .padding()
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "seek", let time = Double(url.host ?? "") { // url.host for "seek://1.5" -> "1.5" (actually host? path? "seek://1.5" -> host "1.5". "seek:1.5" -> path "1.5". Using seek:// is safer for host parsing)
                        // If url.absoluteString is "seek://10.5", host is "10.5"
                        // But Double("10.5") works.
                         onSeek(time)
                         return .handled
                    }
                    return .systemAction
                })
            }
            .onChange(of: currentTime) { newValue in
                // Optional: Auto-scroll to current segment
                // To avoid jarring scrolling, maybe only scroll if off screen?
                // For now, let's keep it manual or simple.
                // Or find the active segment ID and scroll to it.
                if let active = segments.first(where: { $0.contains(newValue) }) {
                   // withAnimation { proxy.scrollTo(active.id, anchor: .center) }
                   // Auto-scrolling while reading can be annoying. Voice Memos doesn't auto-scroll aggressively.
                }
            }
        }
    }
}

struct TranscriptSegmentRow: View {
    let segment: TranscriptionSegment
    let isActivePhrase: Bool
    let currentTime: TimeInterval
    
    var body: some View {
        Text(attributedString)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActivePhrase ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .animation(.default, value: isActivePhrase)
    }
    
    private var attributedString: AttributedString {
        var string = AttributedString("")
        
        for (index, word) in segment.words.enumerated() {
            var wordStr = AttributedString(word.text)
            
            // Add interaction link
            // Use a custom scheme we can trap
            wordStr.link = URL(string: "seek://\(word.startTime)")
            
            // Add styling for active word
            let isWordActive = currentTime >= word.startTime && currentTime < (word.startTime + word.duration)
            if isWordActive {
                wordStr.font = .system(size: 16, weight: .bold)
                wordStr.foregroundColor = .accentColor
            } else {
                wordStr.font = .system(size: 16, weight: .regular)
                wordStr.foregroundColor = isActivePhrase ? .primary : .secondary
            }
            
            // Add underline Style to make it clear strictly clickable? 
            // Voice Memos doesn't underline, just text.
            // But standard links might look blue/underlined.
            // We can override link style.
            
            string.append(wordStr)
            
            // Add space
            if index < segment.words.count - 1 {
                string.append(AttributedString(" "))
            }
        }
        
        return string
    }
}
