import Foundation

public struct OTPParserCustomPatternConfiguration: Codable {
    public let matcherPattern: NSRegularExpression
    public let codeExtractorPattern: NSRegularExpression
    public let serviceName: String

    public init(matcherPattern: NSRegularExpression, codeExtractorPattern: NSRegularExpression, serviceName: String) {
        self.matcherPattern = matcherPattern
        self.codeExtractorPattern = codeExtractorPattern
        self.serviceName = serviceName
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matcherPattern.pattern, forKey: .matcherPattern)
        try container.encode(codeExtractorPattern.pattern, forKey: .codeExtractorPattern)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let matcherPattern = try container.decode(String.self, forKey: CodingKeys.matcherPattern)
        let codeExtractorPattern = try container.decode(String.self, forKey: CodingKeys.codeExtractorPattern)
        let serviceName = try container.decode(String.self, forKey: CodingKeys.serviceName)
        
        let regexOptions: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
        self.matcherPattern = try NSRegularExpression(pattern: matcherPattern, options: regexOptions)
        self.codeExtractorPattern = try NSRegularExpression(pattern: codeExtractorPattern, options: regexOptions)
        self.serviceName = serviceName
    }
    
    enum CodingKeys: String, CodingKey {
        case matcherPattern
        case codeExtractorPattern
        case serviceName
    }
}

public struct OTPParserConfiguration: Encodable, Decodable {
    let servicePatterns: [NSRegularExpression]
    let knownServices: [String]
    let customPatterns: [OTPParserCustomPatternConfiguration]
    
    public init(servicePatterns: [NSRegularExpression], knownServices: [String], customPatterns: [OTPParserCustomPatternConfiguration]) {
        self.servicePatterns = servicePatterns
        self.knownServices = knownServices
        self.customPatterns = customPatterns
    }
        
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(knownServices, forKey: .knownServices)
        try container.encode(servicePatterns.map { $0.pattern }, forKey: .servicePatterns)
        try container.encode(customPatterns, forKey: .customPatterns)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let knownServices = try container.decode([String].self, forKey: CodingKeys.knownServices)
        let servicePatterns = try container.decode([String].self, forKey: CodingKeys.servicePatterns)
        let customPatterns = try container.decode([OTPParserCustomPatternConfiguration].self, forKey: CodingKeys.customPatterns)
        
        self.knownServices = knownServices
        self.servicePatterns = try servicePatterns.map { try NSRegularExpression(pattern: $0) }
        self.customPatterns = customPatterns
    }
    
    enum CodingKeys: String, CodingKey {
       case servicePatterns
       case knownServices
       case customPatterns
    }
}
