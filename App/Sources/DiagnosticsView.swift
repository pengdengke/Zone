import SwiftUI

struct DiagnosticsView: View {
    let messages: [String]

    var body: some View {
        Group {
            if messages.isEmpty {
                Text("No diagnostics yet.")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                List(messages, id: \.self) { message in
                    Text(message)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .frame(minHeight: 180)
    }
}
