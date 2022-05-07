//
//  OTPParserConfiguration.swift
//  TwoFHey
//
//  Created by Drew Pomerleau on 5/3/22.
//

import Foundation

public struct OTPParserConfiguration: Encodable, Decodable {
    let servicePatterns: [NSRegularExpression]
    let knownServices: [String]
    
    init(servicePatterns: [NSRegularExpression], knownServices: [String]) {
        self.servicePatterns = servicePatterns
        self.knownServices = knownServices
    }
        
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(knownServices, forKey: .knownServices)
        try container.encode(servicePatterns.map { $0.pattern }, forKey: .servicePatterns)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let knownServices = try container.decode([String].self, forKey: CodingKeys.knownServices)
        let servicePatterns = try container.decode([String].self, forKey: CodingKeys.servicePatterns)
        
        self.knownServices = knownServices
        self.servicePatterns = try servicePatterns.map { try NSRegularExpression(pattern: $0) }
    }
    
    enum CodingKeys: String, CodingKey {
       case servicePatterns
       case knownServices
    }
}
