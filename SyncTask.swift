import AppKit
import Foundation
import Network

// MARK: - Theme Configuration
enum ThemePreset: String, CaseIterable {
    case minimal
    case glass
    case childish

    var bgColor: NSColor {
        switch self {
        case .minimal:  return NSColor(hex: "#FEF9C3")!
        case .glass:    return NSColor(hex: "#090D16")!
        case .childish: return NSColor(hex: "#FFE3F1")!
        }
    }

    var surfaceColor: NSColor {
        switch self {
        case .minimal:  return NSColor(hex: "#FEFCE8")!
        case .glass:    return NSColor(hex: "#151D2A")!
        case .childish: return NSColor(hex: "#FFF6FA")!
        }
    }

    var textColor: NSColor {
        switch self {
        case .minimal:  return NSColor(hex: "#800020")!
        case .glass:    return NSColor(hex: "#F1F5F9")!
        case .childish: return NSColor(hex: "#FF4FA0")!
        }
    }

    var accentColor: NSColor {
        switch self {
        case .minimal:  return NSColor(hex: "#800020")!
        case .glass:    return NSColor(hex: "#6366F1")!
        case .childish: return NSColor(hex: "#FF4FA0")!
        }
    }

    var addBgColor: NSColor {
        switch self {
        case .minimal:  return NSColor(hex: "#800020")!
        case .glass:    return NSColor(hex: "#10B981")!
        case .childish: return NSColor(hex: "#FF4FA0")!
        }
    }

    var borderColor: NSColor {
        switch self {
        case .minimal:  return NSColor.black
        case .glass:    return NSColor(hex: "#263346")!
        case .childish: return NSColor.black
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .minimal, .glass: return 1.0
        case .childish:        return 2.0
        }
    }

    var dimColor: NSColor {
        switch self {
        case .minimal:  return NSColor(hex: "#595940")!
        case .glass:    return NSColor(hex: "#64748B")!
        case .childish: return NSColor(hex: "#8C6B9E")!
        }
    }

    var cornerRadius: CGFloat { 0.0 }
}

final class ThemeManager {
    static let shared = ThemeManager()
    static let notifName = NSNotification.Name("app.synctask.themeChanged")
    private let defaults = UserDefaults.standard

    var currentPreset: ThemePreset {
        get {
            let raw = defaults.string(forKey: "synctask_theme_preset") ?? "minimal"
            return ThemePreset(rawValue: raw) ?? .minimal
        }
        set {
            defaults.set(newValue.rawValue, forKey: "synctask_theme_preset")
            NotificationCenter.default.post(name: Self.notifName, object: nil)
        }
    }

    func cyclePreset() {
        let all = ThemePreset.allCases
        if let idx = all.firstIndex(of: currentPreset) {
            currentPreset = all[(idx + 1) % all.count]
        }
    }

    var currentBgColor: NSColor {
        if let hex = defaults.string(forKey: "synctask_bg_color_hex"), let c = NSColor(hex: hex) { return c }
        return currentPreset.bgColor
    }

    var currentTextColor: NSColor {
        if let hex = defaults.string(forKey: "synctask_text_color_hex"), let c = NSColor(hex: hex) { return c }
        return currentPreset.textColor
    }

    var currentAccentColor: NSColor {
        if let hex = defaults.string(forKey: "synctask_accent_color_hex"), let c = NSColor(hex: hex) { return c }
        return currentPreset.accentColor
    }

    var customFontName: String? {
        defaults.string(forKey: "synctask_font_name")
    }
}

var kBg: NSColor          { ThemeManager.shared.currentBgColor }
var kSurface: NSColor     { ThemeManager.shared.currentPreset.surfaceColor }
var kText: NSColor        { ThemeManager.shared.currentTextColor }
var kAccent: NSColor      { ThemeManager.shared.currentAccentColor }
var kAddBg: NSColor       { ThemeManager.shared.currentPreset.addBgColor }
var kDim: NSColor         { ThemeManager.shared.currentPreset.dimColor }
var kBorder: NSColor      { ThemeManager.shared.currentPreset.borderColor }
var kRadius: CGFloat      { ThemeManager.shared.currentPreset.cornerRadius }
var kBorderWidth: CGFloat { ThemeManager.shared.currentPreset.borderWidth }

func dynamicFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    if let name = ThemeManager.shared.customFontName, !name.isEmpty, let f = NSFont(name: name, size: size) {
        if weight == .bold || weight == .semibold || weight == .heavy {
            return NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
        }
        return f
    }
    return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
}

extension NSColor {
    convenience init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let val = UInt64(str, radix: 16) else { return nil }
        self.init(
            red: CGFloat((val & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((val & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(val & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    func toHex() -> String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}

// MARK: - Task Model & Store
struct Reminder: Codable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var isStarred: Bool
    var createdAt: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.isStarred = false
        self.createdAt = Date()
    }
}

final class ReminderStore {
    static let shared = ReminderStore()
    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("synctask")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("reminders.json")
    }()
    private(set) var items: [Reminder] = []
    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data) else { return }
        items = decoded
    }
    func save() {
        try? JSONEncoder().encode(items).write(to: url)
        SyncTaskServer.shared.pushCloudState()
    }
    func replaceFromCloud(_ cloudItems: [Reminder]) {
        items = cloudItems
        try? JSONEncoder().encode(items).write(to: url)
    }
    func add(_ r: Reminder) { items.append(r); save() }
    func toggle(id: UUID) { if let i = items.firstIndex(where: { $0.id == id }) { items[i].isCompleted.toggle(); save() } }
    func toggleStar(id: UUID) { if let i = items.firstIndex(where: { $0.id == id }) { items[i].isStarred.toggle(); save() } }
    func delete(id: UUID) { items.removeAll { $0.id == id }; save() }
    func clearCompleted() { items.removeAll { $0.isCompleted }; save() }
    func updateTitle(id: UUID, title: String) { if let i = items.firstIndex(where: { $0.id == id }) { items[i].title = title; save() } }
}

// MARK: - Embedded Lightweight HTTP + Cloud Sync Server (0 MB Extra RAM)
final class SyncTaskServer {
    static let shared = SyncTaskServer()
    private var listener: NWListener?
    private var cloudTimer: Timer?
    private var lastAppliedTimestamp: Double = 0
    private let queue = DispatchQueue(label: "app.synctask.syncserver", qos: .utility)

    var syncKey: String {
        get {
            if let k = UserDefaults.standard.string(forKey: "synctask_cloud_key"), !k.isEmpty { return k }
            let generated = "synctask_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
            UserDefaults.standard.set(generated, forKey: "synctask_cloud_key")
            return generated
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "synctask_cloud_key")
        }
    }

    var cloudTopicURL: URL {
        URL(string: "https://ntfy.sh/\(syncKey)")!
    }

    func getLanIP() -> String {
        var address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr {
            for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
                let interface = ptr.pointee
                if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        let candidate = String(cString: hostname)
                        if !candidate.isEmpty && !candidate.hasPrefix("127.") {
                            address = candidate
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let nwListener = try NWListener(using: params, on: 4321)
            nwListener.newConnectionHandler = { [weak self] conn in self?.handleConnection(conn) }
            nwListener.start(queue: queue)
            listener = nwListener
        } catch {}
        startCloudSync()
    }

    private func startCloudSync() {
        DispatchQueue.main.async {
            self.pushCloudState()
            self.cloudTimer?.invalidate()
            self.cloudTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
                self?.pullCloudState()
            }
        }
    }

    func pushCloudState() {
        let nowMs = Date().timeIntervalSince1970 * 1000.0
        lastAppliedTimestamp = max(lastAppliedTimestamp, nowMs)
        let data = buildStateJSON(source: "mac", updatedAt: nowMs)
        var req = URLRequest(url: cloudTopicURL)
        req.httpMethod = "POST"
        req.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        URLSession.shared.dataTask(with: req).resume()
    }

    private func pullCloudState() {
        guard let pollURL = URL(string: "\(cloudTopicURL.absoluteString)/raw?poll=1&since=all") else { return }
        var req = URLRequest(url: pollURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
            guard let self = self, err == nil, let data = data,
                  let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.split(whereSeparator: \.isNewline)
            guard let lastLine = lines.last,
                  let lineData = String(lastLine).data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any] else { return }
            let source = (json["source"] as? String) ?? ""
            let updatedAt = (json["updatedAt"] as? Double) ?? 0
            guard source == "phone", updatedAt > self.lastAppliedTimestamp,
                  let arr = json["reminders"] as? [[String: Any]] else { return }
            self.lastAppliedTimestamp = updatedAt
            var decoded: [Reminder] = []
            for item in arr {
                guard let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !title.isEmpty else { continue }
                var r = Reminder(title: title)
                if let idStr = item["id"] as? String, let uuid = UUID(uuidString: idStr) { r.id = uuid }
                if let done = item["isCompleted"] as? Bool { r.isCompleted = done }
                if let starred = item["isStarred"] as? Bool { r.isStarred = starred }
                if let ts = item["createdAt"] as? Double { r.createdAt = Date(timeIntervalSinceReferenceDate: ts) }
                decoded.append(r)
            }
            DispatchQueue.main.async {
                ReminderStore.shared.replaceFromCloud(decoded)
                NotificationCenter.default.post(name: NSNotification.Name("app.synctask.reload"), object: nil)
            }
        }.resume()
    }

    private func handleConnection(_ conn: NWConnection) {
        conn.start(queue: queue)
        receiveFullRequest(conn: conn, accumulated: Data())
    }

    private func receiveFullRequest(conn: NWConnection, accumulated: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { conn.cancel(); return }
            var buffer = accumulated
            if let d = data { buffer.append(d) }
            if let sepRange = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer.subdata(in: 0..<sepRange.lowerBound)
                let bodyData = buffer.subdata(in: sepRange.upperBound..<buffer.count)
                let headerStr = String(data: headerData, encoding: .utf8) ?? ""
                var contentLength = 0
                for line in headerStr.components(separatedBy: "\r\n") {
                    if line.lowercased().hasPrefix("content-length:") {
                        contentLength = Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) ?? 0
                    }
                }
                if bodyData.count < contentLength && !isComplete && error == nil {
                    self.receiveFullRequest(conn: conn, accumulated: buffer)
                    return
                }
                self.routeRequest(conn: conn, headerStr: headerStr, bodyData: bodyData)
            } else if !isComplete && error == nil && buffer.count < 65536 {
                self.receiveFullRequest(conn: conn, accumulated: buffer)
            } else {
                conn.cancel()
            }
        }
    }

    private func buildStateJSON(source: String = "mac", updatedAt: Double = Date().timeIntervalSince1970 * 1000.0) -> Data {
        let p = ThemeManager.shared.currentPreset
        let remindersArray: [[String: Any]] = ReminderStore.shared.items.map { r in
            [
                "id": r.id.uuidString.uppercased(),
                "title": r.title,
                "isCompleted": r.isCompleted,
                "isStarred": r.isStarred,
                "createdAt": r.createdAt.timeIntervalSinceReferenceDate
            ]
        }
        let payload: [String: Any] = [
            "source": source,
            "updatedAt": updatedAt,
            "syncKey": syncKey,
            "theme": [
                "preset": p.rawValue,
                "bgColor": ThemeManager.shared.currentBgColor.toHex(),
                "surfaceColor": p.surfaceColor.toHex(),
                "textColor": ThemeManager.shared.currentTextColor.toHex(),
                "addBgColor": p.addBgColor.toHex(),
                "borderColor": p.borderColor.toHex(),
                "dimColor": p.dimColor.toHex(),
                "fontName": ThemeManager.shared.customFontName ?? "monospace"
            ],
            "reminders": remindersArray
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
    }

    private func routeRequest(conn: NWConnection, headerStr: String, bodyData: Data) {
        let firstLine = headerStr.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { conn.cancel(); return }
        let method = parts[0].uppercased()
        let pathOnly = parts[1].components(separatedBy: "?").first ?? "/"

        if method == "OPTIONS" {
            sendResponse(conn: conn, status: "204 No Content", contentType: "text/plain", body: Data())
            return
        }
        if method == "GET" && pathOnly == "/api/state" {
            DispatchQueue.main.async {
                self.sendResponse(conn: conn, status: "200 OK", contentType: "application/json; charset=utf-8", body: self.buildStateJSON())
            }
            return
        }
        if method == "GET" && pathOnly == "/api/info" {
            let ip = getLanIP()
            let info: [String: Any] = ["lanIp": ip, "port": 4321, "phoneUrl": "http://\(ip):4321/"]
            let data = (try? JSONSerialization.data(withJSONObject: info)) ?? Data("{}".utf8)
            sendResponse(conn: conn, status: "200 OK", contentType: "application/json; charset=utf-8", body: data)
            return
        }
        if method == "POST" && pathOnly == "/api/mutate" {
            let json = (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: Any] ?? [:]
            let type = (json["type"] as? String) ?? ""
            DispatchQueue.main.async {
                let store = ReminderStore.shared
                switch type {
                case "ADD_REMINDER":
                    if let item = json["item"] as? [String: Any],
                       let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !title.isEmpty {
                        var rem = Reminder(title: title)
                        if let starred = item["isStarred"] as? Bool { rem.isStarred = starred }
                        store.add(rem)
                    }
                case "TOGGLE_REMINDER":
                    if let idStr = json["id"] as? String, let uuid = UUID(uuidString: idStr) { store.toggle(id: uuid) }
                case "TOGGLE_STAR":
                    if let idStr = json["id"] as? String, let uuid = UUID(uuidString: idStr) { store.toggleStar(id: uuid) }
                case "UPDATE_REMINDER":
                    if let idStr = json["id"] as? String, let uuid = UUID(uuidString: idStr),
                       let title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !title.isEmpty { store.updateTitle(id: uuid, title: title) }
                case "DELETE_REMINDER":
                    if let idStr = json["id"] as? String, let uuid = UUID(uuidString: idStr) { store.delete(id: uuid) }
                case "CLEAR_COMPLETED":
                    store.clearCompleted()
                default: break
                }
                NotificationCenter.default.post(name: NSNotification.Name("app.synctask.reload"), object: nil)
                var resp = Data("{\"ok\":true,\"state\":".utf8)
                resp.append(self.buildStateJSON())
                resp.append(Data("}".utf8))
                self.sendResponse(conn: conn, status: "200 OK", contentType: "application/json; charset=utf-8", body: resp)
            }
            return
        }
        if method == "GET" && pathOnly == "/synctask.apk" {
            let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
            let cwdDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let candidates = [
                cwdDir.appendingPathComponent("synctask.apk"),
                execDir.appendingPathComponent("synctask.apk")
            ]
            for url in candidates {
                if let apkData = try? Data(contentsOf: url) {
                    sendResponse(
                        conn: conn,
                        status: "200 OK",
                        contentType: "application/vnd.android.package-archive",
                        extraHeaders: "Content-Disposition: attachment; filename=\"synctask.apk\"\r\n",
                        body: apkData
                    )
                    return
                }
            }
            sendResponse(conn: conn, status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
            return
        }
        if method == "GET" && (pathOnly == "/" || pathOnly == "/index.html") {
            sendResponse(conn: conn, status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(Self.embeddedMobileHTML.utf8))
            return
        }
        sendResponse(conn: conn, status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
    }

    private func sendResponse(conn: NWConnection, status: String, contentType: String, extraHeaders: String = "", body: Data) {
        let header = "HTTP/1.1 \(status)\r\n" +
                     "Content-Type: \(contentType)\r\n" +
                     "Content-Length: \(body.count)\r\n" +
                     "Access-Control-Allow-Origin: *\r\n" +
                     "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                     "Access-Control-Allow-Headers: Content-Type\r\n" +
                     "Cache-Control: no-store\r\n" +
                     extraHeaders +
                     "Connection: close\r\n\r\n"
        var payload = Data(header.utf8)
        payload.append(body)
        conn.send(content: payload, completion: .contentProcessed { _ in conn.cancel() })
    }

    static let embeddedMobileHTML = """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no" />
<meta name="color-scheme" content="dark" />
<meta name="theme-color" id="metaTheme" content="#000000" />
<title>synctask</title>
<style>
:root {
  color-scheme: dark;
  --bg: #000000;
  --surface: #121212;
  --text: #FFFFFF;
  --add-bg: #27272A;
  --add-text: #FFFFFF;
  --border: #27272A;
  --dim: #71717A;
  --font: monospace, sans-serif;
}
* { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--font);
  min-height: 100dvh;
  padding: 14px;
  display: flex;
  flex-direction: column;
}
.bar { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
.title-wrap { display: flex; align-items: center; gap: 8px; }
h1 { font-size: 18px; font-weight: 700; }
.badge {
  background: var(--surface);
  color: var(--text);
  border: 1px solid var(--border);
  font-size: 11px;
  font-weight: 700;
  padding: 2px 7px;
}
.btn {
  background: var(--surface);
  color: var(--text);
  border: 1px solid var(--border);
  font-family: var(--font);
  font-size: 12px;
  font-weight: 700;
  padding: 6px 12px;
  cursor: pointer;
}
.btn-primary { background: var(--add-bg); color: var(--add-text); }
.tabs { display: grid; grid-template-columns: 1fr 1fr; margin-bottom: 10px; }
.tab {
  background: transparent;
  color: var(--text);
  border: 1px solid var(--border);
  font-family: var(--font);
  font-size: 12px;
  padding: 6px;
  cursor: pointer;
}
.tab.active { background: var(--surface); font-weight: 700; }
.list { flex: 1; display: flex; flex-direction: column; gap: 5px; overflow-y: auto; }
.row {
  background: var(--surface);
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  min-height: 38px;
}
.row.starred { border: 1.5px solid #F59E0B; }
.check {
  width: 20px; height: 20px;
  border: 1px solid var(--border);
  background: transparent;
  color: #FFFFFF;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
}
.row.done .check { background: var(--border); }
.row-title { flex: 1; font-size: 13px; font-weight: 500; word-break: break-word; cursor: pointer; }
.row.starred .row-title { color: #F59E0B; font-weight: 700; }
.row.done .row-title { color: var(--dim); text-decoration: line-through; }
.star, .del {
  width: 24px; height: 24px;
  border: 1px solid var(--border);
  background: transparent;
  color: var(--dim);
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}
.row.starred .star { background: #F59E0B; border-color: #D97706; color: #FFFFFF; }
.del { border: none; }
.footer { display: flex; align-items: center; justify-content: space-between; margin-top: 10px; padding-top: 6px; font-size: 11px; }
.link-btn { background: none; border: none; color: var(--text); font-family: var(--font); font-size: 11px; cursor: pointer; }
.status { color: var(--dim); font-size: 10px; cursor: pointer; text-decoration: underline; }
.modal {
  position: fixed; inset: 0; background: rgba(0,0,0,0.65);
  display: flex; align-items: center; justify-content: center; padding: 16px;
}
.modal[hidden] { display: none; }
.panel {
  width: 100%; max-width: 340px;
  background: var(--bg);
  border: 1px solid var(--border);
  padding: 14px;
}
.panel-label { font-size: 11px; font-weight: 700; margin-bottom: 6px; display: block; }
.input {
  width: 100%;
  background: var(--surface);
  color: var(--text);
  border: 1px solid var(--border);
  font-family: var(--font);
  font-size: 14px;
  font-weight: 700;
  padding: 8px 10px;
  margin-bottom: 12px;
  outline: none;
}
.actions { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.apk-bar {
  display: flex; align-items: center; justify-content: space-between;
  background: var(--surface); border: 1px solid var(--border);
  padding: 6px 10px; margin-bottom: 10px; font-size: 11px;
}
.apk-bar a { color: var(--text); font-weight: 700; text-decoration: none; }
</style>
</head>
<body>
<div class="apk-bar" id="apkBar">
  <a href="/synctask.apk" download="synctask.apk">Download Android App (APK)</a>
  <button class="link-btn" id="closeApkBar" type="button">x</button>
</div>
<div class="bar">
  <div class="title-wrap">
    <h1>synctask</h1>
    <span class="badge" id="badge">0</span>
  </div>
  <button class="btn btn-primary" id="addOpenBtn" type="button">+ Add</button>
</div>
<div class="tabs">
  <button class="tab active" id="tabActive" type="button">Active</button>
  <button class="tab" id="tabDone" type="button">Done</button>
</div>
<div class="list" id="list"></div>
<div class="footer">
  <button class="link-btn" id="clearBtn" type="button">Clear Done</button>
  <span class="status" id="status" title="Tap to configure Mac IP">Host: Auto</span>
</div>
<div class="modal" id="modal" hidden>
  <form class="panel" id="form">
    <span class="panel-label" id="modalLabel">Task</span>
    <input class="input" id="input" type="text" placeholder="What to do?" autocomplete="off" />
    <div class="actions">
      <button class="btn" id="cancelBtn" type="button">Cancel</button>
      <button class="btn btn-primary" id="saveBtn" type="submit">Add</button>
    </div>
  </form>
</div>
<script>
(() => {
  const isNative = Boolean(window.SyncTaskNative) || window.location.protocol === 'file:';
  if (isNative) {
    const bar = document.getElementById('apkBar');
    if (bar) bar.remove();
  } else {
    document.getElementById('closeApkBar').onclick = () => document.getElementById('apkBar').remove();
  }

  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('key')) {
    localStorage.setItem('synctask_host', urlParams.get('key'));
    if (window.SyncTaskNative && window.SyncTaskNative.setMacHost) {
      window.SyncTaskNative.setMacHost(urlParams.get('key'));
    }
  }

  function getSyncKey() {
    if (window.SyncTaskNative && window.SyncTaskNative.getMacHost) {
      const nativeKey = window.SyncTaskNative.getMacHost();
      if (nativeKey) return nativeKey;
    }
    return localStorage.getItem('synctask_host') || '';
  }

  function getCloudUrl() {
    const k = getSyncKey();
    return k ? ('https://ntfy.sh/' + encodeURIComponent(k)) : '';
  }

  let state = { reminders: [], theme: null };
  let tab = 0;
  let modalMode = 'add';
  let editId = null;

  try {
    const cached = JSON.parse(localStorage.getItem('synctask_state') || 'null');
    if (cached && Array.isArray(cached.reminders)) state = cached;
  } catch (_) {}

  const listEl = document.getElementById('list');
  const badgeEl = document.getElementById('badge');
  const statusEl = document.getElementById('status');
  const modal = document.getElementById('modal');
  const modalLabel = document.getElementById('modalLabel');
  const form = document.getElementById('form');
  const input = document.getElementById('input');
  const saveBtn = document.getElementById('saveBtn');

  document.getElementById('tabActive').onclick = () => { tab = 0; render(); };
  document.getElementById('tabDone').onclick = () => { tab = 1; render(); };
  document.getElementById('addOpenBtn').onclick = () => openModal('add', null);
  document.getElementById('cancelBtn').onclick = () => { modal.hidden = true; };
  document.getElementById('clearBtn').onclick = () => mutate({ type: 'CLEAR_COMPLETED' });
  statusEl.onclick = () => openModal('host', null);

  function openModal(mode, item) {
    modalMode = mode;
    if (mode === 'host') {
      modalLabel.textContent = 'Sync Key (shown in Mac widget Sync panel)';
      input.placeholder = 'synctask_...';
      input.value = getSyncKey();
      saveBtn.textContent = 'Connect';
    } else {
      editId = item ? item.id : null;
      modalLabel.textContent = item ? 'Edit Task' : 'New Task';
      input.placeholder = 'What to do?';
      input.value = item ? item.title : '';
      saveBtn.textContent = item ? 'Save' : 'Add';
    }
    modal.hidden = false;
    setTimeout(() => input.focus(), 20);
  }

  form.onsubmit = (e) => {
    e.preventDefault();
    const val = input.value.trim();
    if (!val) return;
    modal.hidden = true;
    if (modalMode === 'host') {
      const clean = val.replace(/^https?:\\/\\//, '').replace(/\\/+$/, '');
      localStorage.setItem('synctask_host', clean);
      if (window.SyncTaskNative && window.SyncTaskNative.setMacHost) {
        window.SyncTaskNative.setMacHost(clean);
      }
      pull();
      return;
    }
    if (editId) mutate({ type: 'UPDATE_REMINDER', id: editId, title: val });
    else mutate({ type: 'ADD_REMINDER', item: { title: val, isStarred: false } });
  };

  function applyTheme(t) {
    document.getElementById('metaTheme').content = '#000000';
  }

  function render() {
    applyTheme(state.theme);
    const items = Array.isArray(state.reminders) ? state.reminders : [];
    const activeCount = items.filter(i => !i.isCompleted).length;
    badgeEl.textContent = activeCount;
    badgeEl.style.display = activeCount ? 'inline-block' : 'none';
    document.getElementById('tabActive').classList.toggle('active', tab === 0);
    document.getElementById('tabDone').classList.toggle('active', tab === 1);

    const filtered = items
      .filter(i => tab === 1 ? i.isCompleted : !i.isCompleted)
      .sort((a, b) => (a.isStarred !== b.isStarred) ? (a.isStarred ? -1 : 1) : ((b.createdAt || 0) - (a.createdAt || 0)));

    listEl.innerHTML = '';
    for (const item of filtered) {
      const row = document.createElement('div');
      row.className = 'row' + (item.isCompleted ? ' done' : '') + (item.isStarred ? ' starred' : '');

      const check = document.createElement('button');
      check.className = 'check';
      check.textContent = item.isCompleted ? 'v' : '';
      check.onclick = () => mutate({ type: 'TOGGLE_REMINDER', id: item.id });

      const title = document.createElement('div');
      title.className = 'row-title';
      title.textContent = item.title;
      title.onclick = () => openModal('edit', item);

      const star = document.createElement('button');
      star.className = 'star';
      star.textContent = '*';
      star.onclick = () => mutate({ type: 'TOGGLE_STAR', id: item.id });

      const del = document.createElement('button');
      del.className = 'del';
      del.textContent = 'x';
      del.onclick = () => mutate({ type: 'DELETE_REMINDER', id: item.id });

      row.append(check, title, star, del);
      listEl.appendChild(row);
    }
  }

  async function pull() {
    if (document.visibilityState === 'hidden') return;
    const cloud = getCloudUrl();
    if (!cloud) {
      statusEl.textContent = 'Tap to set Sync Key';
      return;
    }
    try {
      const res = await fetch(cloud + '/raw?poll=1&since=all&_t=' + Date.now(), { cache: 'no-store' });
      const text = await res.text();
      const lines = text.split(/\\r?\\n/).map(l => l.trim()).filter(Boolean);
      for (let i = lines.length - 1; i >= 0; i--) {
        try {
          const data = JSON.parse(lines[i]);
          if (data && Array.isArray(data.reminders)) {
            state = data;
            localStorage.setItem('synctask_state', JSON.stringify(state));
            statusEl.textContent = 'Cloud Synced (Any Wi-Fi / 5G)';
            render();
            break;
          }
        } catch (_) {}
      }
    } catch (_) {
      statusEl.textContent = 'Offline (Tap to set Sync Key)';
    }
  }

  async function mutate(payload) {
    const items = Array.isArray(state.reminders) ? state.reminders.map(r => ({ ...r })) : [];
    const type = payload.type;
    if (type === 'ADD_REMINDER' && payload.item && payload.item.title) {
      const id = (crypto.randomUUID ? crypto.randomUUID() : ('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
        const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
      }))).toUpperCase();
      items.push({ id, title: payload.item.title.trim(), isCompleted: false, isStarred: Boolean(payload.item.isStarred), createdAt: (Date.now() / 1000) - 978307200 });
    } else if (type === 'TOGGLE_REMINDER') {
      const idx = items.findIndex(r => r.id === payload.id);
      if (idx >= 0) items[idx].isCompleted = !items[idx].isCompleted;
    } else if (type === 'TOGGLE_STAR') {
      const idx = items.findIndex(r => r.id === payload.id);
      if (idx >= 0) items[idx].isStarred = !items[idx].isStarred;
    } else if (type === 'UPDATE_REMINDER') {
      const idx = items.findIndex(r => r.id === payload.id);
      if (idx >= 0 && payload.title) items[idx].title = payload.title.trim();
    } else if (type === 'DELETE_REMINDER') {
      const idx = items.findIndex(r => r.id === payload.id);
      if (idx >= 0) items.splice(idx, 1);
    } else if (type === 'CLEAR_COMPLETED') {
      for (let i = items.length - 1; i >= 0; i--) { if (items[i].isCompleted) items.splice(i, 1); }
    }
    state = { ...state, source: 'phone', updatedAt: Date.now(), reminders: items };
    localStorage.setItem('synctask_state', JSON.stringify(state));
    render();
    if (window.SyncTaskNative && window.SyncTaskNative.refreshHomeWidget) {
      window.SyncTaskNative.refreshHomeWidget();
    }
    const cloud = getCloudUrl();
    if (!cloud) return;
    try {
      await fetch(cloud, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        body: JSON.stringify(state)
      });
      statusEl.textContent = 'Cloud Synced (Any Wi-Fi / 5G)';
    } catch (_) {
      statusEl.textContent = 'Offline';
    }
  }

  render();
  if (!getSyncKey() && isNative) {
    openModal('host', null);
  } else {
    pull();
  }
  setInterval(pull, 2500);
  document.addEventListener('visibilitychange', pull);
})();
</script>
</body>
</html>
"""
}

// MARK: - Desktop Widget Views
final class ReminderRowView: NSView {
    var reminder: Reminder { didSet { updateUI() } }
    var onToggle:     ((UUID) -> Void)?
    var onStarToggle: ((UUID) -> Void)?
    var onDelete:     ((UUID) -> Void)?
    var onEdit:       ((UUID, String) -> Void)?

    private let check   = NSButton()
    private let label   = NSTextField()
    private let starBtn = NSButton()
    private let del     = NSButton()

    init(_ reminder: Reminder) {
        self.reminder = reminder
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        wantsLayer = true
        layer?.cornerRadius = kRadius / 2
        layer?.backgroundColor = kSurface.cgColor

        check.isBordered = false; check.bezelStyle = .regularSquare; check.setButtonType(.momentaryChange)
        check.wantsLayer = true; check.layer?.cornerRadius = 4; check.layer?.borderWidth = kBorderWidth; check.layer?.borderColor = kBorder.cgColor
        check.target = self; check.action = #selector(toggleTapped); addSubview(check)

        label.isBordered = false; label.backgroundColor = .clear; label.isEditable = false
        label.lineBreakMode = .byTruncatingTail
        let dclick = NSClickGestureRecognizer(target: self, action: #selector(editTapped))
        dclick.numberOfClicksRequired = 2
        label.addGestureRecognizer(dclick)
        addSubview(label)

        starBtn.isBordered = false; starBtn.wantsLayer = true; starBtn.layer?.cornerRadius = 5
        starBtn.layer?.borderWidth = kBorderWidth; starBtn.layer?.borderColor = kBorder.cgColor
        starBtn.target = self; starBtn.action = #selector(starTapped)
        addSubview(starBtn)

        del.title = "x"; del.font = dynamicFont(size: 10, weight: .bold); del.isBordered = false
        del.contentTintColor = kDim; del.target = self; del.action = #selector(deleteTapped); del.alphaValue = 0.7
        addSubview(del)

        updateUI()
    }

    func updateUI() {
        layer?.backgroundColor = kSurface.cgColor
        check.layer?.borderColor = kBorder.cgColor
        check.layer?.backgroundColor = reminder.isCompleted ? kBorder.cgColor : NSColor.clear.cgColor
        check.attributedTitle = reminder.isCompleted
            ? NSAttributedString(string: "v", attributes: [.font: dynamicFont(size: 10, weight: .bold), .foregroundColor: NSColor.white])
            : NSAttributedString(string: "")

        if reminder.isCompleted {
            let s = NSMutableAttributedString(string: reminder.title)
            let r = NSRange(location: 0, length: reminder.title.count)
            s.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: r)
            s.addAttribute(.foregroundColor, value: kDim, range: r)
            label.attributedStringValue = s
            starBtn.layer?.backgroundColor = NSColor.clear.cgColor
            starBtn.layer?.borderColor = kBorder.cgColor
            starBtn.attributedTitle = NSAttributedString(string: "*", attributes: [.font: dynamicFont(size: 12, weight: .bold), .foregroundColor: kDim])
        } else if reminder.isStarred {
            let amber = NSColor(hex: "#F59E0B")!
            label.stringValue = reminder.title
            label.textColor = amber
            label.font = dynamicFont(size: 13, weight: .bold)
            starBtn.layer?.backgroundColor = amber.cgColor
            starBtn.layer?.borderColor = amber.cgColor
            starBtn.attributedTitle = NSAttributedString(string: "*", attributes: [.font: dynamicFont(size: 13, weight: .bold), .foregroundColor: NSColor.white])
        } else {
            label.stringValue = reminder.title
            label.textColor = kText
            label.font = dynamicFont(size: 13, weight: .medium)
            starBtn.layer?.backgroundColor = NSColor.clear.cgColor
            starBtn.layer?.borderColor = kBorder.cgColor
            starBtn.attributedTitle = NSAttributedString(string: "*", attributes: [.font: dynamicFont(size: 12, weight: .bold), .foregroundColor: kDim])
        }
    }

    override func layout() {
        super.layout()
        let h = bounds.height, w = bounds.width
        check.frame   = NSRect(x: 10, y: (h - 18) / 2, width: 18, height: 18)
        starBtn.frame = NSRect(x: w - 52, y: (h - 24) / 2, width: 24, height: 24)
        del.frame     = NSRect(x: w - 24, y: (h - 18) / 2, width: 18, height: 18)
        label.frame   = NSRect(x: 34, y: (h - 18) / 2, width: w - 90, height: 18)
    }

    @objc private func toggleTapped() { onToggle?(reminder.id) }
    @objc private func starTapped()   { onStarToggle?(reminder.id) }
    @objc private func deleteTapped() { onDelete?(reminder.id) }
    @objc private func editTapped() {
        guard let window = self.window else { return }
        let alert = NSAlert()
        alert.messageText = "Edit task"
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        tf.stringValue = reminder.title
        alert.accessoryView = tf
        alert.beginSheetModal(for: window) { [weak self] r in
            guard let self = self, r == .alertFirstButtonReturn else { return }
            let t = tf.stringValue.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { self.onEdit?(self.reminder.id, t) }
        }
    }
}

final class AddPanel: NSView {
    var onAdd:    ((Reminder) -> Void)?
    var onCancel: (() -> Void)?

    private let titleField = NSTextField()
    private let addBtn     = NSButton()
    private let cancelBtn  = NSButton()

    override init(frame: NSRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        wantsLayer = true
        titleField.drawsBackground = true
        titleField.font = dynamicFont(size: 13, weight: .bold); titleField.focusRingType = .none
        titleField.isBordered = true; titleField.bezelStyle = .squareBezel
        addSubview(titleField)

        addBtn.title = "Add"; addBtn.isBordered = false; addBtn.wantsLayer = true
        addBtn.font = dynamicFont(size: 12, weight: .bold)
        addBtn.target = self; addBtn.action = #selector(addTapped); addSubview(addBtn)

        cancelBtn.title = "Cancel"; cancelBtn.isBordered = false; cancelBtn.wantsLayer = true
        cancelBtn.font = dynamicFont(size: 12, weight: .bold)
        cancelBtn.target = self; cancelBtn.action = #selector(cancelTapped); addSubview(cancelBtn)
        refreshTheme()
    }

    func refreshTheme() {
        layer?.backgroundColor = kBg.cgColor
        layer?.borderWidth = kBorderWidth
        layer?.borderColor = kBorder.cgColor
        titleField.backgroundColor = kSurface
        titleField.textColor = kText
        addBtn.layer?.backgroundColor = kAddBg.cgColor
        addBtn.contentTintColor = kSurface
        cancelBtn.layer?.backgroundColor = kSurface.cgColor
        cancelBtn.contentTintColor = kText
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        titleField.frame = NSRect(x: 14, y: h - 54, width: w - 28, height: 32)
        cancelBtn.frame  = NSRect(x: 14, y: 14, width: (w - 36) / 2, height: 30)
        addBtn.frame     = NSRect(x: 22 + (w - 36) / 2, y: 14, width: (w - 36) / 2, height: 30)
    }

    func clear() { titleField.stringValue = "" }

    @objc private func addTapped() {
        let t = titleField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        onAdd?(Reminder(title: t))
    }
    @objc private func cancelTapped() { onCancel?() }
}

final class PhoneQRPanel: NSView {
    var onClose: (() -> Void)?

    private let titleLabel = NSTextField()
    private let qrView     = NSImageView()
    private let urlLabel   = NSTextField()
    private let copyBtn    = NSButton()
    private let closeBtn   = NSButton()
    private var currentUrl = "http://127.0.0.1:4321/"

    override init(frame: NSRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        wantsLayer = true
        titleLabel.stringValue = "MOBILE LIVE SYNC"
        titleLabel.font = dynamicFont(size: 11, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isEditable = false; titleLabel.isBordered = false; titleLabel.backgroundColor = .clear
        addSubview(titleLabel)

        qrView.wantsLayer = true
        qrView.layer?.backgroundColor = NSColor.white.cgColor
        qrView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(qrView)

        urlLabel.font = dynamicFont(size: 9, weight: .bold)
        urlLabel.alignment = .center
        urlLabel.isEditable = false; urlLabel.isBordered = false; urlLabel.backgroundColor = .clear
        addSubview(urlLabel)

        copyBtn.title = "Copy URL"; copyBtn.isBordered = false; copyBtn.wantsLayer = true
        copyBtn.font = dynamicFont(size: 11, weight: .bold)
        copyBtn.target = self; copyBtn.action = #selector(copyTapped)
        addSubview(copyBtn)

        closeBtn.title = "Done"; closeBtn.isBordered = false; closeBtn.wantsLayer = true
        closeBtn.font = dynamicFont(size: 11, weight: .bold)
        closeBtn.target = self; closeBtn.action = #selector(closeTapped)
        addSubview(closeBtn)

        refreshQR()
    }

    func refreshQR() {
        layer?.backgroundColor = kBg.cgColor
        layer?.borderWidth = kBorderWidth + 1
        layer?.borderColor = kBorder.cgColor
        titleLabel.textColor = kText
        urlLabel.textColor = kDim
        qrView.layer?.borderWidth = kBorderWidth
        qrView.layer?.borderColor = kBorder.cgColor
        copyBtn.layer?.backgroundColor = kSurface.cgColor
        copyBtn.contentTintColor = kText
        closeBtn.layer?.backgroundColor = kAddBg.cgColor
        closeBtn.contentTintColor = kSurface

        let ip = SyncTaskServer.shared.getLanIP()
        let key = SyncTaskServer.shared.syncKey
        currentUrl = "http://\(ip):4321/?key=\(key)"
        urlLabel.stringValue = "Sync Key: \(key)"
        if let data = currentUrl.data(using: .utf8),
           let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            if let output = filter.outputImage {
                let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
                let rep = NSCIImageRep(ciImage: scaled)
                let img = NSImage(size: rep.size)
                img.addRepresentation(rep)
                qrView.image = img
            }
        }
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        titleLabel.frame = NSRect(x: 10, y: h - 26, width: w - 20, height: 18)
        let qrSize: CGFloat = 148
        qrView.frame     = NSRect(x: (w - qrSize) / 2, y: h - 32 - qrSize, width: qrSize, height: qrSize)
        urlLabel.frame   = NSRect(x: 8, y: 46, width: w - 16, height: 16)
        copyBtn.frame    = NSRect(x: 12, y: 12, width: (w - 32) / 2, height: 28)
        closeBtn.frame   = NSRect(x: 20 + (w - 32) / 2, y: 12, width: (w - 32) / 2, height: 28)
    }

    @objc private func copyTapped() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentUrl, forType: .string)
    }
    @objc private func closeTapped() { onClose?() }
}

final class TodoView: NSView {
    private var rows: [UUID: ReminderRowView] = [:]
    private var filterIdx = 0
    private var panelShown = false
    private var qrShown = false
    private var dragStart: NSPoint = .zero, initialWinOrigin: NSPoint = .zero, dragActive = false

    private let scroll       = NSScrollView()
    private let list         = NSView()
    private let panel        = AddPanel()
    private let qrPanel      = PhoneQRPanel()
    private let header       = NSTextField()
    private let badge        = NSTextField()
    private let addBtn       = NSButton()
    private let clearBtn     = NSButton()
    private let themeBtn     = NSButton()
    private let syncBtn      = NSButton()
    private let activeTabBtn = NSButton()
    private let doneTabBtn   = NSButton()

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
        reload()
        NotificationCenter.default.addObserver(self, selector: #selector(onReload), name: NSNotification.Name("app.synctask.reload"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onThemeChanged), name: ThemeManager.notifName, object: nil)
        SyncTaskServer.shared.start()
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func onReload() {
        DispatchQueue.main.async { self.reload(); self.needsDisplay = true }
    }

    @objc private func onThemeChanged() {
        DispatchQueue.main.async {
            self.applyThemeColors()
            self.reload()
            self.needsDisplay = true
        }
    }

    private func build() {
        wantsLayer = true

        header.stringValue = "synctask"
        header.font = dynamicFont(size: 17, weight: .bold)
        header.isEditable = false; header.isBordered = false; header.backgroundColor = .clear
        addSubview(header)

        badge.font = dynamicFont(size: 10, weight: .bold); badge.alignment = .center
        badge.isEditable = false; badge.isBordered = false; badge.backgroundColor = .clear; badge.wantsLayer = true
        addSubview(badge)

        activeTabBtn.title = "Active"; activeTabBtn.isBordered = false; activeTabBtn.wantsLayer = true
        activeTabBtn.target = self; activeTabBtn.action = #selector(activeTabTapped); addSubview(activeTabBtn)

        doneTabBtn.title = "Done"; doneTabBtn.isBordered = false; doneTabBtn.wantsLayer = true
        doneTabBtn.target = self; doneTabBtn.action = #selector(doneTabTapped); addSubview(doneTabBtn)

        addBtn.title = "+ Add"; addBtn.font = dynamicFont(size: 12, weight: .bold); addBtn.isBordered = false; addBtn.wantsLayer = true
        addBtn.target = self; addBtn.action = #selector(showPanel); addSubview(addBtn)

        clearBtn.title = "Clear Done"; clearBtn.font = dynamicFont(size: 11, weight: .medium)
        clearBtn.isBordered = false; clearBtn.target = self; clearBtn.action = #selector(clearDone); addSubview(clearBtn)

        themeBtn.title = "Theme"; themeBtn.font = dynamicFont(size: 10, weight: .bold)
        themeBtn.isBordered = false; themeBtn.wantsLayer = true
        themeBtn.target = self; themeBtn.action = #selector(cycleTheme); addSubview(themeBtn)

        syncBtn.title = "Sync"; syncBtn.font = dynamicFont(size: 10, weight: .bold)
        syncBtn.isBordered = false; syncBtn.wantsLayer = true
        syncBtn.target = self; syncBtn.action = #selector(toggleQRPanel); addSubview(syncBtn)

        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false; scroll.documentView = list; addSubview(scroll)

        panel.isHidden = true; panel.onAdd = { [weak self] r in ReminderStore.shared.add(r); self?.panel.isHidden = true; self?.panelShown = false; self?.reload() }
        panel.onCancel = { [weak self] in self?.panel.isHidden = true; self?.panelShown = false }
        addSubview(panel)

        qrPanel.isHidden = true; qrPanel.onClose = { [weak self] in self?.qrPanel.isHidden = true; self?.qrShown = false }
        addSubview(qrPanel)

        applyThemeColors()
    }

    private func applyThemeColors() {
        layer?.backgroundColor = kBg.cgColor
        header.textColor = kText
        badge.textColor = kText
        badge.layer?.borderWidth = kBorderWidth
        badge.layer?.borderColor = kBorder.cgColor
        badge.layer?.backgroundColor = kSurface.cgColor
        addBtn.layer?.borderWidth = kBorderWidth
        addBtn.layer?.borderColor = kBorder.cgColor
        addBtn.layer?.backgroundColor = kAddBg.cgColor
        addBtn.contentTintColor = kSurface
        clearBtn.contentTintColor = kText
        for btn in [themeBtn, syncBtn] {
            btn.layer?.borderWidth = kBorderWidth
            btn.layer?.borderColor = kBorder.cgColor
            btn.layer?.backgroundColor = kSurface.cgColor
            btn.contentTintColor = kText
        }
        panel.refreshTheme()
        qrPanel.refreshQR()
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        header.frame       = NSRect(x: 16, y: h - 42, width: 120, height: 24)
        badge.frame        = NSRect(x: 140, y: h - 37, width: 26, height: 18)
        addBtn.frame       = NSRect(x: w - 78, y: h - 40, width: 64, height: 24)
        let tabW           = (w - 28) / 2
        activeTabBtn.frame = NSRect(x: 14, y: h - 72, width: tabW, height: 24)
        doneTabBtn.frame   = NSRect(x: 14 + tabW, y: h - 72, width: tabW, height: 24)
        clearBtn.frame     = NSRect(x: 14, y: 10, width: 78, height: 18)
        themeBtn.frame     = NSRect(x: w - 144, y: 9, width: 58, height: 20)
        syncBtn.frame      = NSRect(x: w - 80, y: 9, width: 66, height: 20)
        scroll.frame       = NSRect(x: 10, y: 34, width: w - 20, height: h - 112)
        panel.frame        = NSRect(x: 10, y: h / 2 - 78, width: w - 20, height: 156)
        qrPanel.frame      = NSRect(x: 12, y: h / 2 - 125, width: w - 24, height: 250)
        relayoutList()
    }

    @objc private func activeTabTapped() { filterIdx = 0; reload() }
    @objc private func doneTabTapped()   { filterIdx = 1; reload() }
    @objc private func showPanel()       { qrPanel.isHidden = true; qrShown = false; panelShown = true; panel.clear(); panel.isHidden = false }
    @objc private func toggleQRPanel()   { panel.isHidden = true; panelShown = false; qrShown.toggle(); qrPanel.refreshQR(); qrPanel.isHidden = !qrShown }
    @objc private func cycleTheme()      { ThemeManager.shared.cyclePreset() }
    @objc private func clearDone()       { ReminderStore.shared.clearCompleted(); reload() }

    private func filtered() -> [Reminder] {
        let raw = filterIdx == 1 ? ReminderStore.shared.items.filter { $0.isCompleted } : ReminderStore.shared.items.filter { !$0.isCompleted }
        return raw.sorted { a, b in a.isStarred != b.isStarred ? (a.isStarred && !b.isStarred) : (a.createdAt > b.createdAt) }
    }

    func reload() {
        let pending = ReminderStore.shared.items.filter { !$0.isCompleted }.count
        badge.stringValue = "\(pending)"
        badge.isHidden = pending == 0
        for (idx, btn) in [(0, activeTabBtn), (1, doneTabBtn)] {
            let active = (filterIdx == idx)
            btn.layer?.borderWidth = kBorderWidth
            btn.layer?.borderColor = kBorder.cgColor
            btn.layer?.backgroundColor = (active ? kSurface : .clear).cgColor
            btn.attributedTitle = NSAttributedString(string: idx == 0 ? "Active" : "Done", attributes: [
                .font: dynamicFont(size: 11, weight: active ? .bold : .medium),
                .foregroundColor: kText
            ])
        }

        let filterList = filtered()
        let ids = Set(filterList.map { $0.id })
        for (id, v) in rows where !ids.contains(id) { v.removeFromSuperview(); rows.removeValue(forKey: id) }
        for r in filterList {
            if let existing = rows[r.id] {
                existing.reminder = r
            } else {
                let row = ReminderRowView(r)
                row.onToggle     = { [weak self] id in ReminderStore.shared.toggle(id: id); self?.reload() }
                row.onStarToggle = { [weak self] id in ReminderStore.shared.toggleStar(id: id); self?.reload() }
                row.onDelete     = { [weak self] id in ReminderStore.shared.delete(id: id); self?.reload() }
                row.onEdit       = { [weak self] id, t in ReminderStore.shared.updateTitle(id: id, title: t); self?.reload() }
                list.addSubview(row)
                rows[r.id] = row
            }
        }
        relayoutList()
    }

    private func relayoutList() {
        let filterList = filtered()
        let rowH: CGFloat = 34, gap: CGFloat = 4, totalH = CGFloat(filterList.count) * (rowH + gap)
        let w = scroll.bounds.width
        list.frame = NSRect(x: 0, y: 0, width: w, height: max(totalH, scroll.bounds.height))
        for (i, r) in filterList.enumerated() {
            rows[r.id]?.frame = NSRect(x: 0, y: list.frame.height - CGFloat(i + 1) * (rowH + gap), width: w, height: rowH)
        }
    }

    override func mouseDown(with event: NSEvent) { dragStart = NSEvent.mouseLocation; if let w = window { initialWinOrigin = w.frame.origin }; dragActive = true; window?.makeKey() }
    override func mouseDragged(with event: NSEvent) {
        guard dragActive, let w = window else { return }
        let c = NSEvent.mouseLocation
        w.setFrameOrigin(NSPoint(x: initialWinOrigin.x + (c.x - dragStart.x), y: initialWinOrigin.y + (c.y - dragStart.y)))
    }
    override func mouseUp(with event: NSEvent) { dragActive = false }
}

final class DesktopWidgetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: DesktopWidgetWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let frame = NSRect(x: 80, y: 420, width: 280, height: 320)
        let win = DesktopWidgetWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.contentView = TodoView(frame: NSRect(origin: .zero, size: frame.size))
        win.orderFrontRegardless()
        window = win
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
