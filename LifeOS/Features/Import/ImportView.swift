import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ImportViewModel
    
    @State private var isFilePickerPresented = false
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.importedEntries.isEmpty || viewModel.isProcessing {
                progressiveResultsView
            } else {
                initialView
            }
        }
        .frame(width: 600, height: 500)
        .background(theme.backgroundColor)
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.png, .jpeg, .heic, .heif, .pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.processFiles(urls)
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private var progressiveResultsView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(viewModel.isProcessing ? "Importing Entries" : "Review Imported Entries")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                if viewModel.isProcessing {
                    Text("\(viewModel.currentProgress) of \(viewModel.totalFiles)")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                } else {
                    Text("\(viewModel.importedEntries.count) \(viewModel.importedEntries.count == 1 ? "entry" : "entries")")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
            }
            .padding(16)
            
            Divider()
                .background(theme.dividerColor)
            
            // Scrollable results list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.importedEntries.enumerated()), id: \.element.filename) { index, entry in
                            EntryResultRow(entry: entry, viewModel: viewModel)
                                .id(entry.filename)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.importedEntries.count) { _, newCount in
                    if newCount > 0, let lastEntry = viewModel.importedEntries.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.filename, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Processing indicator at bottom
            if viewModel.isProcessing {
                Divider()
                    .background(theme.dividerColor)
                
                processingFooter
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Error message if any
            if let error = viewModel.errorMessage {
                Divider()
                    .background(theme.dividerColor)
                
                HStack {
                    Image(systemName: error.contains("cancel") ? "info.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(error.contains("cancel") ? theme.accentColor : theme.destructive)
                    
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    
                    Spacer()
                }
                .padding(12)
                .background(error.contains("cancel") ? theme.accentColor.opacity(0.1) : theme.destructive.opacity(0.1))
            }
            
            Divider()
                .background(theme.dividerColor)
            
            // Footer with action buttons
            HStack(spacing: 12) {
                Button(viewModel.isProcessing ? "Close" : "Cancel") {
                    if viewModel.isProcessing {
                        dismiss()
                    } else {
                        viewModel.reset()
                        dismiss()
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.hoveredBackground)
                .cornerRadius(6)
                
                Spacer()
                
                Button("Import \(viewModel.importedEntries.count) \(viewModel.importedEntries.count == 1 ? "Entry" : "Entries")") {
                    viewModel.importEntries()
                    dismiss()
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(viewModel.importedEntries.isEmpty ? theme.dividerColor : theme.accentColor)
                .cornerRadius(6)
                .disabled(viewModel.importedEntries.isEmpty || viewModel.isProcessing)
            }
            .padding(16)
        }
    }
    
    private var processingFooter: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing \(viewModel.currentProgress) of \(viewModel.totalFiles)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.primaryText)
                
                if !viewModel.currentFile.isEmpty {
                    Text(viewModel.currentFile)
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            Button("Cancel") {
                viewModel.cancelImport()
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundColor(theme.destructive)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.destructive.opacity(0.1))
            .cornerRadius(6)
        }
        .padding(16)
        .background(theme.hoveredBackground)
    }
    
    private var initialView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.text.image")
                .font(.system(size: 64))
                .foregroundColor(theme.secondaryText)
            
            VStack(spacing: 8) {
                Text("Import Journal Entries")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                if KeychainService.shared.hasAPIKey() {
                    Text("Using OpenAI GPT-4o Vision for high-accuracy OCR")
                        .font(.system(size: 13))
                        .foregroundColor(theme.accentColor)
                    
                    Text("Select images (PNG, JPEG, HEIC) or PDFs of your journal pages")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("Estimated cost: ~$0.01-0.02 per image")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                } else {
                    Text("Add your OpenAI API key in Settings for best results")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Settings") {
                        showSettings = true
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .foregroundColor(theme.accentColor)
                    .padding(.top, 4)
                }
            }
            
            if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(theme.destructive)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    if error.contains("API key") {
                        Button("Open Settings") {
                            showSettings = true
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .foregroundColor(theme.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.accentColor.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.hoveredBackground)
                .cornerRadius(6)
                
                Button("Select Files") {
                    isFilePickerPresented = true
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.buttonTextHover)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.accentColor)
                .cornerRadius(6)
            }
            .padding(.bottom, 24)
        }
    }
    

}
