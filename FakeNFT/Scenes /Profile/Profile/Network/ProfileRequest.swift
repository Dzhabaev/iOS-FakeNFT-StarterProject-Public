//
//  ProfileRequest.swift
//  FakeNFT
//
//  Created by Chalkov on 07.05.2024.
//

import Foundation

struct ProfileRequest: NetworkRequest {
    var httpMethod: HttpMethod = .get
    
    var dto: Encodable?
    
    var httpBody: String?
    
    var endpoint: URL?
    
    init() {
        guard let endpoint = URL(string: "\(NetworkConstants.baseURL)/api/v1/profile/1") else { return }
        self.endpoint = endpoint
    }
}
