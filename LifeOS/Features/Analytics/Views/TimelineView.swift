//
//  TimelineView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Timeline view with year → month drill-down hierarchy
struct TimelineView: View {
    @State private var selectedMonth: MonthSummary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Timeline")
                    .font(.headline)

                Text("Monthly and yearly summaries will appear here once data is processed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
            }
            .padding()
        }
        .sheet(item: $selectedMonth) { month in
            MonthDetailView(month: month)
        }
    }
}

#Preview {
    TimelineView()
}
