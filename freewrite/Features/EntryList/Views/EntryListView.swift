
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
                LazyVStack(spacing: 0) {
                    ForEach(vm.entries) { entry in
                        EntryRowView(
                            entry: entry,
                            isSelected: vm.selectedEntryId == entry.id,
                            isHovered: vm.hoveredEntryId == entry.id,
                            hoveredTrashId: vm.hoveredTrashId,
                            hoveredExportId: vm.hoveredExportId,
                            onSelect: {
                                if vm.selectedEntryId != entry.id {
                                    if let currentId = vm.selectedEntryId,
                                       let currentEntry = vm.entries.first(where: { $0.id == currentId }) {
                                        vm.saveEntry(entry: currentEntry, content: editorViewModel.text)
                                    }
                                    
                                    vm.selectedEntryId = entry.id
                                    if let content = vm.loadEntry(entry: entry) {
                                        editorViewModel.text = content
                                    }
                                }
                            },
                            onDelete: {
                                if let newText = vm.deleteEntry(entry: entry) {
                                    editorViewModel.text = newText
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
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.hoveredEntryId = hovering ? entry.id : nil
                            }
                        }
                        
                        if entry.id != vm.entries.last?.id {
                            Divider()
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
