# 2FHey

Automatically detect and copy verification codes from iMessage and SMS.

## Features

- 🔐 Automatic OTP detection from messages
- 📋 Auto-copy to clipboard
- ⌨️ Optional auto-paste
- 🔔 Desktop notifications
- 🎯 Global keyboard shortcut (⇧⌘E) to resync messages
- 🌐 Support for 145+ services

## How It Works

2FHey uses smart keyword-based detection to identify verification code messages. When a message contains words like "verification", "code", "OTP", "PIN", etc., it automatically:

1. Extracts 4-8 digit codes (or alphanumeric codes)
2. Identifies the service (Google, Apple, Bank, etc.)
3. Copies the code to your clipboard
4. Shows a notification overlay
5. Optionally auto-pastes the code

## Supported Formats

The app automatically detects codes in various formats:
- Standard digits: `123456`
- Spaced/dashed: `123-456` or `123 456`
- Alphanumeric: `ABC123`, `X7Y9Z2`
- Google format: `G-12345`
- Chinese brackets: `【验证码123456】`

## Installation

1. Download the latest release
2. Move to Applications folder
3. Launch and grant required permissions:
   - **Full Disk Access** - to read Messages database
   - **Accessibility** - for auto-paste and keyboard shortcuts

## Keyboard Shortcuts

- **⇧⌘E** (Shift + Command + E) - Resync messages and copy the latest OTP code to clipboard
  - Useful if 2FHey missed a message or you need to retrieve a recent code again
  - Can be disabled in Settings if it conflicts with other apps

## Custom Services

If you use a service that isn't automatically recognized, you can add it to the known services list by creating a PR to update `OTPParserConstants.knownServices` in `TwoFHey/OTPParser/OTPParserContants.swift`.

## Development Notes

**Version 2.0+** uses a simplified keyword-based OTP parser (`SimpleOTPParser.swift`) instead of complex regex patterns. This makes the app more reliable and easier to maintain.

The old regex-based system (`AppConfig.json` and 130+ service patterns) has been deprecated in favor of smart detection that works with any service.
