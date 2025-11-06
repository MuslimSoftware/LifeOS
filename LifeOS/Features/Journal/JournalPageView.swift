import SwiftUI

struct JournalPageView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(EntryListViewModel.self) private var entryListViewModel
    @Environment(SidebarHoverManager.self) private var hoverManager
    @Environment(\.theme) private var theme
    
    let pdfService: PDFExportService
    let fileService: FileManagerService
    
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                theme.backgroundColor
                    .ignoresSafeArea()

                EditorView()
                    .padding(.bottom, editorViewModel.bottomNavOpacity > 0 ? 68 : 0)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    BottomNavigationView(
                        availableFonts: NSFontManager.shared.availableFontFamilies,
                        fileService: fileService,
                        selectedDate: $selectedDate
                    )
                }
            }
            .overlay(
                EdgeHintView(
                    isLeftEdge: true,
                    isVisible: !hoverManager.isLeftSidebarOpen
                        && !hoverManager.isLeftSidebarPinned
                )
                .opacity(editorViewModel.edgeHintsOpacity)
            )
            .overlay(
                EdgeHintView(
                    isLeftEdge: false,
                    isVisible: !hoverManager.isRightSidebarOpen(for: .journal)
                        && !hoverManager.isRightSidebarPinned(for: .journal)
                )
                .opacity(editorViewModel.edgeHintsOpacity)
            )

            if hoverManager.isRightSidebarOpen(for: .journal) {
                Divider()

                EntryListView(
                    fileService: fileService,
                    pdfService: pdfService
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hoverManager.isRightSidebarOpen(for: .journal))
        .onChange(of: selectedDate) { _, newDate in
            updateCurrentEntryDate(newDate)
        }
        .onChange(of: entryListViewModel.selectedEntryId) { _, newEntryId in
            if let entryId = newEntryId,
               let entry = entryListViewModel.entries.first(where: { $0.id == entryId }) {
                selectedDate = parseDateFromEntry(entry)
            }
        }
        .onAppear {
            if let entryId = entryListViewModel.selectedEntryId,
               let entry = entryListViewModel.entries.first(where: { $0.id == entryId }) {
                selectedDate = parseDateFromEntry(entry)
            }
        }
    }
    
    private func updateCurrentEntryDate(_ date: Date) {
        guard let currentEntryId = entryListViewModel.selectedEntryId else { return }
        guard let index = entryListViewModel.entries.firstIndex(where: { $0.id == currentEntryId }) else { return }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        let dateYear = calendar.component(.year, from: date)
        
        var updatedEntry = entryListViewModel.entries[index]
        updatedEntry.date = dateString
        updatedEntry.year = dateYear
        
        entryListViewModel.entries[index] = updatedEntry
        entryListViewModel.saveEntry(entry: updatedEntry, content: editorViewModel.text)
    }
    
    private func parseDateFromEntry(_ entry: HumanEntry) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        if let date = dateFormatter.date(from: entry.date) {
            var components = Calendar.current.dateComponents([.month, .day], from: date)
            components.year = entry.year
            return Calendar.current.date(from: components) ?? Date()
        }
        return Date()
    }
}
