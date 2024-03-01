import Foundation

extension String {
    var isInt: Bool {
        return Int(self) != nil
    }
}

let CUSTOM_PARSERS: [CustomOTPParser] = [
    CustomOTPParser(
        notes: "Kotak Bank, includes a bunch of numbers",
        example: "123456 is the OTP for transaction of INR 1234.00 on your Kotak Bank Card 1234 at AMAZON PAY INDIA PRIVATET valid for 15 mins. DONT SHARE OTP WITH ANYONE INCLUDING BANK OFFICIALS.",
        requiredServiceName: "transaction",
        canParseMessage: { message in
            let words = message.components(separatedBy: " ")
            return message.contains("Kotak Bank") && words.count > 5 && words[0].isInt
        }, parseMessage: { message in
            let words = message.components(separatedBy: " ")
            return ParsedOTP(service: "kotak bank", code: words[0])
        }),
    CustomOTPParser(
        notes: "Generic catch 1 (Epic Games, possibly others)",
        example: "Your verification code is 732825",
        requiredServiceName: nil,
        canParseMessage: { message in
            let words = message.components(separatedBy: " ")
            return message.contains("Your security code:") && words[3].replacingOccurrences(of: ".", with: "").isInt
        }, parseMessage: { message in
            let words = message.components(separatedBy: " ")
            return ParsedOTP(service: "Unknown", code: words[3].replacingOccurrences(of: ".", with: ""))
        }),
    // misc. unknown user reported

    // unknown

    CustomOTPParser(
        notes: "Portal Verification",
        example: "Your portal verification code is : jh7112 Msg&Data rates may apply. Reply STOP to opt-out",
        requiredServiceName: nil,
        canParseMessage: { message in
            let words = message.components(separatedBy: " ")
            return message.contains("portal verification") && words.count > 6 && words[6].count == 6
        }, parseMessage: { message in
            let words = message.components(separatedBy: " ")
            return ParsedOTP(service: "Unknown", code: words[6])
        }),
    // cater allen

    CustomOTPParser(
        notes: "Cater Allen's complex OTP",
        example: "OTP to MAKE A NEW PAYMENT of GBP 9.94 to 560027 & 27613445. Call us if this wasn't you. NEVER share this code, not even with Cater Allen staff 699486",
        requiredServiceName: nil,
        canParseMessage: { message in
            let words = message.components(separatedBy: " ")
            guard let lastWord = words.last, lastWord.isInt else { return false }

            return message.contains("Cater Allen staff") && message.contains("OTP to MAKE A NEW PAYMENT")
        }, parseMessage: { message in
            guard let lastWord = message.components(separatedBy: " ").last else { return nil }
            return ParsedOTP(service: "Cater Allen", code: lastWord)
        }),
]
