//
//  AnalyticsProgressView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Modal sheet showing analytics processing progress
struct AnalyticsProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var progress: Double = 0.0
    @State private var statusText: String = "Starting..."
    @State private var currentOperation: String = "Initializing"
    @State private var processedCount: Int = 0
    @State private var totalCount: Int = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var startTime: Date = Date()
    @State private var showCancelConfirmation: Bool = false
    @State private var isComplete: Bool = false
    @State private var error: String?
    @State private var processingTask: Task<Void, Never>?

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if isComplete {
                completionView
            } else if error != nil {
                errorView
            } else {
                progressView
            }
        }
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 600, minHeight: 420, idealHeight: 480, maxHeight: 600)
        .background(theme.backgroundColor)
        .onReceive(timer) { _ in
            updateProgress()
        }
        .onAppear {
            startProcessing()
        }
        .onDisappear {
            processingTask?.cancel()
        }
    }

    private var progressView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(theme.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Processing Journal Entries")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primaryText)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(theme.accentColor)
                    .frame(height: 12)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.surfaceColor)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack {
                    Text(currentOperation)
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                        Text(formatTime(elapsedTime))
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                            .monospacedDigit()
                    }
                }
            }

            Spacer()

            Button("Cancel Processing") {
                showCancelConfirmation = true
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundColor(theme.destructive)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(theme.destructive.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.destructive.opacity(0.2), lineWidth: 1)
            )
            .confirmationDialog("Cancel Processing", isPresented: $showCancelConfirmation) {
                Button("Stop Processing", role: .destructive) {
                    cancelProcessing()
                }
            } message: {
                Text("This will stop processing. You can resume later from Settings.")
            }
        }
        .padding(.all, 40)
    }

    private var completionView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("Processing Complete")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.primaryText)

                Text("All entries have been analyzed successfully")
                    .font(.callout)
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("\(totalCount)")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                        .monospacedDigit()
                    Text("Entries Processed")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text(formatTime(elapsedTime))
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                        .monospacedDigit()
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(theme.surfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.dividerColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.accentColor)
            .cornerRadius(8)
            .shadow(color: theme.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.all, 40)
    }

    private var errorView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            VStack(spacing: 12) {
                Text("Processing Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.primaryText)

                Text(error ?? "An unknown error occurred")
                    .font(.callout)
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            Spacer()

            HStack(spacing: 16) {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.dividerColor.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(8)

                Button("Retry") {
                    retryProcessing()
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(theme.accentColor)
                .cornerRadius(8)
                .shadow(color: theme.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.all, 40)
    }

    private var estimatedRemainingTime: String {
        guard totalCount > 0, processedCount > 0, elapsedTime > 0 else {
            return "Calculating..."
        }

        let rate = Double(processedCount) / elapsedTime
        let remaining = Double(totalCount - processedCount) / rate
        return formatTime(remaining)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func updateProgress() {
        guard !isComplete, error == nil else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }

    private func startProcessing() {
        processingTask = Task {
            do {
                let fileService = FileManagerService()
                let allEntries = fileService.loadExistingEntries()
                totalCount = allEntries.count

                guard totalCount > 0 else {
                    await MainActor.run {
                        error = "No journal entries found to process"
                    }
                    return
                }

                let dbService = DatabaseService.shared
                try dbService.initialize()

                let chunkRepo = ChunkRepository(dbService: dbService)
                let analyticsRepo = EntryAnalyticsRepository(dbService: dbService)
                let monthSummaryRepo = MonthSummaryRepository(dbService: dbService)
                let yearSummaryRepo = YearSummaryRepository(dbService: dbService)

                let pipeline = AnalyticsPipelineService(
                    fileManagerService: fileService,
                    chunkRepository: chunkRepo,
                    analyticsRepository: analyticsRepo,
                    monthSummaryRepository: monthSummaryRepo,
                    yearSummaryRepository: yearSummaryRepo
                )

                try await pipeline.processAllEntries { current, total in
                    Task { @MainActor in
                        guard !Task.isCancelled else { return }
                        processedCount = current
                        totalCount = total
                        progress = Double(current) / Double(total)
                        statusText = "Processing entry \(current) of \(total)..."
                        currentOperation = "Analyzing emotions and events"
                    }
                }

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    currentOperation = "Generating summaries..."
                }

                try await pipeline.updateSummaries()

                await MainActor.run {
                    isComplete = true
                }

            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func cancelProcessing() {
        processingTask?.cancel()
        dismiss()
    }

    private func retryProcessing() {
        error = nil
        progress = 0
        processedCount = 0
        startTime = Date()
        elapsedTime = 0
        isComplete = false
        startProcessing()
    }
}

#Preview {
    AnalyticsProgressView()
}
