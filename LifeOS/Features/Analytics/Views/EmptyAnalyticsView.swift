//
//  EmptyAnalyticsView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Empty state shown when no analytics data exists
struct EmptyAnalyticsView: View {
    let onNavigateToSettings: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Analytics Data")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Process your journal entries to see analytics and insights")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Go to Settings") {
                onNavigateToSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    EmptyAnalyticsView(onNavigateToSettings: {})
}
