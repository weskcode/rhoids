import WidgetKit
import SwiftUI

@main
struct RHOIDSWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomeScreenWidget()
        LockScreenWidget()
        RHOIDSLiveActivityWidget()
    }
}
