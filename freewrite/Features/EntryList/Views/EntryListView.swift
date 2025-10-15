
import SwiftUI

struct EntryListView: View {
    @Environment(EntryListViewModel.self) private var viewModel
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(\.theme) private var theme
    
    @State private var isHoveringHistory = false
    
    let fileService: FileManagerService
    let pdfService: PDFExportService
    
    var body: some View {
        @Bindable var vm = viewModel
        
        VStack(spacing: 0) {
            Button(action: {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: fileService.documentsDirectory.path)
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("History")
                                .font(.system(size: 13))
                                .foregroundColor(isHoveringHistory ? theme.buttonTextHover : theme.buttonText)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(isHoveringHistory ? theme.buttonTextHover : theme.buttonText)
                        }
                        Text(fileService.documentsDirectory.path)
                            .font(.system(size: 10))
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onHover { hovering in
                isHoveringHistory = hovering
            }
            
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
    }
}
