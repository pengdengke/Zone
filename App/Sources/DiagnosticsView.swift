import SwiftUI

struct DiagnosticsView: View {
    let messages: [String]

    var body: some View {
        List(messages, id: \.self) { message in
            Text(message)
                .font(.system(.body, design: .monospaced))
        }
        .frame(minHeight: 180)
    }
}
