import Foundation

extension String {
    var isInt: Bool {
        return Int(self) != nil
    }
}

struct OTPParserConstants {
    static let googleOTPRegex = try! NSRegularExpression(pattern: #"\b(g-\d{4,8})\b"#)
    
    static let endingCharacters: Set<Character> = [",", ".", "!", " ", "，", "。"]
    
    static let knownServices = [
        "td ameritrade",
        "coinbase",
        "ally",
        "schwab",
        "id.me",
        "bofa",
        "dropboxing",
        "wise.com",
        "paypal",
        "venmo",
        "cash",
        "segment",
        "verizon",
        "kotak bank",
        "weibo",
        "wechat",
        "whatsapp",
        "viber",
        "snapchat",
        "line",
        "slack",
        "signal",
        "telegram",
        "allo",
        "kakaotalk",
        "voxer",
        "im+",
        "skype",
        "facebook",
        "microsoft",
        "google",
        "twitter",
        "instagram",
        "sony",
        "apple",
        "ubereats",
        "uber",
        "lyft",
        "postmates",
        "doordash",
        "delivery.com",
        "eat24",
        "foodler",
        "amazon",
        "tencent",
        "alibaba",
        "taobao",
        "baidu",
        "youku",
        "toutaio",
        "netease",
        "yandex",
        "uc browser",
        "qq browser",
        "qmenu",
        "sogou",
        "bbm",
        "ebay",
        "intel",
        "cisco",
        "citizen",
        "oracle",
        "xerox",
        "ibm",
        "foursquare",
        "hotmail",
        "outlook",
        "yahoo",
        "netflix",
        "spotify",
        "producthunt",
        "nike",
        "adidas",
        "shopify",
        "wordpress",
        "yelp eats",
        "yelp",
        "drizly",
        "eaze",
        "gopuff",
        "grubhub",
        "seamless",
        "foodpanda",
        "freshdirect",
        "github",
        "flickr",
        "etsy",
        "bank of america",
        "lenscrafters",
        "zocdoc",
        "flycleaners",
        "cleanly",
        "handy",
        "twilio",
        "kik",
        "xbox",
        "imo",
        "kayak",
        "grab",
        "qq",
        "moonpay",
        "robinhood",
        "ao retail",
        "cater allen",
        "apple pay",
        "bill.com",
        "amex",
        "sia",
        "fanduel",
        "cart"
      ]
    
    static let authWords: Set<String> = [
        "your",
        "auth",
        "login",
        "activation",
        "authentication",
        "verification",
        "confirmation",
        "access code",
        "code",
        "pin",
        "otp",
        "purchase",
        "receipt",
        "phone",
        "number",
        "security",
        "2-step",
        "2-fac",
        "2-factor"
      ]
    
    public static let servicePatterns = [
        try! NSRegularExpression(pattern: #"\bfor\s+your\s+([\w\d ]{2,64})\s+account\b"#),
        try! NSRegularExpression(pattern: #"\bon\s+your\s+([\w\d ]{2,64})\s+account\b"#),
        try! NSRegularExpression(pattern: #"\bas\s+your\s+([\w\d ]{2,64})\s+account\b"#),
        try! NSRegularExpression(pattern: #"\bas\s+([\w\d ]{2,64})\s+account\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+account\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+verification\s+code\b"#),

        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+verification\s+number\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+verification\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+activation\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+activation\s+number\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+activation\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+otp\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+otp\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+auth\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+auth\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+authentication\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+authentication\s+number\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+authentication\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+security\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+security\s+number\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+security\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+confirmation\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+confirmation\s+number\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+confirmation\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+access\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+access\s+number\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d ]{2,64})\s+access\s+pin\b"#),

        try! NSRegularExpression(pattern: #"\byour\s+verification\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+verification\s+number\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+verification\s+pin\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+activation\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+activation\s+number\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+activation\s+pin\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+otp\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+otp\s+pin\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+auth\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+auth\s+pin\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+authentication\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+authentication\s+number\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+authentication\s+pin\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+security\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+security\s+number\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+security\s+pin\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+confirmation\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+confirmation\s+number\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+confirmation\s+pin\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+access\s+code\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+access\s+number\s+for\s+([\w\d ]{2,64})\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+access\s+pin\s+for\s+([\w\d ]{2,64})\b"#),

        try! NSRegularExpression(pattern: #"\byour\s+([\w\d]{2,64})\s+code\b"#),
        try! NSRegularExpression(pattern: #"\byour\s+([\w\d]{2,64})\s+pin\b"#),

        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+verification\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+verification\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+verification\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+activation\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+activation\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+activation\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+otp\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+otp\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+auth\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+auth\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+auth\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+authentication\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+authentication\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+authentication\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+security\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+security\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+security\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+confirmation\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+confirmation\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+confirmation\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+access\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+access\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+login\s+access\s+pin\b"#),

        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+verification\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+verification\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+verification\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+activation\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+activation\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+activation\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+otp\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+otp\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+auth\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+auth\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+auth\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+authentication\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+authentication\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+authentication\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+security\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+security\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+security\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+confirmation\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+confirmation\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+confirmation\s+pin\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+access\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+access\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{2,64})\s+access\s+pin\b"#),

        try! NSRegularExpression(pattern: #"^welcome\s+to\s+([\w\d ]{2,64})[,;.]"#),
        try! NSRegularExpression(pattern: #"^welcome\s+to\s+([\w\d]{2,64})\b"#),

        try! NSRegularExpression(pattern: #"^\[([^\]\d]{2,64})]"#),
        try! NSRegularExpression(pattern: #"^\(([^)\d]{2,64})\)"#),

        try! NSRegularExpression(pattern: #"\bcode\s+for\s+([\w\d]{3,64})\b"#),
        try! NSRegularExpression(pattern: #"\bpin\s+for\s+([\w\d]{3,64})\b"#),
        try! NSRegularExpression(pattern: #"\botp\s+for\s+([\w\d]{3,64})\b"#),
        try! NSRegularExpression(pattern: #"\bnumber\s+for\s+([\w\d]{3,64})\b"#),

        try! NSRegularExpression(pattern: #"\b([\w\d]{3,64})\s+login\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{3,64})\s+login\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{3,64})\s+login\s+pin\b"#),

        try! NSRegularExpression(pattern: #"\b([\w\d]{3,64})\s+code\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{3,64})\s+number\b"#),
        try! NSRegularExpression(pattern: #"\b([\w\d]{3,64})\s+pin\b"#),

        try! NSRegularExpression(pattern: #"【([\u4e00-\u9fa5\d\w]+)"#),
    ]
    
    struct CodeMatchingRegularExpressions {
        static let standardFourToEight = try! NSRegularExpression(pattern: #"\b(\d{4,8})\b"#)
        static let dashedThreeAndThree = try! NSRegularExpression(pattern: #"\b(\d{3}[- ]\d{3})\b"#)
    }
    
    let customParsers: [CustomOTPParser] = [
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
}
