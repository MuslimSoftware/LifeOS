import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    
    @State private var fileService = FileManagerService()
    @State private var pdfService = PDFExportService()
    @State private var editorViewModel: EditorViewModel?
    @State private var entryListViewModel: EntryListViewModel?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if let editorVM = editorViewModel, let entryListVM = entryListViewModel {
                mainContent
                    .environment(editorVM)
                    .environment(entryListVM)
                    .theme(settings.currentTheme)
                    .onReceive(timer) { _ in
                        editorVM.timerTick()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
                        editorVM.isFullscreen = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
                        editorVM.isFullscreen = false
                    }
                    .onChange(of: editorVM.text) {
                        if let currentId = entryListVM.selectedEntryId,
                           let currentEntry = entryListVM.entries.first(where: { $0.id == currentId }) {
                            entryListVM.saveEntry(entry: currentEntry, content: editorVM.text)
                        }
                    }
            } else {
                ProgressView()
                    .onAppear {
                        initializeViewModels()
                    }
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .preferredColorScheme(settings.colorScheme)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if let editorVM = editorViewModel, let entryListVM = entryListViewModel {
            HStack(spacing: 0) {
                ZStack {
                    settings.currentTheme.backgroundColor
                        .ignoresSafeArea()
                    
                    EditorView()
                        .padding(.bottom, editorVM.bottomNavOpacity > 0 ? 68 : 0)
                        .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        BottomNavigationView(
                            availableFonts: NSFontManager.shared.availableFontFamilies
                        )
                    }
                }
                
                if entryListVM.showingSidebar {
                    Divider()
                    
                    EntryListView(
                        fileService: fileService,
                        pdfService: pdfService
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: entryListVM.showingSidebar)
        }
    }
    
    private func initializeViewModels() {
        let editorVM = EditorViewModel(fileService: fileService, settings: settings)
        let entryListVM = EntryListViewModel(fileService: fileService)
        
        if let initialText = entryListVM.loadExistingEntries() {
            editorVM.text = initialText
        } else if let selectedId = entryListVM.selectedEntryId,
                  let selectedEntry = entryListVM.entries.first(where: { $0.id == selectedId }),
                  let content = entryListVM.loadEntry(entry: selectedEntry) {
            editorVM.text = content
        }
        
        self.editorViewModel = editorVM
        self.entryListViewModel = entryListVM
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
}
