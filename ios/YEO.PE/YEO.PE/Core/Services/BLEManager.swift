import Foundation
import CoreBluetooth
import Combine
import UIKit

class BLEManager: NSObject, ObservableObject {
    static let shared = BLEManager()
    
    // Constants
    private let serviceUUID = CBUUID(string: "00001E00-0000-1000-8000-00805F9B34FB")
    private let uidCharacteristicUUID = CBUUID(string: "00001E01-0000-1000-8000-00805F9B34FB") // New Characteristic
    private let appID: [UInt8] = [0xFF, 0xFF]
    
    // Managers
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    // State
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var discoveredUsers: [User] = []
    
    // Data
    private var currentUID: String?
    private var discoveredUIDs: [String: Int] = [:] // UID: RSSI
    private var lastSeenMap: [String: Date] = [:] // UID: Date
    private var scanTimer: Timer?
    private var reportTimer: Timer?
    private var cleanupTimer: Timer?
    private var activePeripherals: [UUID: CBPeripheral] = [:] // Keep reference to connected peripherals
    private var tempUIDs: [UUID: String] = [:] // Temporary storage for UIDs read from characteristics
    private var isInBackground = false
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "yeopeCentralManager"])
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionRestoreIdentifierKey: "yeopePeripheralManager"])
        
        setupAppStateObservers()
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
        print("🌙 App entered background. Stopping BLE scanning & reporting...")
        isInBackground = true
        stopScanning()
    }
    
    @objc private func handleAppForegrounding() {
        print("☀️ App entering foreground. Resuming BLE scanning & reporting...")
        isInBackground = false
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
                case .success(let uid):
                    self?.currentUID = uid
                    self?.startAdvertising(uid: uid)
                case .failure(let error):
                    print("Failed to get UID: \(error)")
                }
            }
        }
    }
    
    private func startAdvertising(uid: String) {
        guard peripheralManager.state == .poweredOn else { return }
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Create Characteristic for Background Discovery
        let characteristic = CBMutableCharacteristic(
            type: uidCharacteristicUUID,
            properties: [.read],
            value: uid.data(using: .utf8),
            permissions: [.readable]
        )
        
        service.characteristics = [characteristic]
        
        peripheralManager.removeAllServices()
        peripheralManager.add(service)
        
        // Manufacturer Data is ignored by CoreBluetooth on iOS for advertising.
        // We must use the Local Name to broadcast the UID.
        // Note: The Local Name has a length limit, so ensure UID is concise or hashed if too long.
        // For this implementation, we assume UID fits (e.g., short hash or UUID segment).
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: uid // No prefix, just UID to save space
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        print("Started advertising UID via Local Name & Characteristic: \(uid)")
    }
    
    private func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
    }
    
    // MARK: - Scanning Logic
    
    // Raw Scanning Data
    // Raw Scanning Data
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
    
    // ... (Existing properties)
    
    // MARK: - Scanning Logic
    
    private func startScanningLoop() {
        guard !isInBackground else { return }
        
        #if targetEnvironment(simulator)
        // Simulator Mock Mode
        print("📱 Running on Simulator: Starting Mock BLE Scan")
        isScanning = true
        isBluetoothEnabled = true
        
        // Mock discovery timer
        scanTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isRawScanMode {
                // Mock Raw Peripherals
                let randomId = UUID()
                let typeRandom = Int.random(in: 0...2)
                let deviceType: DeviceType = typeRandom == 0 ? .ios : (typeRandom == 1 ? .android : .other)
                
                let name: String
                switch deviceType {
                case .ios: name = "iPhone \(Int.random(in: 10...15))"
                case .android: name = "Galaxy S\(Int.random(in: 20...24))"
                case .other: name = "Device \(Int.random(in: 100...999))"
                }
                
                let mockPeripheral = RawPeripheral(
                    id: randomId,
                    name: name,
                    rssi: Int.random(in: -90...-40),
                    deviceType: deviceType,
                    lastSeen: Date()
                )
                self.rawPeripherals[randomId] = mockPeripheral
                
                // Cleanup mock
                if self.rawPeripherals.count > 20 {
                    self.rawPeripherals.removeValue(forKey: self.rawPeripherals.keys.first!)
                }
            } else {
                // Existing Mock User Logic
                // Create a random mock user
                let randomId = UUID().uuidString
                let mockUser = User(
                    id: randomId,
                    email: "mock\(Int.random(in: 1...100))@test.com",
                    nickname: "SimUser \(Int.random(in: 1...99))",
                    nicknameMask: "SimUser \(Int.random(in: 1...99))",
                    settings: nil,
                    createdAt: nil,
                    lastLoginAt: nil,
                    distance: Double.random(in: 1.0...20.0),
                    hasActiveRoom: Bool.random(),
                    roomId: nil,
                    roomName: nil
                )
                
                // Add or update
                var currentUsers = self.discoveredUsers
                if currentUsers.count >= 5 { currentUsers.removeFirst() } // Keep list small
                currentUsers.append(mockUser)
                self.discoveredUsers = currentUsers
                
                // Mock cleanup for simulator (remove first user occasionally)
                if Bool.random() && !self.discoveredUsers.isEmpty {
                     self.discoveredUsers.removeFirst()
                }
            }
        }
        #else
        // Real Device Logic
        // Scan for 5 seconds every 10 seconds to save battery
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.performScan()
        }
        performScan()
        
        // Report results every 10 seconds (or 30s as per spec, but 10s for testing)
        reportTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.reportDiscoveredUIDs()
        }
        
        // Cleanup Timer: Remove users not seen in 15 seconds
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.cleanupExpiredUsers()
        }
        #endif
    }
    
    private func performScan() {
        guard centralManager.state == .poweredOn, !isInBackground else { return }
        
        // Scan for 5 seconds
        print("📱 Starting BLE Scan for 5s... (Raw Mode: \(isRawScanMode))")
        
        let services: [CBUUID]? = isRawScanMode ? nil : [serviceUUID]
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: isRawScanMode] // Allow duplicates in raw mode for RSSI updates
        
        centralManager.scanForPeripherals(withServices: services, options: options)
        isScanning = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.centralManager.stopScan()
            self?.isScanning = false
        }
    }
    
    private func stopScanning() {
        scanTimer?.invalidate()
        reportTimer?.invalidate()
        cleanupTimer?.invalidate()
        centralManager.stopScan()
        isScanning = false
    }
    
    private var strikesMap: [String: Int] = [:] // UID: Strike Count
    private let maxStrikes = 5 // Max strikes before removal
    
    private func cleanupExpiredUsers() {
        let now = Date()
        let timeout: TimeInterval = 15.0
        
        // 1. Cleanup Raw Peripherals
        if isRawScanMode {
            for (id, peripheral) in rawPeripherals {
                if now.timeIntervalSince(peripheral.lastSeen) > 15.0 { // Faster cleanup for raw mode
                    rawPeripherals.removeValue(forKey: id)
                }
            }
        }
        
        // 2. Strike System Logic
        // instead of removing immediately, we check if they were seen recently.
        // If not seen in this scan cycle (approx 15s tolerance), add a strike.
        // Background advertising can be slow, so we need a larger tolerance.
        
        var uidsToRemove: [String] = []
        
        for (uid, lastSeen) in lastSeenMap {
            // Increased from 5.0 to 15.0 to allow for background latency (3 missed scans of 5s each)
            if now.timeIntervalSince(lastSeen) > 15.0 {
                // User not seen recently
                let currentStrikes = strikesMap[uid] ?? 0
                strikesMap[uid] = currentStrikes + 1
                
                print("⚠️ UID \(uid) strike! (\(strikesMap[uid]!)/\(maxStrikes))")
                
                if strikesMap[uid]! >= maxStrikes {
                    uidsToRemove.append(uid)
                }
            } else {
                // User seen recently, reset strikes
                if strikesMap[uid] != 0 {
                    strikesMap[uid] = 0
                    print("✅ UID \(uid) recovered! Strikes reset.")
                }
            }
        }
        
        // Remove users who exceeded max strikes
        for uid in uidsToRemove {
            lastSeenMap.removeValue(forKey: uid)
            discoveredUIDs.removeValue(forKey: uid)
            strikesMap.removeValue(forKey: uid)
            print("🗑️ UID removed (Max Strikes): \(uid)")
        }
        
        // 3. Filter discoveredUsers based on remaining valid UIDs
        var validUIDs: [String: Int] = [:]
        for (uid, rssi) in discoveredUIDs {
            // Only keep if still in lastSeenMap (which means not removed by strikes)
            if lastSeenMap[uid] != nil {
                validUIDs[uid] = rssi
            }
        }
        discoveredUIDs = validUIDs
        
        if discoveredUIDs.isEmpty {
            DispatchQueue.main.async {
                self.discoveredUsers = []
            }
        }
    }

    private func reportDiscoveredUIDs() {
        guard !isInBackground else { return }
        guard TokenManager.shared.isLoggedIn else { 
            print("🚫 Not logged in. Skipping report.")
            return 
        }
        guard !discoveredUIDs.isEmpty else { return }
        
        let scannedData = discoveredUIDs.map { ScannedUID(uid: $0.key, rssi: $0.value) }
        
        print("📡 Reporting \(scannedData.count) discovered UIDs to server...")
        
        BLEService.shared.reportScanResults(uids: scannedData) { [weak self] result in
            switch result {
            case .success(let users):
                print("✅ Server returned \(users.count) nearby users")
                DispatchQueue.main.async {
                    self?.discoveredUsers = users
                }
            case .failure(let error):
                print("❌ Failed to report scan results: \(error)")
            }
        }
    }
    
    private func handleDiscoveredUID(_ uid: String, rssi: Int) {
        if uid.count == 6 {
            discoveredUIDs[uid] = rssi
            lastSeenMap[uid] = Date() // Update last seen
            print("🔍 Discovered UID: \(uid), RSSI: \(rssi)")
        } else {
             print("⚠️ Discovered device with invalid UID length: \(uid)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            isBluetoothEnabled = (central.state == .poweredOn)
            if central.state == .poweredOn {
                // Ready to scan
            }
        }
        
        func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
            // Raw Mode Handling
            // Raw Mode Handling
            if isRawScanMode {
                let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unknown"
                
                var deviceType: DeviceType = .other
                
                // 1. Check Manufacturer Data
                if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
                    if manufacturerData.count >= 2 {
                        let companyId = manufacturerData.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self) }
                        
                        // Apple: 0x004C
                        if companyId == 0x004C {
                            deviceType = .ios
                        }
                        // Samsung: 0x0075
                        else if companyId == 0x0075 {
                            deviceType = .android
                        }
                        // Google: 0x00E0
                        else if companyId == 0x00E0 {
                            deviceType = .android
                        }
                    }
                }
                
                // 2. Check Service UUIDs (if not yet identified as iOS)
                if deviceType == .other {
                    if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                        for uuid in serviceUUIDs {
                            // Google Fast Pair: 0xFE2C
                            if uuid == CBUUID(string: "FE2C") {
                                deviceType = .android
                                break
                            }
                            // Google Nearby Share: 0xFC31
                            if uuid == CBUUID(string: "FC31") {
                                deviceType = .android
                                break
                            }
                        }
                    }
                }
                
                let rawPeripheral = RawPeripheral(
                    id: peripheral.identifier,
                    name: name,
                    rssi: RSSI.intValue,
                    deviceType: deviceType,
                    lastSeen: Date()
                )
                
                DispatchQueue.main.async {
                    self.rawPeripherals[peripheral.identifier] = rawPeripheral
                }
                
                // Don't process further if we are just raw scanning? 
                // Actually we might still want to detect our app users even in raw mode.
                // But for now let's allow both.
            }
            
            // Debug: Log all discoveries with our Service UUID
            let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            // print("🔎 Raw Discovery: \(localName ?? "nil"), RSSI: \(RSSI)")
            
            // 1. Foreground Discovery (Fast)
            if let localName = localName, localName.count == 6 { // Simple check for our UID format
                handleDiscoveredUID(localName, rssi: RSSI.intValue)
            }
            // 2. Background Discovery (Connect & Read) - Only if it has our service UUID
            else if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID], serviceUUIDs.contains(serviceUUID) {
                print("🕵️‍♀️ Background device detected (No Name). Connecting to read UID...")
                activePeripherals[peripheral.identifier] = peripheral // Retain peripheral
                peripheral.delegate = self
                centralManager.connect(peripheral, options: nil)
            }
        }
        
        // ... (Rest of delegate methods)
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("🔗 Connected to \(peripheral.identifier). Discovering services...")
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        activePeripherals.removeValue(forKey: peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 Disconnected from \(peripheral.identifier)")
        activePeripherals.removeValue(forKey: peripheral.identifier)
        tempUIDs.removeValue(forKey: peripheral.identifier)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        // Handle state restoration
        print("Central Manager restored state")
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                print("✅ Service found. Discovering characteristics...")
                peripheral.discoverCharacteristics([uidCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == uidCharacteristicUUID {
                print("✅ Characteristic found. Reading value...")
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let uid = String(data: data, encoding: .utf8) {
            print("📬 Read UID from Characteristic: \(uid)")
            
            // Use a default RSSI or try to read it (reading RSSI is async too)
            // For simplicity, we assume a reasonable RSSI or read it if needed.
            // But didDiscover gave us the RSSI of the advertisement packet.
            // We can't easily map that exact RSSI here without passing it through.
            // However, since we just connected, the device is close.
            // Let's read the current RSSI.
            peripheral.readRSSI()
            
            // Store UID temporarily until RSSI is read
            tempUIDs[peripheral.identifier] = uid
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let uid = tempUIDs[peripheral.identifier] {
            handleDiscoveredUID(uid, rssi: RSSI.intValue)
            
            // Disconnect to save battery
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            if let uid = currentUID {
                // If we aren't advertising (and didn't restore it), start now.
                // We rely on isAdvertising flag, but restoration might have set it nicely?
                // Actually, just calling startAdvertising is safe, it checks state.
                if !isAdvertising {
                    startAdvertising(uid: uid)
                }
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        print("🕯️ Peripheral Manager restoring state...")
        // If the system restored us, we assume advertising is continuing if it was active.
        // We can mark our internal flag or check services.
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
            print("   - Restored \(services.count) services")
            isAdvertising = true
        }
    }
}
