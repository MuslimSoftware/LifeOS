
import SwiftUI
import AppKit

struct UtilityButtonsView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(EntryListViewModel.self) private var entryListViewModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme
    
    @State private var isHoveringFullscreen = false
    @State private var isHoveringNewEntry = false
    @State private var isHoveringImport = false
    @State private var isHoveringClock = false
    @State private var showImportSheet = false
    @Binding var isHoveringBottomNav: Bool
    
    let fileService: FileManagerService
    
    var body: some View {
        @Bindable var entryListBindable = entryListViewModel
        
        HStack(spacing: 8) {
            Button(editorViewModel.isFullscreen ? "Minimize" : "Fullscreen") {
                if let window = NSApplication.shared.windows.first {
                    window.toggleFullScreen(nil)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringFullscreen ? textHoverColor : textColor)
            .onHover { hovering in
                isHoveringFullscreen = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(theme.separatorColor)
            
            Button(action: {
                if editorViewModel.text.isEmpty {
                    print("Current entry is already empty, not creating a new one")
                    return
                }
                
                if let currentId = entryListViewModel.selectedEntryId {
                    let currentEntry = entryListViewModel.entries.first(where: { $0.id == currentId }) ?? entryListViewModel.draftEntry
                    if let currentEntry = currentEntry {
                        entryListViewModel.saveEntry(entry: currentEntry, content: editorViewModel.text)
                    }
                }
                
                let newText = entryListViewModel.createDraftEntry()
                editorViewModel.isLoadingContent = true
                editorViewModel.text = newText
                editorViewModel.isLoadingContent = false
                editorViewModel.randomizePlaceholder()
            }) {
                Text("New Entry")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringNewEntry ? textHoverColor : textColor)
            .onHover { hovering in
                isHoveringNewEntry = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(theme.separatorColor)
            
            Button("Import Entries") {
                showImportSheet = true
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringImport ? textHoverColor : textColor)
            .font(.system(size: 13))
            .onHover { hovering in
                isHoveringImport = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(theme.separatorColor)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    entryListBindable.showingSidebar.toggle()
                }
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(isHoveringClock ? textHoverColor : textColor)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringClock = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportView(viewModel: ImportViewModel(fileService: fileService, entryListViewModel: entryListViewModel))
        }
    }
    
    private var textColor: Color {
        return theme.buttonText
    }
    
    private var textHoverColor: Color {
        return theme.buttonTextHover
    }
}
