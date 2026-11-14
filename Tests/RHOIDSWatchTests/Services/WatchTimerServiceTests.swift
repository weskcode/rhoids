import Foundation
import Testing
@testable import RHOIDSWatch

@MainActor
struct WatchTimerServiceTests {

    @Test("cancelFromPhone ignores mismatched runID and retires it")
    func cancelFromPhoneIgnoresMismatchedAndRetires() async {
        let service = makeService()
        await service.start(duration: 180, preset: .recommended)

        let staleRunID = UUID()
        await service.cancelFromPhone(runID: staleRunID)

        #expect(await service.isRunning == true, "Mismatched phone cancel must not stop a newer Watch timer")
        await service.stop()

        let adopted = await service.adopt(
            endDate: Date().addingTimeInterval(180),
            presetName: "Recommended",
            duration: 180,
            remoteRunID: staleRunID,
            sentAt: Date()
        )
        #expect(adopted == false, "Retired runID must not be resurrected by out-of-order adopt")
        #expect(await service.isRunning == false)
    }

    @Test("adopt ignores message whose sentAt predates active Watch timer")
    func adoptIgnoresStaleSentAt() async {
        let service = makeService()
        await service.start(duration: 180, preset: .recommended)

        let adopted = await service.adopt(
            endDate: Date().addingTimeInterval(300),
            presetName: "Max",
            duration: 300,
            remoteRunID: UUID(),
            sentAt: Date().addingTimeInterval(-30)
        )

        #expect(adopted == false)
        #expect(await service.currentDuration == 180)
        await service.stop()
    }

    @Test("reconcileInactivePhoneState ignores stale response predating active Watch timer")
    func reconcileIgnoresStaleInactiveResponse() async {
        let service = makeService()
        await service.start(duration: 180, preset: .recommended)

        await service.reconcileInactivePhoneState(phoneResponseSentAt: Date().addingTimeInterval(-30))
        #expect(await service.isRunning == true)

        await service.reconcileInactivePhoneState(phoneResponseSentAt: Date().addingTimeInterval(1))
        #expect(await service.isRunning == false)
    }

    private func makeService() -> WatchTimerService {
        WatchTimerService(connectivityService: WatchConnectivityService())
    }
}
