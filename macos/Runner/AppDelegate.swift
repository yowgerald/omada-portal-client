import Cocoa
import FlutterMacOS
import IOKit
import IOKit.network

@main
class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.example.toto_portal/device_info"

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let deviceInfoChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.engine.binaryMessenger)

    deviceInfoChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if (call.method == "getMacAddress") {
        result(self.getMacAddress())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.applicationDidFinishLaunching(aNotification)
  }

  private func getMacAddress() -> String? {
      var macAddress: String?

      if let matchingDict = IOServiceMatching("IOEthernetInterface") {
          var iterator: io_iterator_t = 0
          let kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator)

          if kernResult == KERN_SUCCESS {
              var service: io_object_t
              repeat {
                  service = IOIteratorNext(iterator)
                  if service != 0 {
                      // Get BSD name (e.g., "en0") to filter the specific interface
                      if let bsdNameAsCFString = IORegistryEntryCreateCFProperty(service, kIOBSDNameKey as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? String, bsdNameAsCFString == "en0" {
                          
                          // Get the parent service which has the MAC address
                          var parentService: io_object_t = 0
                          if IORegistryEntryGetParentEntry(service, kIOServicePlane, &parentService) == KERN_SUCCESS {
                              if let data = IORegistryEntryCreateCFProperty(parentService, kIOMACAddress as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
                                  macAddress = data.map { String(format: "%02X", $0) }.joined(separator: "-")
                              }
                              IOObjectRelease(parentService)
                          }
                          break
                      }
                  }
              } while service != 0
              IOObjectRelease(iterator)
          }
      }

      return macAddress ?? "MAC Address not available"
  }
}
