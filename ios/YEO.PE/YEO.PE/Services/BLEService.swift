import Foundation

struct BLEUIDResponse: Codable {
    let uid: String
    let expiresAt: String
}

struct ScanResultPayload: Codable {
    let uids: [ScannedUID]
}

struct ScannedUID: Codable {
    let uid: String
    let rssi: Int
    // timestamp is optional or handled by server/client agreement
}

struct ScanResponse: Codable {
    let users: [User]
}

class BLEService {
    static let shared = BLEService()
    
    private init() {}
    
    func getUID(completion: @escaping (Result<String, Error>) -> Void) {
        APIService.shared.request("/users/ble/uid", method: "POST") { (result: Result<BLEUIDResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.uid))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func reportScanResults(uids: [ScannedUID], completion: @escaping (Result<[User], Error>) -> Void) {
        let body = ["uids": uids.map { ["uid": $0.uid, "rssi": $0.rssi] }]
        
        APIService.shared.request("/users/ble/scan", method: "POST", body: body) { (result: Result<ScanResponse, Error>) in
            switch result {
            case .success(let response):
                completion(.success(response.users))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
