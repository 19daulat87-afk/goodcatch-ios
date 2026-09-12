import Foundation
import SwiftUI
import WebKit
import PhotosUI
import UniformTypeIdentifiers

struct ReportSettings: Codable, Equatable {
    static let formURL = "https://app.smartsheet.com/b/form/9f3a83d49b464771be6352bb9b1ce8de"
    var values: [String: String] = [
        "name":"", "email":"", "site":"YYC4", "businessUnit":"AR", "businessLine":"RME",
        "date":"", "location":"Main Floor", "description":"5S compromised",
        "outcome":"Fall or slip/trip on same level", "stopWork":"No",
        "actionResult":"FIXED ON THE SPOT - HAZARD COMPLETELY ABATED",
        "immediateAction":"Fixed", "likelihood":"1", "severity":"1"]
    var receipt = true
    var url = formURL
    var theme = "Metallic Blue"
    static let fields: [(String, String)] = [
        ("name","Your name (optional)"), ("email","Your email"), ("site","Site"),
        ("businessUnit","Business unit"), ("businessLine","JLL business line"),
        ("date","Date: MM/DD/YYYY (blank = today)"), ("location","Location"),
        ("description","Description of hazardous situation"), ("outcome","Potential outcome"),
        ("stopWork","Stop Work: Yes or No"), ("actionResult","Immediate Action Result"),
        ("immediateAction","Immediate Action"), ("likelihood","Likelihood: 1–4"), ("severity","Severity: 1–4")]
}
struct SavedState: Codable {
    var settings = ReportSettings()
    var photos: [String] = []
    var index = 0
}

@MainActor final class ReportModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var state = SavedState()
    @Published var status = "Open Settings to enter your own details. CAPTCHA and Submit remain manual."
    @Published var busy = false
    @Published var expanded = false
    @Published var showSettings = false
    @Published var attachPrompt = false
    @Published var thumbnail: UIImage?
    let web: WKWebView
    private let folder: URL
    private var operation: Task<Void, Never>?
    private var generation = 0
    private var attached: String?
    var current: String? { state.photos.indices.contains(state.index) ? state.photos[state.index] : nil }
    var counter: String { state.photos.isEmpty ? "Select your photos" : current == nil ? "Queue complete" : "\(state.index + 1) / \(state.photos.count)" }
    var accent: Color {
        switch state.settings.theme { case "Carbon": return .gray; case "Purple Night": return .purple; case "Forest": return .green; default: return .cyan }
    }
    override init() {
        folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GoodCatch", isDirectory:true)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var directory = folder
            var attributes = URLResourceValues(); attributes.isExcludedFromBackup = true
            try directory.setResourceValues(attributes)
            if let data = try? Data(contentsOf: folder.appendingPathComponent("state.json")) {
                state = try JSONDecoder().decode(SavedState.self, from:data)
                state.photos = state.photos.filter { $0 == URL(fileURLWithPath:$0).lastPathComponent }
                state.index = min(max(state.index,0), state.photos.count)
            }
        } catch { status = "Saved queue could not be restored. \(error.localizedDescription)" }
        web.navigationDelegate = self
        web.isOpaque = false
        refreshThumbnail()
        reload()
    }
    static func trusted(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && ["app.smartsheet.com","forms.smartsheet.com"].contains(url.host?.lowercased() ?? "")
    }
    func save() {
        do { try JSONEncoder().encode(state).write(to:folder.appendingPathComponent("state.json"), options:[.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        catch { status = "Could not save settings: \(error.localizedDescription)" }
    }
    func saveSettings(_ settings: ReportSettings) {
        let changed = state.settings.url != settings.url
        state.settings = settings; save()
        if changed { reload() }
    }
    func location(_ text: String) { guard !busy else { return }; state.settings.values["location"] = text; save() }
    func refreshThumbnail() {
        thumbnail = current.flatMap { UIImage(contentsOfFile:folder.appendingPathComponent($0).path) }
    }
    func reload() {
        guard let url = URL(string:state.settings.url), Self.trusted(url) else { status = "Use an HTTPS Smartsheet form URL in Settings."; return }
        operation?.cancel(); busy = false; attached = nil; web.load(URLRequest(url:url))
    }
    func next() {
        guard !busy, current != nil else { return }
        state.index += 1; save(); refreshThumbnail(); reload()
        status = current == nil ? "Queue complete." : "Ready for the next report."
    }
    func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !busy, !items.isEmpty else { return }
        busy = true; status = "Preparing selected photos…"
        var imported: [String] = []
        var failures = 0
        for item in items {
            do {
                guard let bytes = try await item.loadTransferable(type:Data.self), bytes.count <= 20 * 1024 * 1024,
                      let image = UIImage(data:bytes), let jpeg = image.jpegData(compressionQuality:0.9), jpeg.count <= 20 * 1024 * 1024 else { failures += 1; continue }
                let name = "report-\(UUID().uuidString).jpg"
                try jpeg.write(to:folder.appendingPathComponent(name), options:[.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                imported.append(name)
            } catch { failures += 1 }
        }
        busy = false
        guard !imported.isEmpty else { status = "No photos imported. Choose readable images under 20 MB."; return }
        let oldPhotos = state.photos
        state.photos = imported; state.index = 0; save(); refreshThumbnail(); reload()
        for name in oldPhotos { try? FileManager.default.removeItem(at:folder.appendingPathComponent(name)) }
        status = "\(imported.count) photos ready.\(failures > 0 ? " \(failures) could not be imported." : "")"
    }
    private func resource(_ name: String) throws -> String {
        guard let url = Bundle.main.url(forResource:name, withExtension:"js") else { throw CocoaError(.fileNoSuchFile) }
        return try String(contentsOf:url, encoding:.utf8)
    }
    private func json(_ object: Any) throws -> String {
        String(data:try JSONSerialization.data(withJSONObject:object, options:[.fragmentsAllowed]), encoding:.utf8)!
    }
    func fill() {
        guard !busy, current != nil else { status = "Select pictures first."; return }
        guard Self.trusted(web.url) else { status = "Load the Smartsheet form first."; return }
        if state.settings.receipt && (state.settings.values["email"] ?? "").isEmpty {
            status = "Enter your email in Settings or turn off response copies."; showSettings = true; return
        }
        busy = true; status = "Filling report details…"
        let token = generation
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                var config: [String:Any] = self.state.settings.values
                config["receipt"] = self.state.settings.receipt
                let script = try self.resource("fill")
                _ = try await self.web.evaluateJavaScript("window.yycConfig=\(try self.json(config));\n\(script)")
                for _ in 0..<150 {
                    try await Task.sleep(nanoseconds:500_000_000)
                    guard self.generation == token else { return }
                    let result = try await self.web.evaluateJavaScript("window.yycResult || ''") as? String ?? ""
                    if !result.isEmpty {
                        self.busy = false; self.status = result
                        if result.contains("READY") { self.attachPrompt = true }
                        return
                    }
                }
                self.busy = false; self.status = "Fill timed out. Review the form manually."
            } catch { if self.generation == token { self.busy = false; self.status = "Fill interrupted. Review the form manually." } }
        }
    }
    func attachPhoto() {
        guard !busy, let name = current, Self.trusted(web.url) else { return }
        busy = true; status = "Adding the current photo…"
        let token = generation
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                let bytes = try Data(contentsOf:self.folder.appendingPathComponent(name))
                guard !bytes.isEmpty, bytes.count <= 20 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
                _ = try await self.web.evaluateJavaScript(try self.resource("attachment"))
                let ready = try await self.web.evaluateJavaScript("window.yycAttachment.begin()") as? Bool ?? false
                guard ready else { throw CocoaError(.fileNoSuchFile) }
                for offset in stride(from:0, to:bytes.count, by:24576) {
                    try Task.checkCancellation()
                    guard self.generation == token else { return }
                    let chunk = bytes.subdata(in:offset..<min(offset+24576,bytes.count)).base64EncodedString()
                    _ = try await self.web.evaluateJavaScript("window.yycAttachment.chunk('\(chunk)')")
                }
                guard self.generation == token else { return }
                let metadata = try self.json(["name":name,"type":"image/jpeg"])
                let ok = try await self.web.evaluateJavaScript("window.yycAttachment.finish(\(metadata))") as? Bool ?? false
                self.busy = false
                if ok { self.attached = name; self.status = "Photo added: \(name). Wait for Smartsheet to finish uploading before Submit." }
                else { self.status = "Photo was not attached. Use Browse in the form and choose the photo manually." }
            } catch { if self.generation == token { self.busy = false; self.status = "Attachment failed. Use Browse in the form to choose the photo manually." } }
        }
    }
    var attachMessage: String {
        attached == current && current != nil ? "This photo was already sent to the form. Retry only if the attachment is missing or failed." : "Add the current queued photo to this report?"
    }
    func goToSubmit() {
        guard !busy, Self.trusted(web.url) else { return }
        expanded = true
        web.evaluateJavaScript("""
        (()=>{const b=[...document.querySelectorAll('button,input[type=submit]')].find(e=>(e.textContent||e.value||'').trim().toLowerCase()==='submit');if(!b)return false;b.scrollIntoView({block:'center'});return true;})()
        """) { [weak self] value, _ in
            self?.status = (value as? Bool == true) ? "Review the report and any verification, then tap Smartsheet’s Submit." : "Submit is not available yet. Wait for the form to load."
        }
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        generation += 1; operation?.cancel(); busy = false; attached = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { status = "Page could not load. Check your connection and tap Reload." }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Leave embedded frames, including verification, to WebKit.
        if let frame = navigationAction.targetFrame, !frame.isMainFrame { decisionHandler(.allow); return }
        if Self.trusted(navigationAction.request.url) { decisionHandler(.allow); return }
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url, ["https","http"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }
}
