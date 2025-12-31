import Foundation
import CoreBluetooth
import Combine
import UIKit

extension Notification.Name {
    static let identityUpdated = Notification.Name("IdentityUpdated")
}

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
    
    // Stealth Mode
    @Published var isStealthMode = false {
        didSet {
            print("👻 Stealth Mode Changed: \(isStealthMode)")
            if isStealthMode {
                stopAdvertising()
            } else {
                if !isAdvertising {
                    fetchUIDAndStartAdvertising()
                }
            }
        }
    }
    
    // Block Filtering
    var blockedUserIds: Set<String> = []
    
    override init() {
        super.init()
        setupAppStateObservers()
        setup() // Initialize Managers immediately
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
        print("🌙 App entered background. Switching to Continuous Scan (State Restoration Mode)...")
        isInBackground = true
        
        // Ensure Advertising is active
        // State Restoration: We should restart advertising if it was stopped, but if it's already running, do NOT touch it (idempotent).
        if let uid = currentUID {
             startAdvertising(uid: uid) // Safe call thanks to check inside startAdvertising
        }
        
        // Stop Duty Cycle Timers
        scanTimer?.invalidate()
        scanTimer = nil
        reportTimer?.invalidate()
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        // Start Continuous Scan (No Timeout)
        startContinuousScan()
    }
    
    @objc private func handleAppForegrounding() {
        print("☀️ App entering foreground. Switching to Active Duty Cycle...")
        isInBackground = false
        
        // Stop Continuous Scan (Background session)
        // Ensure we start a fresh session for the foreground duty cycle
        centralManager?.stopScan()
        
        if let expiry = uidExpiresAt, Date() >= expiry.addingTimeInterval(-60) {
             print("⚠️ UID expired while in background. Refreshing immediately...")
             fetchUIDAndStartAdvertising()
        }
        
        refreshImmediate()
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
        guard TokenManager.shared.isLoggedIn else {
            print("🚫 BLE Fetch Skipped: User not logged in")
            return
        }
        
        BLEService.shared.getUID { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (uid, expiresAt, nicknameMask)):
                    print("✅ New UID acquired: \(uid) (Expires: \(expiresAt))")
                    self?.currentUID = uid
                    self?.uidExpiresAt = expiresAt
                    
                    // Force restart only if UID changed
                    self?.startAdvertising(uid: uid)
                    self?.scheduleUIDRefresh(expiresAt: expiresAt)
                    
                    // Notify Identity Update (Nickname Mask Regenerated)
                    if let mask = nicknameMask {
                        print("🎭 Identity regenerated: \(mask)")
                        NotificationCenter.default.post(
                            name: .identityUpdated,
                            object: nil,
                            userInfo: ["nicknameMask": mask]
                        )
                    }
                    
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
        guard !isStealthMode else { 
            print("🚫 Stealth Mode is ON. Advertising skipped.")
            return 
        }
        guard let pManager = peripheralManager, pManager.state == .poweredOn else { return }
        
        // Removed Idempotency Check: Always force restart to ensure state is fresh, especially for Background transitions.
        
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
    
    func refreshImmediate() {
        print("⚡️ Force Refreshing Radar (Quick Scan 1s)...")
        scanTimer?.invalidate()
        performScan(duration: 1.0)
        startScanningLoop()
    }
    
    private func startContinuousScan() {
        guard let cManager = centralManager, cManager.state == .poweredOn else { return }
        
        print("🕵️‍♂️ Starting Continuous Background Scan...")
        let services: [CBUUID]? = [serviceUUID]
        // AllowDuplicates false in background is better for battery, but we need strictly standard scan
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        
        cManager.scanForPeripherals(withServices: services, options: options)
        isScanning = true
    }

    private func startScanningLoop() {
        // ... (Existing implementation) ...
        // Ensure no isInBackground check
        
        #if targetEnvironment(simulator)
        // ... (Simulator Logic unchanged) ...
        #else
        // Real Device Logic - Duty Cycle
        // Scan every 10 seconds
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.performScan(duration: 5.0) // Increased to 5s for better background discovery
        }
        
        // Cleanup every 5 seconds
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.cleanupExpiredUsers()
        }
        
        // Initial immediately
        performScan(duration: 5.0)
        #endif
    }
    
    private func performScan(duration: TimeInterval = 5.0) {
        guard let cManager = centralManager, cManager.state == .poweredOn else { return }
        
        // If in background, ignore duty cycle requests (Continuous scan is running)
        if isInBackground { return }
        
        print("📱 Starting BLE Scan for \(duration)s...")
        let services: [CBUUID]? = [serviceUUID]
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: isRawScanMode]
        
        cManager.scanForPeripherals(withServices: services, options: options)
        isScanning = true
        
        // Stop after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
             // Only stop if we are still in foreground (Duty Cycle Mode)
             if self?.isInBackground == false {
                 self?.centralManager?.stopScan()
                 self?.isScanning = false
                 self?.reportDiscoveredUIDs()
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
            
            // Background Reporting Trigger (Throttled?)
            // In Continuous Scan (Background), we don't have the scan loop to trigger reports.
            // So we trigger it on discovery. To avoid spam, we rely on the server to handle frequency or just send it.
            // Since discoveredUIDs accumulates, we send the whole batch.
            if isInBackground {
                 print("🌙 Background Discovery: Triggering Report for \(uid)")
                 cleanupExpiredUsers() // Ensure we don't report stale users
                 reportDiscoveredUIDs()
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🦷 Bluetooth State Updated: \(central.state.rawValue)")
        authorizationStatus = CBManager.authorization
        isBluetoothEnabled = (central.state == .poweredOn)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // DEBUG LOG
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        // print("📡 Saw Device: \(localName ?? peripheral.name ?? "Unknown") | UUIDs: \(serviceUUIDs?.description ?? "nil") | RSSI: \(RSSI)")

        // Raw Mode
        if isRawScanMode {
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unknown"
            var deviceType: DeviceType = .other
            
            if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, manufacturerData.count >= 2 {
                 let companyId = manufacturerData.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self) }
                 if companyId == 0x004C { deviceType = .ios }
                 else if companyId == 0x0075 || companyId == 0x00E0 { deviceType = .android }
            }
            
            let rawPeripheral = RawPeripheral(id: peripheral.identifier, name: name, rssi: RSSI.intValue, deviceType: deviceType, lastSeen: Date())
            DispatchQueue.main.async { self.rawPeripherals[peripheral.identifier] = rawPeripheral }
        }
        
        // Target Logic
        
        // Handling Background Devices (Overflow Area):
        // When an iOS device is advertising in the background, the `ServiceUUIDs` and `LocalName`
        // are often STRIPPED from the `advertisementData` to save space.
        // However, iOS only delivers this event because we explicitly scanned for `[serviceUUID]`.
        // Therefore, if we are NOT in raw mode, we can assume ANY discovery is our target.
        
        let hasServiceUUID = serviceUUIDs?.contains(serviceUUID) == true
        let hasValidLocalName = localName?.count == 6
        
        // Trust the discovery if we found exactly what we were looking for (Implicit Trust)
        let isImplicitMatch = !isRawScanMode
        
        guard hasServiceUUID || hasValidLocalName || isImplicitMatch else { return }
        
        if let localName = localName, localName.count == 6 {
             print("🔎 Found User Signal (Foreground): \(localName) (RSSI: \(RSSI))")
             handleDiscoveredUID(localName, rssi: RSSI.intValue, peripheralId: peripheral.identifier)
        } else {
             // Background Device or Implicit Match: We must connect to read the UID
             activePeripherals[peripheral.identifier] = peripheral
             peripheral.delegate = self
             print("🔗 Connecting to potential background user \(peripheral.name ?? "Unknown") to read UID...")
             centralManager?.connect(peripheral, options: nil)
        }
    }

    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("🤝 Connected to \(peripheral.name ?? "Unknown"). Discovering services...")
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
             print("📬 Read UID from Characteristic: \(uid)")
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
