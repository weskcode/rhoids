import SwiftUI
import FamilyControls

struct FocusLockAppPickerView: View {
    @Bindable var screenTimeService: ScreenTimeService

    var body: some View {
        FamilyActivityPicker(
            headerText: "Choose apps to block when your timer ends.",
            footerText: "You can change this anytime.",
            selection: $screenTimeService.selection
        )
        .navigationTitle("Blocked Apps")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: screenTimeService.selection) {
            screenTimeService.saveSelection()
            // App selection is an input to the effective-mode resolution
            // (blocking only "engages" once apps are picked) - an
            // already-running timer must reflect a change made mid-session,
            // not just the next one.
            Task { @MainActor in
                await AppServices.shared?.timerService.rescheduleForFocusLockChange()
            }
        }
    }
}
