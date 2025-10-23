//
//  StressorsProtectiveView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Split view showing stressors and protective factors
struct StressorsProtectiveView: View {
    let stressors: [String]
    let protectiveFactors: [String]

    var body: some View {
        HStack(spacing: 16) {
            // Stressors column
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Stressors")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(stressors, id: \.self) { stressor in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.red)
                            Text(stressor)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }

            // Protective factors column
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Going Well")
                        .font(.headline)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(protectiveFactors, id: \.self) { factor in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.green)
                            Text(factor)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

#Preview {
    StressorsProtectiveView(
        stressors: [
            "Upcoming project deadline",
            "Not sleeping well",
            "Financial uncertainty"
        ],
        protectiveFactors: [
            "Regular exercise routine",
            "Strong friend support",
            "Making progress on side project"
        ]
    )
    .padding()
}
