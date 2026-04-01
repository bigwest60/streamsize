import FlutterMacOS
import Network

@objc(streamsize_mdns)
class StreamsizePlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.streamsize/mdns",
            binaryMessenger: registrar.messenger
        )
        let instance = StreamsizePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "discoverServices":
            discoverServices(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func discoverServices(result: @escaping FlutterResult) {
        let serviceTypes = [
            "_airplay._tcp",       // Apple TV, AirPlay receivers
            "_googlecast._tcp",    // Chromecast, Android TV
            "_hap._tcp",           // HomeKit accessories
            "_raop._tcp",          // AirPlay audio (HomePod, speakers)
            "_smb._tcp",           // Macs/NAS (requires File Sharing enabled)
        ]

        let dispatchGroup = DispatchGroup()
        var allResults: [[String: String]] = []
        // All browser callbacks and allResults access confined to this queue — no lock needed.
        let scanQueue = DispatchQueue(label: "com.streamsize.mdns", qos: .userInitiated)
        var browsers: [NWBrowser] = []  // retain browsers for their full 5s scan lifetime

        for serviceType in serviceTypes {
            dispatchGroup.enter()
            let params = NWParameters()
            params.includePeerToPeer = true

            let b = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)
            browsers.append(b)

            // browseResultsChangedHandler delivers the FULL current set (snapshot),
            // not a delta. Replace browserResults on each callback; do not append.
            var browserResults: [[String: String]] = []
            b.browseResultsChangedHandler = { results, _ in
                browserResults = results.compactMap { r -> [String: String]? in
                    guard case let .service(name, type, domain, _) = r.endpoint else {
                        return nil
                    }

                    // For _smb._tcp, inspect TXT record to distinguish Mac from NAS.
                    // Macs with File Sharing advertise with model= starting with "Mac"/"iMac".
                    // NAS devices (Synology, QNAP, etc.) use product-specific model values.
                    // Safe default (no model= key): classify as laptop, not NAS.
                    var effectiveType = type
                    if type == "_smb._tcp." || type == "_smb._tcp" {
                        var isNas = false
                        if case let .bonjour(record) = r.metadata,
                           let model = record["model"] {
                            let lower = model.lowercased()
                            isNas = !(lower.hasPrefix("mac") || lower.hasPrefix("imac"))
                        }
                        if isNas {
                            effectiveType = "_nas._tcp"
                        }
                    }

                    return ["name": name, "type": effectiveType, "domain": domain]
                }
            }

            // dispatchGroup.leave() is called ONLY in asyncAfter — never in
            // stateUpdateHandler — to prevent double-leave (EXC_BAD_INSTRUCTION)
            // if the browser fails before the 5s window closes.
            b.stateUpdateHandler = { state in
                if case .failed(_) = state {
                    b.cancel()
                }
            }

            b.start(queue: scanQueue)

            // The Dart .timeout(10s) on invokeListMethod is a dead-man switch
            // (crash guard), not the scan duration control. This asyncAfter(5s)
            // always resolves first under normal conditions.
            scanQueue.asyncAfter(deadline: .now() + 5.0) {
                b.cancel()
                allResults += browserResults
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            // Deduplicate across all service types by name+type
            var seen = Set<String>()
            let deduped = allResults.filter { item in
                let key = "\(item["name"] ?? "")|\(item["type"] ?? "")"
                return seen.insert(key).inserted
            }
            let names = deduped.map { "\($0["name"] ?? "unknown").\($0["type"] ?? "")" }
            result(names as NSArray)
        }
    }
}
