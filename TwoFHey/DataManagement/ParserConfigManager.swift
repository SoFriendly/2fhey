import Foundation

public class ParserConfigManager: ObservableObject {
    public static let DEFAULT_CONFIG = OTPParserConfiguration(servicePatterns: OTPParserConstants.servicePatterns, knownServices: OTPParserConstants.knownServices, customPatterns: [])

    @Published var config: OTPParserConfiguration?

    init() {
        print("ParserConfigManager init")
        config = loadLocalServiceConfig() ?? ParserConfigManager.DEFAULT_CONFIG
        print("Loaded config: \(String(describing: config))")
    }
    
    // Uncomment this out if you want to test codes locally

//    private var configurationFilePath: URL? {
//        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
//        let filePath = documentsUrl.appendingPathComponent("2fheyConfiguration.json")
//        print("Configuration file path: \(filePath)")
//        return filePath
//    }
    
    private var configurationFilePath: URL? {
            let documentsUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] as NSURL
            return documentsUrl.appendingPathComponent("2fheyConfiguration.json")
        }

    private func loadLocalServiceConfig() -> OTPParserConfiguration? {
        print("Loading local service config")
        guard let path = configurationFilePath, let data = try? Data(contentsOf: path) else {
            print("Failed to load local service config")
            return nil
        }
        print("Loaded local service config data")
        return try? JSONDecoder().decode(OTPParserConfiguration.self, from: data)
    }

    private var configURL = URL(string: "https://raw.githubusercontent.com/SoFriendly/2fhey/main/AppConfig.json")

    func downloadLatestServiceConfig() {
        print("Downloading latest service config")
        guard let configURL = configURL else {
            print("Invalid config URL")
            return
        }

        let task = URLSession.shared.dataTask(with: configURL) { [weak self] data, response, error in
            if let error = error {
                print("Error downloading config: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
                print("Invalid response or data")
                return
            }
            
            print("Downloaded config data")
            
            guard let decoded = try? JSONDecoder().decode(OTPParserConfiguration.self, from: data) else {
                print("Failed to decode config data")
                return
            }
            
            print("Decoded config: \(decoded)")
            
            if let configurationFilePath = self?.configurationFilePath {
                do {
                    try data.write(to: configurationFilePath)
                    print("Saved config to local file")
                } catch {
                    print("Failed to save config to local file: \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self?.config = decoded
                print("Updated config on main queue")
            }
        }

        task.resume()
    }
}
