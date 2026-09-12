import SwiftUI
import PhotosUI
import WebKit

@main struct GoodCatchApp: App {
    @StateObject private var model = ReportModel()
    var body: some Scene { WindowGroup { MainView(model:model).preferredColorScheme(.dark) } }
}
struct WebForm: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context:Context) -> WKWebView { web }
    func updateUIView(_ uiView:WKWebView, context:Context) {}
}
struct MainView: View {
    @ObservedObject var model: ReportModel
    @State private var selection: [PhotosPickerItem] = []
    @State private var pending: [PhotosPickerItem] = []
    @State private var replacePrompt = false
    @State private var nextPrompt = false
    var body: some View {
        VStack(spacing:10) {
            HStack {
                VStack(alignment:.leading, spacing:4) {
                    Text("GOOD CATCH").font(.headline).tracking(2)
                    Text("FIELD REPORTS • iPHONE 2.7").font(.caption2).foregroundColor(model.accent)
                }
                Spacer()
                Button("Settings") { model.showSettings = true }.disabled(model.busy)
            }
            if !model.expanded {
                HStack(spacing:14) {
                    Group {
                        if let image = model.thumbnail { Image(uiImage:image).resizable().scaledToFill() }
                        else { Image(systemName:"photo.on.rectangle.angled").font(.largeTitle).foregroundColor(model.accent) }
                    }.frame(width:72,height:72).clipped().cornerRadius(12)
                    VStack(alignment:.leading, spacing:6) {
                        Text(model.counter).font(.headline)
                        Text(model.state.settings.values["location"] ?? "").font(.caption).foregroundColor(.secondary)
                        PhotosPicker(selection:$selection, maxSelectionCount:50, matching:.images) { Label("Select photos",systemImage:"plus") }.disabled(model.busy)
                    }
                    Spacer()
                }.padding(12).background(.white.opacity(0.06)).cornerRadius(14)
                HStack {
                    ForEach(["Main Floor","RSP2","RSP3","RSP4"], id:\.self) { location in
                        Button(location) { model.location(location) }.font(.caption).frame(maxWidth:.infinity)
                            .foregroundColor(model.state.settings.values["location"] == location ? model.accent : .white)
                    }
                }.disabled(model.busy)
            }
            HStack(spacing:6) {
                action("Fill Current", "square.and.pencil") { model.fill() }
                action("Attach Photo", "paperclip") { model.attachPrompt = true }
                action("Next Report", "arrow.right") { nextPrompt = true }
            }.disabled(model.busy)
            HStack {
                Button("Go to Submit") { model.goToSubmit() }.disabled(model.busy)
                Spacer()
                Button(model.expanded ? "Show photos" : "Expand") { model.expanded.toggle() }
            }.font(.caption)
            HStack(alignment:.top) {
                if model.busy { ProgressView().scaleEffect(0.75) }
                Text(model.status).font(.caption2).foregroundColor(.secondary).frame(maxWidth:.infinity,alignment:.leading)
            }.fixedSize(horizontal:false, vertical:true)
            WebForm(web:model.web).clipShape(RoundedRectangle(cornerRadius:10))
        }
        .padding(12).background(LinearGradient(colors:[Color(red:0.12,green:0.18,blue:0.23),.black], startPoint:.topLeading,endPoint:.bottomTrailing))
        .tint(model.accent)
        .sheet(isPresented:$model.showSettings) { SettingsView(model:model, draft:model.state.settings) }
        .onChange(of:selection) { items in
            guard !items.isEmpty else { return }
            if !model.state.photos.isEmpty { pending = items; replacePrompt = true }
            else { Task { await model.importPhotos(items); selection = [] } }
        }
        .alert("Replace photo queue?",isPresented:$replacePrompt) {
            Button("Replace",role:.destructive) { let items = pending; pending = []; selection = []; Task { await model.importPhotos(items) } }
            Button("Cancel",role:.cancel) { pending = []; selection = [] }
        } message: { Text("The current form will reload. Unsubmitted edits will be lost.") }
        .alert("Attach current photo?",isPresented:$model.attachPrompt) {
            Button("Attach") { model.attachPhoto() }; Button("Cancel",role:.cancel) {}
        } message: { Text(model.attachMessage) }
        .alert("Move to next report?",isPresented:$nextPrompt) {
            Button("Continue") { model.next() }; Button("Stay here",role:.cancel) {}
        } message: { Text("Continue after Smartsheet shows success, or to intentionally skip this photo. Unsubmitted edits will be lost.") }
    }
    private func action(_ title:String,_ symbol:String, run:@escaping ()->Void) -> some View {
        Button(action:run) { VStack(spacing:5) { Image(systemName:symbol); Text(title).font(.caption2) }.frame(maxWidth:.infinity).padding(.vertical,10) }
            .background(.white.opacity(0.08)).cornerRadius(10)
    }
}
struct SettingsView: View {
    @ObservedObject var model: ReportModel
    @State var draft: ReportSettings
    @State private var validation = ""
    @State private var reloadPrompt = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter your own details. Review the defaults for every report. Dropdown values must match the choices in the form.").font(.caption)
                    ForEach(ReportSettings.fields,id:\.0) { key,title in
                        VStack(alignment:.leading) {
                            Text(title).font(.caption).foregroundColor(.secondary)
                            TextField(title,text:Binding(get:{draft.values[key] ?? ""},set:{draft.values[key] = $0}),axis:.vertical)
                                .textInputAutocapitalization(key == "email" ? .never : .sentences)
                                .autocorrectionDisabled(key == "email")
                        }
                    }
                } header: { Text("Report details") }
                Section {
                    Toggle("Send me a copy of my responses",isOn:$draft.receipt)
                    Text("Copies use your report email above. Photos come from the current queue.").font(.caption)
                }
                Section("Appearance") {
                    Picker("Accent",selection:$draft.theme) { ForEach(["Metallic Blue","Carbon","Purple Night","Forest"],id:\.self) { Text($0) } }
                }
                Section("Form") {
                    TextField("Smartsheet URL",text:$draft.url).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Requires the supported Good Catch form layout. Changing the URL reloads the current form.").font(.caption)
                    Button("Reload current form") { reloadPrompt = true }
                }
                if !validation.isEmpty { Text(validation).foregroundColor(.red) }
            }.navigationTitle("Report settings")
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement:.confirmationAction) { Button("Save") { save() } }
                }
                .alert("Reload current form?",isPresented:$reloadPrompt) {
                    Button("Reload",role:.destructive) { model.reload(); dismiss() }
                    Button("Cancel",role:.cancel) {}
                } message: { Text("Unsaved form changes will be lost. Settings edits will not be saved.") }
        }.preferredColorScheme(.dark)
    }
    private func save() {
        draft.url = draft.url.trimmingCharacters(in:.whitespacesAndNewlines)
        draft.values = draft.values.mapValues { $0.trimmingCharacters(in:.whitespacesAndNewlines) }
        guard ReportModel.trusted(URL(string:draft.url)) else { validation = "Use an HTTPS Smartsheet URL."; return }
        if draft.receipt && (draft.values["email"] ?? "").isEmpty { validation = "Enter your email or turn response copies off."; return }
        for key in ["likelihood","severity"] {
            guard ["1","2","3","4"].contains(draft.values[key] ?? "") else { validation = "Likelihood and severity must be between 1 and 4."; return }
        }
        model.saveSettings(draft); dismiss()
    }
}
