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
    @State private var happinessCalculator: HappinessIndexCalculator?
    @State private var analyticsRepository: EntryAnalyticsRepository?
    @State private var agentKernel: AgentKernel?
    @State private var currentStateAnalyzer: CurrentStateAnalyzer?

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
        case .analytics:
            if let calculator = happinessCalculator, let repository = analyticsRepository {
                AnalyticsView(
                    calculator: calculator,
                    analyticsRepository: repository,
                    onNavigateToSettings: {
                        // TODO: Add settings navigation if needed
                    }
                )
            } else {
                ProgressView("Loading Analytics...")
                    .onAppear { initializeAnalyticsServices() }
            }
        case .aiChat:
            if let kernel = agentKernel {
                AIChatView(agentKernel: kernel)
            } else {
                ProgressView("Loading AI Chat...")
                    .onAppear { initializeAIServices() }
            }
        case .insights:
            if let analyzer = currentStateAnalyzer {
                CurrentStateDashboardView(analyzer: analyzer, fileManager: fileService)
            } else {
                ProgressView("Loading Insights...")
                    .onAppear { initializeAnalyticsServices() }
            }
        }
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

    private func initializeAnalyticsServices() {
        guard happinessCalculator == nil || analyticsRepository == nil || currentStateAnalyzer == nil else { return }

        // Initialize database service
        let dbService = DatabaseService.shared
        self.databaseService = dbService

        // Initialize happiness calculator
        let calculator = HappinessIndexCalculator()
        self.happinessCalculator = calculator

        // Initialize analytics repository
        let repository = EntryAnalyticsRepository(dbService: dbService)
        self.analyticsRepository = repository

        // Initialize current state analyzer
        let openAI = OpenAIService()
        let analyzer = CurrentStateAnalyzer(
            repository: repository,
            calculator: calculator,
            openAI: openAI
        )
        self.currentStateAnalyzer = analyzer
    }

    private func initializeAIServices() {
        guard agentKernel == nil else { return }

        // Initialize OpenAI service
        let openAI = OpenAIService()

        // Initialize tool registry
        let toolRegistry = ToolRegistry()

        // Initialize database service if needed
        if databaseService == nil {
            databaseService = DatabaseService.shared
        }
        if analyticsRepository == nil {
            analyticsRepository = EntryAnalyticsRepository(dbService: databaseService!)
        }
        if happinessCalculator == nil {
            happinessCalculator = HappinessIndexCalculator()
        }
        if currentStateAnalyzer == nil {
            currentStateAnalyzer = CurrentStateAnalyzer(
                repository: analyticsRepository!,
                calculator: happinessCalculator!,
                openAI: openAI
            )
        }

        // Register tools for the agent

        // 1. Semantic search tool
        let chunkRepository = ChunkRepository(dbService: databaseService!)
        let vectorSearch = VectorSearchService(chunkRepository: chunkRepository)
        let searchTool = SearchSemanticTool(
            vectorSearch: vectorSearch,
            chunkRepository: chunkRepository,
            openAI: openAI
        )
        toolRegistry.registerTool(searchTool)

        // 2. Time series tool
        let timeSeriesTool = GetTimeSeriesTool(
            calculator: happinessCalculator!,
            repository: analyticsRepository!
        )
        toolRegistry.registerTool(timeSeriesTool)

        // 3. Current state snapshot tool
        let currentStateTool = GetCurrentStateSnapshotTool(analyzer: currentStateAnalyzer!)
        toolRegistry.registerTool(currentStateTool)

        // Initialize agent kernel
        let kernel = AgentKernel(
            openAI: openAI,
            toolRegistry: toolRegistry,
            maxIterations: 10,
            model: "gpt-4o"
        )
        self.agentKernel = kernel
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
}
