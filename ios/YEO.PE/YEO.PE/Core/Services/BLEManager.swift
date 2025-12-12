import Foundation
import CoreBluetooth
import Combine
import UIKit

class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()
    
    // Constants
    private let serviceUUID = CBUUID(string: "00001E00-0000-1000-8000-00805F9B34FB")
    private let uidCharacteristicUUID = CBUUID(string: "00001E01-0000-1000-8000-00805F9B34FB")
    private let appID: [UInt8] = [0xFF, 0xFF]
    
    // Managers
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    
    // State
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var discoveredUsers: [User] = []
    @Published var authorizationStatus: CBManagerAuthorization = CBManager.authorization
    
    // Data
    private var currentUID: String?
    private var uidExpiresAt: Date?
    private var refreshTimer: Timer?
    private var discoveredUIDs: [String: Int] = [:] // UID: RSSI
    private var lastSeenMap: [String: Date] = [:] // UID: Date
    private var scanTimer: Timer?
    private var reportTimer: Timer?
    private var cleanupTimer: Timer?
    private var activePeripherals: [UUID: CBPeripheral] = [:] // Keep reference to connected peripherals
    private var tempUIDs: [UUID: String] = [:] // Temporary storage for UIDs read from characteristics
    private var peripheralMap: [UUID: String] = [:] // Cache: PeripheralID -> UID
    private var isInBackground = false
    
    // Raw Scanning (Debug/Radar)
    enum DeviceType {
        case ios
        case android
        case other
    }
    
    struct RawPeripheral: Identifiable {
        let id: UUID
        let name: String
        let rssi: Int
        let deviceType: DeviceType
        let lastSeen: Date
    }
    
    @Published var isRawScanMode = false
    @Published var rawPeripherals: [UUID: RawPeripheral] = [:]
    
    // Block Filtering
    var blockedUserIds: Set<String> = []
    
    override init() {
        super.init()
        setupAppStateObservers()
    }
    
    func setup() {
        guard centralManager == nil else { return }
        print("🚀 Initializing BLE Managers...")
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "yeopeCentralManager"])
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionRestoreIdentifierKey: "yeopePeripheralManager"])
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - App State Handling
    
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackgrounding), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppForegrounding), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func handleAppBackgrounding() {
        print("🌙 App entered background. Switching to passive background scan...")
        isInBackground = true
        
        scanTimer?.invalidate()
        scanTimer = nil
        
        if centralManager?.state == .poweredOn {
            let services: [CBUUID]? = isRawScanMode ? nil : [serviceUUID]
            centralManager?.scanForPeripherals(withServices: services, options: nil)
            isScanning = true
        }
    }
    
    @objc private func handleAppForegrounding() {
        print("☀️ App entering foreground. Resuming BLE scanning & reporting...")
        isInBackground = false
        
        if let expiry = uidExpiresAt, Date() >= expiry.addingTimeInterval(-60) {
             print("⚠️ UID expired while in background. Refreshing immediately...")
             fetchUIDAndStartAdvertising()
        }
        
        startScanningLoop()
    }
    
    // MARK: - Public Methods
    
    func start() {
        fetchUIDAndStartAdvertising()
        startScanningLoop()
    }
    
    func stop() {
        stopAdvertising()
        stopScanning()
    }
    
    // MARK: - Advertising Logic
    
    private func fetchUIDAndStartAdvertising() {
        BLEService.shared.getUID { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (uid, expiresAt)):
                    print("✅ New UID acquired: \(uid) (Expires: \(expiresAt))")
                    self?.currentUID = uid
                    self?.uidExpiresAt = expiresAt
                    self?.startAdvertising(uid: uid)
                    self?.scheduleUIDRefresh(expiresAt: expiresAt)
                case .failure(let error):
                    print("Failed to get UID: \(error)")
                }
            }
        }
    }
    
    private func scheduleUIDRefresh(expiresAt: Date) {
        refreshTimer?.invalidate()
        
        let now = Date()
        let refreshDate = expiresAt.addingTimeInterval(-10 * 60)
        let interval = refreshDate.timeIntervalSince(now)
        
        if interval > 0 {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.fetchUIDAndStartAdvertising()
            }
        } else {
            fetchUIDAndStartAdvertising()
        }
    }
    
    private func startAdvertising(uid: String) {
        guard let pManager = peripheralManager, pManager.state == .poweredOn else { return }
        
        // Reset services
        pManager.removeAllServices()
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        let characteristic = CBMutableCharacteristic(
            type: uidCharacteristicUUID,
            properties: [.read],
            value: uid.data(using: .utf8),
            permissions: [.readable]
        )
        service.characteristics = [characteristic]
        pManager.add(service)
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: uid
        ]
        
        pManager.startAdvertising(advertisementData)
        isAdvertising = true
        print("Started advertising UID: \(uid)")
    }
    
    private func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
    }
    
    // MARK: - Scanning Logic
    
    private func startScanningLoop() {
        if isInBackground { return }
        
        #if targetEnvironment(simulator)
        // Simulator Mock Mode
        isScanning = true
        isBluetoothEnabled = true
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isRawScanMode {
                let randomId = UUID()
                let typeRandom = Int.random(in: 0...2)
                let deviceType: DeviceType = typeRandom == 0 ? .ios : (typeRandom == 1 ? .android : .other)
                let name = "Mock Device \(Int.random(in: 1...99))"
                
                let mockPeripheral = RawPeripheral(
                    id: randomId,
                    name: name,
                    rssi: Int.random(in: -90...-40),
                    deviceType: deviceType,
                    lastSeen: Date()
                )
                self.rawPeripherals[randomId] = mockPeripheral
                if self.rawPeripherals.count > 20 { self.rawPeripherals.removeValue(forKey: self.rawPeripherals.keys.first!) }
            } else {
                let randomId = UUID().uuidString
                let mockUser = User(
                    id: randomId,
                    email: "mock@test.com",
                    nickname: "SimUser \(Int.random(in: 1...99))",
                    nicknameMask: "SimUser \(Int.random(in: 1...99))",
                    settings: nil,
                    createdAt: nil,
                    lastLoginAt: nil,
                    distance: Double.random(in: 1.0...20.0),
                    hasActiveRoom: false,
                    roomId: nil,
                    roomName: nil
                )
                // Append mock user logic... omitted for brevity but keeping concept
                var current = self.discoveredUsers
                if current.count >= 5 { current.removeFirst() }
                current.append(mockUser)
                self.discoveredUsers = current
            }
        }
        #else
        // Real Device Logic - Duty Cycle
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.performScan()
        }
        performScan()
        
        reportTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.reportDiscoveredUIDs()
        }
        
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.cleanupExpiredUsers()
        }
        #endif
    }
    
    private func performScan() {
        guard let cManager = centralManager, cManager.state == .poweredOn, !isInBackground else { return }
        
        print("📱 Starting BLE Scan for 5s...")
        let services: [CBUUID]? = isRawScanMode ? nil : [serviceUUID]
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: isRawScanMode]
        
        cManager.scanForPeripherals(withServices: services, options: options)
        isScanning = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            // Only stop if still in foreground loop
            if self?.isInBackground == false {
                self?.centralManager?.stopScan()
                self?.isScanning = false
            }
        }
    }
    
    private func stopScanning() {
        scanTimer?.invalidate()
        reportTimer?.invalidate()
        cleanupTimer?.invalidate()
        centralManager?.stopScan()
        isScanning = false
    }
    
    // Strikes Logic
    private var strikesMap: [String: Int] = [:]
    private let maxStrikes = 5
    
    private func cleanupExpiredUsers() {
        let now = Date()
        let timeout: TimeInterval = 15.0
        
        if isRawScanMode {
            for (id, peripheral) in rawPeripherals {
                if now.timeIntervalSince(peripheral.lastSeen) > timeout {
                    rawPeripherals.removeValue(forKey: id)
                }
            }
        }
        
        var uidsToRemove: [String] = []
        for (uid, lastSeen) in lastSeenMap {
            if now.timeIntervalSince(lastSeen) > timeout {
                let currentStrikes = strikesMap[uid] ?? 0
                strikesMap[uid] = currentStrikes + 1
                if strikesMap[uid]! >= maxStrikes {
                    uidsToRemove.append(uid)
                }
            } else {
                strikesMap[uid] = 0
            }
        }
        
        for uid in uidsToRemove {
            lastSeenMap.removeValue(forKey: uid)
            discoveredUIDs.removeValue(forKey: uid)
            strikesMap.removeValue(forKey: uid)
        }
        
        var validUIDs: [String: Int] = [:]
        for (uid, rssi) in discoveredUIDs {
            if lastSeenMap[uid] != nil {
                validUIDs[uid] = rssi
            }
        }
        discoveredUIDs = validUIDs
        
        if discoveredUIDs.isEmpty {
            DispatchQueue.main.async { self.discoveredUsers = [] }
        }
    }
    
    private func reportDiscoveredUIDs() {
        guard TokenManager.shared.isLoggedIn else { return }
        guard !discoveredUIDs.isEmpty else { return }
        
        let scannedData = discoveredUIDs.map { ScannedUID(uid: $0.key, rssi: $0.value) }
        BLEService.shared.reportScanResults(uids: scannedData) { [weak self] result in
            switch result {
            case .success(let users):
                // Filter blocked users
                let blockList = self?.blockedUserIds ?? []
                let filtered = users.filter { !blockList.contains($0.id) }
                DispatchQueue.main.async { self?.discoveredUsers = filtered }
            case .failure(let error):
                print("Failed to report: \(error)")
            }
        }
    }
    
    private func handleDiscoveredUID(_ uid: String, rssi: Int, peripheralId: UUID? = nil) {
        if uid.count == 6 {
            discoveredUIDs[uid] = rssi
            lastSeenMap[uid] = Date()
            if let pid = peripheralId { peripheralMap[pid] = uid }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        authorizationStatus = CBManager.authorization
        isBluetoothEnabled = (central.state == .poweredOn)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Raw Mode
        if isRawScanMode {
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unknown"
            var deviceType: DeviceType = .other
            
            if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, manufacturerData.count >= 2 {
                 let companyId = manufacturerData.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self) }
                 if companyId == 0x004C { deviceType = .ios }
                 else if companyId == 0x0075 || companyId == 0x00E0 { deviceType = .android }
            }
            // Logic for Service UUIDs omitted for brevity but should be here if crucial.
            
            let rawPeripheral = RawPeripheral(id: peripheral.identifier, name: name, rssi: RSSI.intValue, deviceType: deviceType, lastSeen: Date())
            DispatchQueue.main.async { self.rawPeripherals[peripheral.identifier] = rawPeripheral }
        }
        
        // Target Logic
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        
        if let localName = localName, localName.count == 6 {
            handleDiscoveredUID(localName, rssi: RSSI.intValue, peripheralId: peripheral.identifier)
        } else if !isRawScanMode {
            let hasServiceUUID = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.contains(serviceUUID) ?? false
            if hasServiceUUID {
                if let cachedUID = peripheralMap[peripheral.identifier] {
                    handleDiscoveredUID(cachedUID, rssi: RSSI.intValue, peripheralId: peripheral.identifier)
                } else {
                    activePeripherals[peripheral.identifier] = peripheral
                    peripheral.delegate = self
                    centralManager?.connect(peripheral, options: nil)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        activePeripherals.removeValue(forKey: peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        activePeripherals.removeValue(forKey: peripheral.identifier)
        tempUIDs.removeValue(forKey: peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                activePeripherals[peripheral.identifier] = peripheral
                peripheral.delegate = self
            }
        }
        if dict[CBCentralManagerRestoredStateScanServicesKey] != nil {
            isScanning = true
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([uidCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == uidCharacteristicUUID {
            peripheral.readValue(for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let uid = String(data: data, encoding: .utf8) {
             peripheral.readRSSI()
             tempUIDs[peripheral.identifier] = uid
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let uid = tempUIDs[peripheral.identifier] {
            handleDiscoveredUID(uid, rssi: RSSI.intValue, peripheralId: peripheral.identifier)
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn, let uid = currentUID, !isAdvertising {
            startAdvertising(uid: uid)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        if dict[CBPeripheralManagerRestoredStateServicesKey] != nil {
            isAdvertising = true
        }
    }
}
