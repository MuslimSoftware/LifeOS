import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppSettings.self) private var settings

    @State private var fileService = FileManagerService()
    @State private var pdfService = PDFExportService()
    @State private var editorViewModel: EditorViewModel?
    @State private var entryListViewModel: EntryListViewModel?
    @State private var selectedRoute: NavigationRoute = .calendar
    @State private var saveTask: Task<Void, Never>?

    // Analytics & AI services
    @State private var databaseService: DatabaseService?
    @State private var agentKernel: AgentKernel?

    // Authentication
    @State private var authManager = AuthenticationManager.shared
    @State private var hasCheckedAuth = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if !hasCheckedAuth {
                // Initial authentication check
                ProgressView("Checking authentication...")
                    .task {
                        await authManager.checkAuthentication()
                        hasCheckedAuth = true

                        // Initialize AI services after auth check completes (if authenticated)
                        if authManager.isAuthenticated {
                            initializeAIServices()
                        }
                    }
            } else if let editorVM = editorViewModel, let entryListVM = entryListViewModel {
                HStack(spacing: 0) {
                    // Sidebar pinned to leading edge with fixed width
                    SidebarView(selectedRoute: $selectedRoute)
                        .frame(width: 160)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .theme(settings.currentTheme)

                    Divider()

                    // Main content takes remaining space
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .environment(editorVM)
                        .environment(entryListVM)
                        .theme(settings.currentTheme)
                        .background(settings.currentTheme.surfaceColor)
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
                            guard !editorVM.isLoadingContent else { return }

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
        .onReceive(NotificationCenter.default.publisher(for: .authenticationDidChange)) { _ in
            // Reinitialize services when API key is added/changed
            print("🔄 Auth changed, reinitializing AI services...")
            initializeAIServices()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch selectedRoute {
        case .calendar:
            CalendarView(selectedRoute: $selectedRoute)
        case .journal:
            JournalPageView(
                pdfService: pdfService,
                fileService: fileService
            )
        case .aiChat:
            if !authManager.isAuthenticated {
                setupRequiredView
            } else if let kernel = agentKernel {
                AIChatView(agentKernel: kernel)
            } else {
                ProgressView("Loading AI Chat...")
            }
        }
    }

    private var setupRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Setup Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please add your OpenAI API key in Settings to use AI features")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                // Open settings (assuming there's a way to navigate to settings)
                selectedRoute = .calendar  // Navigate somewhere to access settings
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func initializeViewModels() {
        fileService.migrateToEncryption()

        let editorVM = EditorViewModel(fileService: fileService, settings: settings)
        let entryListVM = EntryListViewModel(fileService: fileService)

        editorVM.isLoadingContent = true
        if let initialText = entryListVM.loadExistingEntries() {
            editorVM.text = initialText
        } else if let selectedId = entryListVM.selectedEntryId,
                  let selectedEntry = entryListVM.entries.first(where: { $0.id == selectedId }),
                  let content = entryListVM.loadEntry(entry: selectedEntry) {
            editorVM.text = content
        }
        editorVM.isLoadingContent = false

        self.editorViewModel = editorVM
        self.entryListViewModel = entryListVM
    }

    private func initializeAIServices() {
        guard agentKernel == nil else { return }

        do {
            // Initialize OpenAI service
            let openAI = OpenAIService()

            // Initialize database service if needed
            if databaseService == nil {
                let dbService = DatabaseService.shared
                try dbService.initialize()
                databaseService = dbService
                print("✅ Database initialized for AI services")
            }

            // Create tool registry with new minimal tools
            let toolRegistry = ToolRegistry.createStandardRegistry(
                databaseService: databaseService!,
                openAI: openAI
            )

            // Initialize agent kernel
            let kernel = AgentKernel(
                openAI: openAI,
                toolRegistry: toolRegistry,
                maxIterations: 10,
                model: "gpt-4o"
            )
            self.agentKernel = kernel

            print("✅ AI services initialized successfully")
        } catch {
            print("❌ Failed to initialize AI services: \(error.localizedDescription)")
            // Services remain nil, views will show appropriate empty/error states
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
}
