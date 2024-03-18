//
//  TwoFHeyTests.swift
//  TwoFHeyTests
//
//  Created by Drew Pomerleau on 5/7/22.
//

import XCTest
import _FHey

class TwoFHeyTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

//
    func testResyCode() throws {
        let parser = TwoFHeyOTPParser(withConfig: ParserConfigManager.DEFAULT_CONFIG)
        XCTAssertEqual(parser.parseMessage(#"123-456 is your Resy account verification code. This is not a booking confirmation."#), ParsedOTP(service: "resy", code: "123456"))
    }

    func testValuesFromOldRepo() throws {
        let parser = TwoFHeyOTPParser(withConfig: ParserConfigManager.DEFAULT_CONFIG)

//        XCTAssertEqual(parser.parseMessage(#"G-412157 is your Google verification code."#), ParsedOTP(service: "google", code: "412157"))

        XCTAssertEqual(parser.parseMessage(#"469538 is your verification code for your Sony Entertainment Network account."#), ParsedOTP(service: "sony entertainment network", code: "469538"))

        XCTAssertEqual(parser.parseMessage(#"512665 (NetEase Verification Code)"#), ParsedOTP(service: "netease", code: "512665"))

        XCTAssertEqual(parser.parseMessage(#"2-step verification is now deactivated on your Sony Entertainment Network account."#), nil)

        XCTAssertEqual(parser.parseMessage(#"[Alibaba Group]Your verification code is 797428"#), ParsedOTP(service: "alibaba group", code: "797428"))

        XCTAssertEqual(parser.parseMessage(#"[HuomaoTV]code: 456291. Please complete the verification within 5 minutes. If you did not operate, please ignore this message."#), ParsedOTP(service: "huomaotv", code: "456291"))

        XCTAssertEqual(parser.parseMessage(#"Auth code: 2607 Please enter this code in your app."#), ParsedOTP(service: nil, code: "2607"))

//        XCTAssertEqual(parser.parseMessage(#"Welcome to ClickSend, for your first login you'll need the activation PIN: 464120"#), ParsedOTP(service: "clicksend", code: "464120"))

        XCTAssertEqual(parser.parseMessage(#"Here is your ofo verification code: 2226"#), ParsedOTP(service: "ofo", code: "2226"))

        XCTAssertEqual(parser.parseMessage(#"Use 5677 as Microsoft account security code"#), ParsedOTP(service: "microsoft", code: "5677"))

        XCTAssertEqual(parser.parseMessage(#"Your Google verification code is 596465"#), ParsedOTP(service: "google", code: "596465"))

        XCTAssertEqual(parser.parseMessage(#"Your LinkedIn verification code is 804706."#), ParsedOTP(service: "linkedin", code: "804706"))

        XCTAssertEqual(parser.parseMessage(#"Your WhatsApp code is 105-876 but you can simply tap on this link to verify your device: v.whatsapp.com/105876"#), ParsedOTP(service: "whatsapp", code: "105876"))

        XCTAssertEqual(parser.parseMessage(#"This is your secret password for REGISTRATION. GO-JEK never asks for your password, DO NOT GIVE IT TO ANYONE. Your PASSWORD is 1099 ."#), ParsedOTP(service: nil, code: "1099"))

        XCTAssertEqual(parser.parseMessage(#"Your confirmation code is 951417. Please enter it in the text field."#), ParsedOTP(service: nil, code: "951417"))

        XCTAssertEqual(parser.parseMessage(#"588107 is your LIKE verification code"#), ParsedOTP(service: "like", code: "588107"))

        XCTAssertEqual(parser.parseMessage(#"Your one-time eBay pin is 3190"#), ParsedOTP(service: "ebay", code: "3190"))

        XCTAssertEqual(parser.parseMessage(#"Telegram code 65847"#), ParsedOTP(service: "telegram", code: "65847"))



        XCTAssertEqual(parser.parseMessage(#"858365 is your 98point6 security code."#), ParsedOTP(service: "98point6", code: "858365"))

        XCTAssertEqual(parser.parseMessage(#"0013 is your verification code for HQ Trivia"#), ParsedOTP(service: "hq trivia", code: "0013"))

        XCTAssertEqual(parser.parseMessage(#"750963 is your Google Voice verification code"#), ParsedOTP(service: "google voice", code: "750963"))

        XCTAssertEqual(parser.parseMessage(#"Пароль: 1752 (никому не говорите) Доступ к информации"#), ParsedOTP(service: nil, code: "1752"))



        XCTAssertEqual(parser.parseMessage(#"2715"#), ParsedOTP(service: nil, code: "2715"))

        XCTAssertEqual(parser.parseMessage(#"Snapchat code: 481489. Do not share it or use it elsewhere!"#), ParsedOTP(service: "snapchat", code: "481489"))

        XCTAssertEqual(parser.parseMessage(#"[#] Your Uber code: 5934 qlRnn4A1sbt"#), ParsedOTP(service: "uber", code: "5934"))

        XCTAssertEqual(parser.parseMessage(#"128931 is your BIGO LIVE verification code"#), ParsedOTP(service: "bigo live", code: "128931"))

        XCTAssertEqual(parser.parseMessage(#"Humaniq code: 167-262"#), ParsedOTP(service: "humaniq", code: "167262"))

//        XCTAssertEqual(parser.parseMessage(#"373473(Weibo login verification code) This code is for user authentication, please do not send it to anyone else."#), ParsedOTP(service: "weibo", code: "373473"))

        XCTAssertEqual(parser.parseMessage(#"[zcool]Your verification code is 991533"#), ParsedOTP(service: "zcool", code: "991533"))

//        XCTAssertEqual(parser.parseMessage(#"G-830829"#), ParsedOTP(service: "google", code: "G-830829"))

        XCTAssertEqual(parser.parseMessage(#"117740 ist dein Verifizierungscode für dein Sony Entertainment Network-Konto."#), ParsedOTP(service: "sony", code: "117740"))

        XCTAssertEqual(parser.parseMessage(#"Your Lyft code is 744444"#), ParsedOTP(service: "lyft", code: "744444"))

//        XCTAssertEqual(parser.parseMessage(#"Cash Show - 賞金クイズ の確認コードは 764972 です。"#), ParsedOTP(service: nil, code: "764972"))

        XCTAssertEqual(parser.parseMessage(#"[SwiftCall]Your verification code: 6049"#), ParsedOTP(service: "swiftcall", code: "6049"))

        XCTAssertEqual(parser.parseMessage(#"Your Proton verification code is: 861880"#), ParsedOTP(service: "proton", code: "861880"))

        XCTAssertEqual(parser.parseMessage(#"VerifyCode:736136"#), ParsedOTP(service: nil, code: "736136"))

        XCTAssertEqual(parser.parseMessage(#"WhatsApp code 507-240"#), ParsedOTP(service: "whatsapp", code: "507240"))

        XCTAssertEqual(parser.parseMessage(#"[EggOne]Your verification code is: 562961, valid for 10 minutes. If you are not operating, please contact us as soon as possible."#), ParsedOTP(service: "eggone", code: "562961"))

        XCTAssertEqual(parser.parseMessage(#"(Zalo) 8568 la ma kich hoat cua so dien thoai 13658014095. Vui long nhap ma nay vao ung dung Zalo de kich hoat tai khoan."#), ParsedOTP(service: "zalo", code: "8568"))

        XCTAssertEqual(parser.parseMessage(#"You are editing the phone number information of your weibo account, the verification code is: 588397 (expire in 10 min)."#), ParsedOTP(service: "weibo", code: "588397"))

        XCTAssertEqual(parser.parseMessage(#"Your CloudSigma verification code for MEL is 880936"#), ParsedOTP(service: "cloudsigma", code: "880936"))

//        XCTAssertEqual(parser.parseMessage(#"G-718356() Google ."#), ParsedOTP(service: "google", code: "G-718356"))

//        XCTAssertEqual(parser.parseMessage(#"G-723210(이)가 Google 인증 코드입니다."#), ParsedOTP(service: "google", code: "G-723210"))

        XCTAssertEqual(parser.parseMessage(#"You requested a secure one-time password to log in to your USCIS Account. Please enter this secure one-time password: 04352398"#), ParsedOTP(service: "uscis", code: "04352398"))

        XCTAssertEqual(parser.parseMessage(#"Your Stairlin verification code is 815671"#), ParsedOTP(service: "stairlin", code: "815671"))



        XCTAssertEqual(parser.parseMessage(#"Your mCent confirmation code is: 6920"#), ParsedOTP(service: "mcent", code: "6920"))

        XCTAssertEqual(parser.parseMessage(#"Your Zhihu verification code is 756591."#), ParsedOTP(service: "zhihu", code: "756591"))

        XCTAssertEqual(parser.parseMessage(#"Hello! Your BuzzSumo verification code is 823 815"#), ParsedOTP(service: "buzzsumo", code: "823815"))

        XCTAssertEqual(parser.parseMessage(#"WhatsApp code 569-485. You can also tap on this link to verify your phone: v.whatsapp.com/569485"#), ParsedOTP(service: "whatsapp", code: "569485"))

//        XCTAssertEqual(parser.parseMessage(#"Use the code (7744) on WeChat to log in to your account. Don't forward the code!"#), ParsedOTP(service: "wechat", code: "7744"))

        XCTAssertEqual(parser.parseMessage(#"grubhub order 771332"#), ParsedOTP(service: "grubhub", code: "771332"))

//        XCTAssertEqual(parser.parseMessage(#"Your boa code is "521992""#), ParsedOTP(service: "boa", code: "521992"))

        XCTAssertEqual(parser.parseMessage(#"Your Twilio verification code is: 9508"#), ParsedOTP(service: "twilio", code: "9508"))

        XCTAssertEqual(parser.parseMessage(#"Your Twitter confirmation coce is 180298"#), ParsedOTP(service: "twitter", code: "180298"))

        XCTAssertEqual(parser.parseMessage(#"Use 003407 as your password for Facebook for iPhone."#), ParsedOTP(service: "facebook", code: "003407"))

//        XCTAssertEqual(parser.parseMessage(#"Reasy. Set. Get. Your new glasses are ready for pick up at LensCrafters! Stop in any time to see th enew you. Questions? 718-858-7036"#), nil)

        XCTAssertEqual(parser.parseMessage(#"6635 is your Postmates verification code."#), ParsedOTP(service: "postmates", code: "6635"))



        XCTAssertEqual(parser.parseMessage(#"388-941-4444 your code is 333222"#), ParsedOTP(service: nil, code: "333222"))

        XCTAssertEqual(parser.parseMessage(#"+1-388-941-4444 your code is 333-222"#), ParsedOTP(service: nil, code: "333222"))

        XCTAssertEqual(parser.parseMessage(#"Microsoft access code: 6907"#), ParsedOTP(service: "microsoft", code: "6907"))

//        XCTAssertEqual(parser.parseMessage(#"<#> Your ExampleApp code is: 123ABC78 FA+9qCX9VSu"#), ParsedOTP(service: "exampleapp", code: "123ABC78"))

    }
    
    func testShouldNotParseAPhoneNumber() throws {
        let parser = TwoFHeyOTPParser(withConfig: ParserConfigManager.DEFAULT_CONFIG)

        XCTAssertEqual(parser.parseMessage(#"388-941-4444 your code is 333222"#), ParsedOTP(service: nil, code: "333222"))

    }
    
    func testCustomPattern() throws {
//        let customPattern = OTPParserCustomPatternConfiguration()
        let jsonPattern = #"""
{
  "matcherPattern": "^someweird-.+$",
  "codeExtractorPattern": "^someweird.+:((\\d|\\D){4,6})$"
}
"""#
        let decoded = try JSONDecoder().decode(OTPParserCustomPatternConfiguration.self, from: jsonPattern.data(using: .utf8)!)
        
        let testConfig = OTPParserConfiguration(servicePatterns: [], knownServices: [], customPatterns: [decoded])

        let parser = TwoFHeyOTPParser(withConfig: testConfig)

        XCTAssertEqual(parser.parseMessage(#"someweird-pattern:a1b2c3"#), ParsedOTP(service: nil, code: "a1b2c3"))

    }
    
    func testCustomPatternWithNoServieName() {
        let message = "46143020\nvalid 5 minutes\ndurata 5 minuti\ndurée 5 minutes\ngültig 5 minuten\r"
        let jsonPattern = #"""
      {
         "serviceName":"no provider name",
         "matcherPattern":"\\d{2,8}.*valid",
         "codeExtractorPattern":"(\\d{2,8})"
      }
"""#
        let decoded = try! JSONDecoder().decode(OTPParserCustomPatternConfiguration.self, from: jsonPattern.data(using: .utf8)!)
        
        let testConfig = OTPParserConfiguration(servicePatterns: [], knownServices: [], customPatterns: [decoded])

        XCTAssertNotNil(decoded.matcherPattern.firstMatchInString(message), "")
        
        let parser = TwoFHeyOTPParser(withConfig: testConfig)

        XCTAssertEqual(parser.parseMessage(message), ParsedOTP(service: nil, code: "46143020"))
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
