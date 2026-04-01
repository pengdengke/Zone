import SwiftUI

struct DiagnosticsView: View {
    let messages: [String]
    let emptyStateText: String

    var body: some View {
        Group {
            if messages.isEmpty {
                Text(emptyStateText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { entry in
                            Text(entry.element)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 180)
    }
}
