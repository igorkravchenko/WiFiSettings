import Observation
import UIKit
import UIKitNavigation

@Perceptible
@MainActor
class WiFiSettingsModel {
    @CasePathable
    enum Destination {
        case connect(ConnectToNetworkModel)
        case detail(NetworkDetailModel)
    }
    
    var destination: Destination?
    var foundNetworks: [Network]
    var isOn: Bool
    var selectedNetworkID: Network.ID?
    
    init(
        destination: Destination? = nil,
        foundNetworks: [Network],
        isOn: Bool = true,
        selectedNetworkID: Network.ID? = nil
    ) {
        self.destination = destination
        self.foundNetworks = foundNetworks
        self.isOn = isOn
        self.selectedNetworkID = selectedNetworkID
    }
    
    func networkTapped(_ network: Network) {
        if network.id == selectedNetworkID {
            destination = .detail(
                NetworkDetailModel(
                    network: network,
                    onConfirmForget: { [weak self] in
                        guard let self else { return }
                        destination = nil
                        selectedNetworkID = nil
                    }
                )
            )
        } else if network.isSecured {
            destination = .connect(
                ConnectToNetworkModel(
                    network: network,
                    onConnect: { [weak self] network in
                        guard let self else { return }
                        destination = nil
                        selectedNetworkID = network.id
                    }
                )
            )
        } else {
            selectedNetworkID = network.id
        }
    }
    
    func infoButtonTapped(network: Network) {
        self.destination = .detail(
            NetworkDetailModel(
                network: network,
                onConfirmForget: { [weak self] in
                    guard let self else { return }
                    destination = nil
                    selectedNetworkID = nil
                }
            )
        )
    }
}

class WiFiSettingsViewController: UICollectionViewController {
    @UIBindable var model: WiFiSettingsModel
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    
    init(model: WiFiSettingsModel) {
        self.model = model
        super.init(
            collectionViewLayout: UICollectionViewCompositionalLayout.list(
                using: UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            )
        )
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Wi-Fi"
        
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }
            configure(cell: cell, indexPath: indexPath, item: item)
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    
        observe { [weak self] in
            guard let self else { return }
            dataSource.apply(.init(model: model), animatingDifferences: true)
        }
        present(item: $model.destination.connect) { model in
            UINavigationController(
                rootViewController: ConnectToNetworkViewController(model: model)
            )
        }
        self.navigationDestination(
            item: $model.destination.detail
        ) { model in
            NetworkDetailViewController(model: model)
        }
    }
    
    override func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard case let .foundNetwork(network) = dataSource.itemIdentifier(for: indexPath) else { return }
        model.networkTapped(network)
    }
    
    private func configure(
        cell: UICollectionViewListCell,
        indexPath: IndexPath,
        item: Item
    ) {
        var configuration = cell.defaultContentConfiguration()
        defer { cell.contentConfiguration = configuration }
        switch item {
        case .isOn:
            configuration.text = "Wi-Fi"
            cell.accessories = [
                .customView(
                    configuration: UICellAccessory.CustomViewConfiguration
                        .init(
                            customView: UISwitch(isOn: $model.isOn),
                            placement: .trailing(displayed: .always)
                        )
                )
            ]
        case let .selectedNetwork(networkID):
            guard let network = model.foundNetworks.first(where: { $0.id == networkID })
            else { return }
            configureNetwork(
                configuration: &configuration,
                cell: cell,
                network: network,
                indexPath: indexPath,
                item: item
            )
            
        case let .foundNetwork(network):
            configureNetwork(
                configuration: &configuration,
                cell: cell,
                network: network,
                indexPath: indexPath,
                item: item
            )
        }
    }
    
    func configureNetwork(
        configuration: inout UIListContentConfiguration,
        cell: UICollectionViewListCell,
        network: Network,
        indexPath: IndexPath,
        item: Item
    ) {
        configuration.text = network.name
        cell.accessories = [.detail(displayed: .always) { [weak self] in
            guard let self else { return }
            model.infoButtonTapped(network: network)
        }]
        if network.isSecured {
            let image = UIImage(systemName: "lock.fill")
            let imageView = UIImageView(image: image)
            imageView.tintColor = .darkText
            cell.accessories.append(
                .customView(
                    configuration: UICellAccessory.CustomViewConfiguration(
                        customView: imageView,
                        placement: .trailing(displayed: .always)
                    )
                )
            )
        }
        let image = UIImage(systemName: "wifi", variableValue: network.connectivity)!
        let imageView = UIImageView(image: image)
        imageView.tintColor = .darkText
        cell.accessories.append(
            .customView(
                configuration: UICellAccessory.CustomViewConfiguration
                    .init(
                        customView: imageView,
                        placement: .trailing(displayed: .always)
                    )
            )
        )
        cell.accessories.append(
            .customView(
                configuration: UICellAccessory.CustomViewConfiguration
                    .init(
                        customView: UIImageView(
                            image: UIImage(systemName: "checkmark")
                        ),
                        placement: .leading(displayed: .always),
                        reservedLayoutWidth: .custom(1)
                    )
            )
        )
    }
    
    enum Section {
        case top
        case foundNetworks
    }
    
    enum Item: Hashable {
        case isOn
        case selectedNetwork(Network.ID)
        case foundNetwork(Network)
    }
}

extension NSDiffableDataSourceSnapshot<WiFiSettingsViewController.Section, WiFiSettingsViewController.Item> {
    @MainActor
    init(model: WiFiSettingsModel) {
        self.init()
        appendSections([.top])
        appendItems([.isOn], toSection: .top)
        
        guard model.isOn else { return }
        
        if let selectedNetworkID = model.selectedNetworkID {
            appendItems([.selectedNetwork(selectedNetworkID)], toSection: .top)
        }
        
        appendSections([.foundNetworks])
        appendItems(
            model.foundNetworks
                .filter { $0.id != model.selectedNetworkID }
                .map { .foundNetwork($0) },
            toSection: .foundNetworks
        )
    }
}

import SwiftUI

#Preview {
    UIViewControllerRepresenting {
        UINavigationController(
            rootViewController: WiFiSettingsViewController(model: WiFiSettingsModel(
                foundNetworks: .mocks,
                isOn: true, selectedNetworkID: [Network].mocks[0].id
            )
            )
        )
    }
}

import SwiftUI

#Preview {
    let model = WiFiSettingsModel(foundNetworks: .mocks)
    UIViewControllerRepresenting<UINavigationController> {
        UINavigationController(
            rootViewController: WiFiSettingsViewController(
                model: model
            )
        )
    }
    .task {
        while true {
            try? await Task.sleep(for: .seconds(1))
            if Bool.random() {
                guard let randomIndex = (0 ..< model.foundNetworks.count).randomElement() else { continue }
                if model.foundNetworks[randomIndex].id != model.selectedNetworkID {
                    model.foundNetworks.remove(at: randomIndex)
                }
            } else {
                model.foundNetworks.append(
                    Network(
                        name: goofyWiFiNames.randomElement()!,
                        isSecured: !(1...1_000).randomElement()!.isMultiple(of: 5),
                        connectivity: Double((1...100).randomElement()!) / 100
                    )
                )
            }
            
        }
    }
}

let goofyWiFiNames = [
    "AirSpace1",
    "Living Room",
    "Courage",
    "Nacho Wifi",
    "FBI Surveillance Van",
    "Peacock-Swagger",
    "Zigo's WaiFai",
    "Gogi's FiWi",
    "Gisya's WiFi Unlimited",
    "Free WiFi",
    "Realst WiFi eva",
    "Some WayFight",
    "Another WiFi Endpoint"
]


extension [Network] {
    static let mocks = [
        Network(
            name: "nachos",
            isSecured: true,
            connectivity: 0.5
        ),
        Network(
            name: "nachos 5G",
            isSecured: true,
            connectivity: 0.75
        ),
        Network(
            name: "Blob Jr's LAN PARTY",
            isSecured: true,
            connectivity: 0.2
        ),
        Network(
            name: "Blob's World",
            isSecured: false,
            connectivity: 1
        )
    ]
}
