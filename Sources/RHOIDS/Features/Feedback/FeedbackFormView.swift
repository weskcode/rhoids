import SwiftUI
import UIKit

/// User-initiated feedback form that hands a message off to the configured
/// mail app and preserves the draft when that handoff is unavailable.
struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var message = ""
    @State private var showingMailUnavailable = false
    @State private var copiedSupportEmail = false

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Feedback message")
                } header: {
                    Text("What could be better?")
                } footer: {
                    Text("Your feedback goes straight to the developer and helps shape what gets fixed next.")
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(trimmedMessage.isEmpty)
                }
            }
            .alert("Mail Isn’t Available", isPresented: $showingMailUnavailable) {
                Button("Copy Support Email") {
                    UIPasteboard.general.string = AppStoreInfo.supportEmail
                    copiedSupportEmail = true
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your message is still here. You can copy the support address and send it with another mail app.")
            }
            .sensoryFeedback(.success, trigger: copiedSupportEmail)
        }
    }

    private func send() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppStoreInfo.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "RHOIDS Feedback"),
            URLQueryItem(name: "body", value: trimmedMessage)
        ]
        guard let url = components.url else {
            showingMailUnavailable = true
            return
        }
        openURL(url) { accepted in
            if accepted {
                dismiss()
            } else {
                showingMailUnavailable = true
            }
        }
    }
}

#if DEBUG
#Preview {
    FeedbackFormView()
}
#endif
