import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppSettings.self) private var settings

    @State private var fileService = FileManagerService()
    @State private var pdfService = PDFExportService()
    @State private var editorViewModel: EditorViewModel?
    @State private var entryListViewModel: EntryListViewModel?
    @State private var selectedRoute: NavigationRoute = .home
    @State private var saveTask: Task<Void, Never>?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if let editorVM = editorViewModel, let entryListVM = entryListViewModel {
                HStack(spacing: 0) {
                    SidebarView(selectedRoute: $selectedRoute)
                        .theme(settings.currentTheme)
                    
                    Divider()
                    
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
                            saveTask?.cancel()

                            saveTask = Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(500))

                                guard !Task.isCancelled else { return }

                                if let currentId = entryListVM.selectedEntryId {
                                    let currentEntry = entryListVM.entries.first(where: { $0.id == currentId }) ?? entryListVM.draftEntry
                                    if let currentEntry = currentEntry {
                                        entryListVM.saveEntryWithoutPreviewUpdate(entry: currentEntry, content: editorVM.text)
                                    }
                                }
                            }
                        }
                        .onChange(of: entryListVM.selectedEntryId) { oldId, newId in
                            saveTask?.cancel()

                            if let oldId = oldId {
                                let oldEntry = entryListVM.entries.first(where: { $0.id == oldId }) ?? entryListVM.draftEntry
                                if let oldEntry = oldEntry {
                                    entryListVM.saveEntry(entry: oldEntry, content: editorVM.text)
                                }
                            }
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
        switch selectedRoute {
        case .home:
            HomeView()
        case .journal:
            JournalPageView(
                pdfService: pdfService,
                fileService: fileService
            )
        case .calendar:
            CalendarView(selectedRoute: $selectedRoute)
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
