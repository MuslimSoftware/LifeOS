import SwiftUI

struct JournalPageView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(EntryListViewModel.self) private var entryListViewModel
    @Environment(\.theme) private var theme
    
    let pdfService: PDFExportService
    let fileService: FileManagerService
    
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
                        availableFonts: NSFontManager.shared.availableFontFamilies
                    )
                }
            }
            
            if entryListViewModel.showingSidebar {
                Divider()
                
                EntryListView(
                    fileService: fileService,
                    pdfService: pdfService
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: entryListViewModel.showingSidebar)
    }
}
