
import SwiftUI

struct EntryListView: View {
    @Environment(EntryListViewModel.self) private var viewModel
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(SidebarHoverManager.self) private var hoverManager
    @Environment(\.theme) private var theme

    @State private var isHoveringNewEntry = false
    @State private var isHoveringPin = false
    @State private var showImportSheet = false
    
    let fileService: FileManagerService
    let pdfService: PDFExportService
    
    var body: some View {
        @Bindable var vm = viewModel
        
        VStack(spacing: 0) {
            // Top row: Pin button and three-dot menu
            HStack {
                // Pin button (now on the left/inner edge)
                Button(action: {
                    hoverManager.toggleRightPin(for: .journal)
                }) {
                    Image(systemName: hoverManager.isRightSidebarPinned(for: .journal) ? "chevron.right.2" : "line.horizontal.3")
                        .foregroundColor(isHoveringPin ? theme.buttonTextHover : theme.buttonText)
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHoveringPin ? theme.hoveredBackground : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringPin = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .accessibilityLabel("Toggle sidebar pin")
                .help("Toggle sidebar pin")

                Spacer()

                // Three-dot menu
                Menu {
                    Button("File Location") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: fileService.documentsDirectory.path)
                    }
                    
                    Button("Import Entries") {
                        showImportSheet = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(theme.buttonText)
                        .rotationEffect(.degrees(90))
                        .frame(width: 16, height: 16)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // New Entry button (centered)
            Button(action: createNewEntry) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                        .foregroundColor(isHoveringNewEntry ? theme.buttonTextHover : theme.buttonText)
                    Text("New Entry")
                        .font(.system(size: 13))
                        .foregroundColor(isHoveringNewEntry ? theme.buttonTextHover : theme.buttonText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringNewEntry = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help("New entry")
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(vm.groupedEntries) { yearGroup in
                        Section {
                            if vm.expandedYears.contains(yearGroup.year) {
                                ForEach(yearGroup.months) { monthGroup in
                                    VStack(spacing: 0) {
                                        MonthHeaderView(
                                            monthName: monthGroup.monthName,
                                            count: monthGroup.count,
                                            isExpanded: vm.expandedMonths.contains("\(yearGroup.year)-\(monthGroup.month)"),
                                            onToggle: {
                                                vm.toggleMonth(yearGroup.year, monthGroup.month)
                                            }
                                        )
                                        
                                        if vm.expandedMonths.contains("\(yearGroup.year)-\(monthGroup.month)") {
                                            ForEach(monthGroup.entries) { entry in
                                                VStack(spacing: 0) {
                                                    EntryRowView(
                                                        entry: entry,
                                                        isSelected: vm.selectedEntryId == entry.id,
                                                        isHovered: vm.hoveredEntryId == entry.id,
                                                        hoveredTrashId: vm.hoveredTrashId,
                                                        hoveredExportId: vm.hoveredExportId,
                                                        onSelect: {
                                                            if vm.selectedEntryId != entry.id {
                                                                if let currentId = vm.selectedEntryId {
                                                                    let currentEntry = vm.entries.first(where: { $0.id == currentId }) ?? vm.draftEntry
                                                                    if let currentEntry = currentEntry {
                                                                        vm.saveEntry(entry: currentEntry, content: editorViewModel.text)
                                                                    }
                                                                }
                                                                
                                                                if vm.isCurrentEntryDraft && editorViewModel.text.isEmpty {
                                                                    print("Discarding empty draft entry")
                                                                    vm.draftEntry = nil
                                                                }
                                                                
                                                                vm.selectedEntryId = entry.id
                                                                if let content = vm.loadEntry(entry: entry) {
                                                                    editorViewModel.isLoadingContent = true
                                                                    editorViewModel.text = content
                                                                    editorViewModel.isLoadingContent = false
                                                                }
                                                            }
                                                        },
                                                        onDelete: {
                                                            if let newText = vm.deleteEntry(entry: entry) {
                                                                editorViewModel.isLoadingContent = true
                                                                editorViewModel.text = newText
                                                                editorViewModel.isLoadingContent = false
                                                            }
                                                        },
                                                        onExport: {
                                                            if vm.selectedEntryId == entry.id {
                                                                vm.saveEntry(entry: entry, content: editorViewModel.text)
                                                            }
                                                            
                                                            if let content = vm.loadEntry(entry: entry) {
                                                                pdfService.exportEntryAsPDF(
                                                                    entry: entry,
                                                                    content: content,
                                                                    selectedFont: editorViewModel.settings.selectedFont,
                                                                    fontSize: editorViewModel.settings.fontSize,
                                                                    lineHeight: editorViewModel.lineHeight
                                                                )
                                                            }
                                                        }
                                                    )
                                                    .padding(.leading, 8)
                                                    .onHover { hovering in
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            vm.hoveredEntryId = hovering ? entry.id : nil
                                                        }
                                                    }
                                                    
                                                    if entry.id != monthGroup.entries.last?.id {
                                                        Divider()
                                                            .padding(.leading, 28)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            YearHeaderView(
                                year: yearGroup.year,
                                count: yearGroup.totalCount,
                                isExpanded: vm.expandedYears.contains(yearGroup.year),
                                onToggle: {
                                    vm.toggleYear(yearGroup.year)
                                }
                            )
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .frame(width: 200)
        .background(theme.backgroundColor)
        .sheet(isPresented: $showImportSheet) {
            ImportView(viewModel: ImportViewModel(fileService: fileService, entryListViewModel: viewModel))
        }
    }
    
    private func createNewEntry() {
        if editorViewModel.text.isEmpty {
            print("Current entry is already empty, not creating a new one")
            return
        }
        
        if let currentId = viewModel.selectedEntryId {
            let currentEntry = viewModel.entries.first(where: { $0.id == currentId }) ?? viewModel.draftEntry
            if let currentEntry = currentEntry {
                viewModel.saveEntry(entry: currentEntry, content: editorViewModel.text)
            }
        }
        
        let newText = viewModel.createDraftEntry()
        editorViewModel.isLoadingContent = true
        editorViewModel.text = newText
        editorViewModel.isLoadingContent = false
        editorViewModel.randomizePlaceholder()
    }
}
