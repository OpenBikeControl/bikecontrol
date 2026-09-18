import Flutter
import Foundation
import dnssd

// dns_sd error constants import as Int.
private let dnsNoError = DNSServiceErrorType(kDNSServiceErr_NoError)
private let dnsNameConflict = DNSServiceErrorType(kDNSServiceErr_NameConflict)

/// Publishes BikeControl's mDNS services under a dedicated host that carries
/// a single IPv4 A record, via Bonjour's dns_sd API.
///
/// NSNetService ties services to the device hostname, which Bonjour answers
/// with every address the device has, IPv6 link-locals included; some
/// trainer apps cannot connect to those. Registering our own A record needs
/// no multicast entitlement because mDNSResponder does the multicast.
/// Dart side: prop's `DnsSdServiceAdvertiser`.
final class DnsSdAdvertiser: NSObject {
  static let channelName = "bikecontrol/dnssd"

  /// How long `registerHost` waits for probing to report a conflict before
  /// treating the record as ours. Probing normally settles in under a second.
  private static let probeTimeout: TimeInterval = 3

  private static let recordTtl: UInt32 = 120

  /// All dns_sd calls and callbacks run here; DNSServiceRefDeallocate must be
  /// called on the queue the ref was scheduled on.
  private let queue = DispatchQueue(label: "bikecontrol.dnssd")

  private var hostConnection: DNSServiceRef?
  private var hostRecord: DNSRecordRef?
  private var hostLabel: String?
  private var hostInterface: UInt32 = 0
  private var pendingHostResult: FlutterResult?
  private var hostProbeTimeout: DispatchWorkItem?

  private var services: [Int: DNSServiceRef] = [:]
  private var nextHandle = 1

  func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "BikeControlDnsSd") else { return }
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      let args = call.arguments as? [String: Any] ?? [:]
      self.queue.async {
        switch call.method {
        case "registerHost":
          guard let label = args["label"] as? String, let ipv4 = args["ipv4"] as? String else {
            return Self.reply(result, Self.argumentError(call.method))
          }
          self.registerHost(label: label, ipv4: ipv4, result: result)
        case "updateHost":
          guard let ipv4 = args["ipv4"] as? String else {
            return Self.reply(result, Self.argumentError(call.method))
          }
          self.updateHost(ipv4: ipv4, result: result)
        case "unregisterHost":
          self.unregisterHost()
          Self.reply(result, nil)
        case "registerService":
          self.registerService(args, result: result)
        case "unregisterService":
          if let handle = args["handle"] as? Int, let ref = self.services.removeValue(forKey: handle) {
            DNSServiceRefDeallocate(ref)
          }
          Self.reply(result, nil)
        default:
          Self.reply(result, FlutterMethodNotImplemented)
        }
      }
    }
  }

  // MARK: - Host record

  private func registerHost(label: String, ipv4: String, result: @escaping FlutterResult) {
    unregisterHost()
    guard var address = Self.parseIPv4(ipv4) else {
      return Self.reply(result, FlutterError(code: "address", message: "not an IPv4: \(ipv4)", details: nil))
    }
    var connection: DNSServiceRef?
    var err = DNSServiceCreateConnection(&connection)
    guard err == dnsNoError, let connection else {
      return Self.reply(result, Self.dnsError("DNSServiceCreateConnection", err))
    }
    DNSServiceSetDispatchQueue(connection, queue)

    let interface = Self.interfaceIndex(for: ipv4)
    var record: DNSRecordRef?
    err = withUnsafeBytes(of: &address) { bytes in
      DNSServiceRegisterRecord(
        connection,
        &record,
        DNSServiceFlags(kDNSServiceFlagsUnique),
        interface,
        "\(label).local.",
        UInt16(kDNSServiceType_A),
        UInt16(kDNSServiceClass_IN),
        UInt16(bytes.count),
        bytes.baseAddress,
        Self.recordTtl,
        { _, _, _, errorCode, context in
          guard let context else { return }
          Unmanaged<DnsSdAdvertiser>.fromOpaque(context).takeUnretainedValue().hostRecordReply(errorCode)
        },
        Unmanaged.passUnretained(self).toOpaque()
      )
    }
    guard err == dnsNoError else {
      DNSServiceRefDeallocate(connection)
      return Self.reply(result, Self.dnsError("DNSServiceRegisterRecord", err))
    }
    hostConnection = connection
    hostRecord = record
    hostLabel = label
    hostInterface = interface
    pendingHostResult = result

    // No callback before the timeout means probing found no conflict yet.
    let timeout = DispatchWorkItem { [weak self] in self?.hostRecordReply(dnsNoError) }
    hostProbeTimeout = timeout
    queue.asyncAfter(deadline: .now() + Self.probeTimeout, execute: timeout)
  }

  private func hostRecordReply(_ errorCode: DNSServiceErrorType) {
    hostProbeTimeout?.cancel()
    hostProbeTimeout = nil
    guard let result = pendingHostResult else {
      if errorCode != dnsNoError {
        NSLog("DnsSdAdvertiser: host record \(hostLabel ?? "?") lost after registration: \(errorCode)")
      }
      return
    }
    pendingHostResult = nil
    if errorCode == dnsNoError {
      return Self.reply(result, nil)
    }
    unregisterHost()
    if errorCode == dnsNameConflict {
      return Self.reply(result, FlutterError(code: "conflict", message: "host name already in use", details: nil))
    }
    Self.reply(result, Self.dnsError("host record", errorCode))
  }

  private func updateHost(ipv4: String, result: @escaping FlutterResult) {
    guard let connection = hostConnection, let record = hostRecord, let label = hostLabel else {
      return Self.reply(result, FlutterError(code: "state", message: "no host registered", details: nil))
    }
    guard var address = Self.parseIPv4(ipv4) else {
      return Self.reply(result, FlutterError(code: "address", message: "not an IPv4: \(ipv4)", details: nil))
    }
    // A record pinned to the old interface cannot just change its rdata.
    if Self.interfaceIndex(for: ipv4) != hostInterface {
      return registerHost(label: label, ipv4: ipv4, result: result)
    }
    let err = withUnsafeBytes(of: &address) { bytes in
      DNSServiceUpdateRecord(connection, record, 0, UInt16(bytes.count), bytes.baseAddress, Self.recordTtl)
    }
    Self.reply(result, err == dnsNoError ? nil : Self.dnsError("DNSServiceUpdateRecord", err))
  }

  /// Deallocating the connection withdraws its records (goodbye packets).
  private func unregisterHost() {
    hostProbeTimeout?.cancel()
    hostProbeTimeout = nil
    if let pending = pendingHostResult {
      pendingHostResult = nil
      Self.reply(pending, FlutterError(code: "cancelled", message: "host re-registered", details: nil))
    }
    if let connection = hostConnection { DNSServiceRefDeallocate(connection) }
    hostConnection = nil
    hostRecord = nil
    hostLabel = nil
    hostInterface = 0
  }

  // MARK: - Services

  private func registerService(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let name = args["name"] as? String,
          let type = args["type"] as? String,
          let port = args["port"] as? Int,
          let hostLabel = args["hostLabel"] as? String
    else {
      return Self.reply(result, Self.argumentError("registerService"))
    }
    let txt = Self.encodeTxt(args["txt"] as? [String: Any] ?? [:])
    var ref: DNSServiceRef?
    let err = txt.withUnsafeBytes { bytes in
      DNSServiceRegister(
        &ref,
        0,
        hostInterface,
        name,
        type,
        "local.",
        "\(hostLabel).local.",
        UInt16(port).bigEndian,
        UInt16(bytes.count),
        bytes.baseAddress,
        { _, _, errorCode, name, _, _, _ in
          if errorCode != dnsNoError {
            NSLog("DnsSdAdvertiser: service \(name.map { String(cString: $0) } ?? "?") failed: \(errorCode)")
          }
        },
        nil
      )
    }
    guard err == dnsNoError, let ref else {
      return Self.reply(result, Self.dnsError("DNSServiceRegister", err))
    }
    DNSServiceSetDispatchQueue(ref, queue)
    let handle = nextHandle
    nextHandle += 1
    services[handle] = ref
    Self.reply(result, handle)
  }

  // MARK: - Helpers

  private static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private static func argumentError(_ method: String) -> FlutterError {
    FlutterError(code: "arguments", message: "\(method): missing arguments", details: nil)
  }

  private static func dnsError(_ what: String, _ code: DNSServiceErrorType) -> FlutterError {
    FlutterError(code: "dnssd", message: "\(what) failed: \(code)", details: code)
  }

  private static func parseIPv4(_ string: String) -> in_addr? {
    var address = in_addr()
    return inet_pton(AF_INET, string, &address) == 1 ? address : nil
  }

  /// The interface holding [ipv4], so the A record is only published on the
  /// network that address belongs to. 0 (any) when not found.
  private static func interfaceIndex(for ipv4: String) -> UInt32 {
    var list: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&list) == 0, let first = list else { return 0 }
    defer { freeifaddrs(list) }
    for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
      guard let sa = entry.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0,
            String(cString: host) == ipv4
      else { continue }
      return if_nametoindex(entry.pointee.ifa_name)
    }
    return 0
  }

  /// RFC 6763 §6 TXT rdata: length-prefixed `key=value` strings.
  private static func encodeTxt(_ txt: [String: Any]) -> Data {
    var data = Data()
    for (key, value) in txt.sorted(by: { $0.key < $1.key }) {
      var entry = Data(key.utf8)
      if let bytes = value as? FlutterStandardTypedData {
        entry.append(UInt8(ascii: "="))
        entry.append(bytes.data)
      }
      guard entry.count <= 255 else { continue }
      data.append(UInt8(entry.count))
      data.append(entry)
    }
    // An empty TXT record is a single zero-length string.
    return data.isEmpty ? Data([0]) : data
  }
}
