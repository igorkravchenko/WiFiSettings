import SwiftUI
import UIKitNavigation

@main
struct WiFiSettingsApp: App {
    var body: some Scene {
        WindowGroup {
            UIViewControllerRepresenting {
                UINavigationController(
                    rootViewController: WiFiSettingsViewController(
                        model: WiFiSettingsModel(
                            destination: .detail(
                                NetworkDetailModel(network: [Network].mocks[1])
                                ),
                            foundNetworks: .mocks,
                            selectedNetworkID: [Network].mocks[1].id
                        )
                    )
                )
            }
        }
    }
}
