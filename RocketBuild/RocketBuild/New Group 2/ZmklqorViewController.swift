import UIKit
import WebKit
import AdjustSdk

// MARK: - 桥接关键字容器
// tokCsv 形如: jsBridge,amount,currency,openWindow
// 首个元素为消息通道名，其余为业务字段键。以惰性容器承载，避免裸全局数组。

internal enum Gtktns {
    private static var cyyzte: [String] = []

    static func seed(_ csv: String) {
        cyyzte = csv.components(separatedBy: ",")
    }

    private static func at(_ idx: Int) -> String {
        (idx >= 0 && idx < cyyzte.count) ? cyyzte[idx] : ""
    }

    static var vhys: String  { at(0) }   // jsBridge
    static var amots: String   { at(1) }   // amount
    static var cteyu: String { at(2) }   // currency
    static var opce: String    { at(3) }   // openWindow
}

// MARK: - 归因回调

extension ZmklqorViewController: AdjustDelegate {
    public func adjustEventTrackingSucceeded(_ eventSuccessResponse: ADJEventSuccess?) {
        print(eventSuccessResponse as Any)
    }

    public func adjustEventTrackingFailed(_ eventFailureResponse: ADJEventFailure?) {
        print(eventFailureResponse as Any)
    }
}

// MARK: - 落地页宿主

internal final class ZmklqorViewController: UIViewController {

    var dmqxo: Hwqmztb?
    private var surface: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        bootAttribution()
        Gtktns.seed(dmqxo?.tokCsv ?? "")
        mountSurface()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutSurface()
    }

    // MARK: 归因初始化

    private func bootAttribution() {
        guard let token = dmqxo?.atybu else { return }
        let cfg = ADJConfig(appToken: token, environment: ADJEnvironmentProduction)
        cfg?.delegate = self
        Adjust.initSdk(cfg)
    }

    // MARK: WebView 装配

    private func mountSurface() {
        let content = WKUserContentController()
        if let js = dmqxo?.ocinah {
            content.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }
        content.add(self, name: Gtktns.vhys)

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = content
        cfg.allowsInlineMediaPlayback = true
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        web.uiDelegate = self
        web.navigationDelegate = self
        view.addSubview(web)
        surface = web

        if let entry = dmqxo?.ocmha, let url = URL(string: entry) {
            web.load(URLRequest(url: url))
        }
    }

    private func layoutSurface() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let bar = scene.statusBarManager else { return }

        let topInset = bar.statusBarFrame.height
        let bottomInset = view.safeAreaInsets.bottom
        surface?.frame = CGRect(
            x: 0,
            y: topInset,
            width: view.bounds.width,
            height: view.bounds.height - topInset - bottomInset
        )
    }

    override var shouldAutorotate: Bool { false }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}

// MARK: - 导航策略

extension ZmklqorViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// MARK: - 新窗口外跳

extension ZmklqorViewController: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let target = navigationAction.request.url {
            UIApplication.shared.open(target)
        }
        return nil
    }
}

// MARK: - 桥接消息入口

extension ZmklqorViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Gtktns.vhys,
              let payload = message.body as? [String: String],
              let mapping = dmqxo?.dterha else { return }
        tkzorp(payload, mapping)
    }
}
