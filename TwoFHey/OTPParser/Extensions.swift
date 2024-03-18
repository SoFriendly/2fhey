import Foundation

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

extension NSTextCheckingResult {
    func firstCaptureGroupInString(_ string: String) -> String? {
        // Check if the desired capture group index is within bounds
        guard numberOfRanges > 1, let substringRange = Range(range(at: 1), in: string) else { return nil }
        
        return String(string[substringRange])
    }
}


extension NSRegularExpression {
    public func firstMatchInString(_ string: String) -> NSTextCheckingResult? {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range)
    }
    
    func matchesInString(_ string: String) -> [NSTextCheckingResult] {
        let range = NSRange(location: 0, length: string.utf16.count)
        return matches(in: string, range: range)
    }
    
    func firstCaptureGroupInString(_ string: String) -> String? {
        guard let match = firstMatchInString(string) else { return nil }
        
        return match.firstCaptureGroupInString(string)
    }
}
