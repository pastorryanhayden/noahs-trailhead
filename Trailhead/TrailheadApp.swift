import SwiftUI

enum TrailTheme {
    static let background = Color(red: 0.055, green: 0.09, blue: 0.13)
    static let panel = Color(red: 0.09, green: 0.14, blue: 0.19)
    static let mint = Color(red: 0.55, green: 0.88, blue: 0.72)
    static let gold = Color(red: 1, green: 0.75, blue: 0.40)
    static let muted = Color(red: 0.65, green: 0.72, blue: 0.78)
}

@main
struct TrailheadApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).preferredColorScheme(.dark)
                .tint(TrailTheme.mint)
                .alert("Saved progress", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) var scenePhase
    @State private var role: String?
    @State private var parentGate = false
    init() {
        #if DEBUG
        // Developer screenshots can open Noah's public profile; parent access
        // always goes through the PIN gate, including debug builds.
        _role = State(initialValue: ProcessInfo.processInfo.arguments.contains("--preview-noah") ? "Noah" : nil)
        #endif
    }
    var body: some View {
        Group {
            if role == "Noah" { NoahShell { role = nil } }
            else if role == "Parent" { ParentShell { role = nil } }
            else {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 30) {
                            Image(systemName: "mountain.2.fill").font(.system(size: 64)).foregroundStyle(TrailTheme.mint)
                            VStack(spacing: 12) {
                                Text("TRAILHEAD").font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(7).foregroundStyle(TrailTheme.mint)
                                Text("A little further.\nEvery day.").font(.system(size: 56, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                                Text("Build your skills. Build your camp. Find your next summit.").font(.title3).foregroundStyle(TrailTheme.muted)
                            }
                            ViewThatFits {
                                HStack(spacing: 20) { profiles }
                                VStack(spacing: 20) { profiles }
                            }.frame(maxWidth: 760)
                            Label("Your progress stays on this iPad. Ready wherever you are.", systemImage: "wifi.slash")
                                .font(.footnote).foregroundStyle(TrailTheme.muted)
                        }.padding(40).frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }.background(TrailTheme.background)
            }
        }
        .sheet(isPresented: $parentGate) { ParentGate { role = "Parent"; parentGate = false } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.save(); store.stopSpeaking()
                if role == "Parent" { role = nil }
            }
        }
    }
    private var profiles: some View {
        Group {
            Button { role = "Noah" } label: {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "figure.hiking").font(.largeTitle).foregroundStyle(TrailTheme.mint)
                    Text("Noah").font(.title.bold())
                    HStack { Text("Start your expedition"); Spacer(); Image(systemName: "arrow.up.right") }.foregroundStyle(TrailTheme.muted)
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading).background(TrailTheme.panel, in: RoundedRectangle(cornerRadius: 24))
            }.buttonStyle(.plain).accessibilityIdentifier("profile.noah")
            Button { parentGate = true } label: {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(TrailTheme.gold)
                    Text("Parent").font(.title.bold())
                    HStack { Text("Plan, review & encourage"); Spacer(); Image(systemName: "arrow.up.right") }.foregroundStyle(TrailTheme.muted)
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading).background(TrailTheme.panel, in: RoundedRectangle(cornerRadius: 24))
            }.buttonStyle(.plain).accessibilityIdentifier("profile.parent")
        }
    }
}

struct ParentGate: View {
    @Environment(\.dismiss) var dismiss
    let onUnlock: () -> Void
    @State private var pin = ""
    @State private var confirmation = ""
    @State private var message = ""
    @State private var failures = 0
    @State private var lockedUntil = Date.distantPast
    private let setup = !ParentPIN.configured
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "lock.shield").font(.system(size: 44)).foregroundStyle(TrailTheme.gold)
                Text(setup ? "Set up the parent profile" : "Welcome back").font(.largeTitle.bold())
                Text(setup ? "Choose a six-digit parent PIN. Keep it somewhere safe; there is no email recovery in this offline version." : "Enter your six-digit parent PIN.")
                    .foregroundStyle(TrailTheme.muted)
                SecureField("Six-digit PIN", text: $pin).keyboardType(.numberPad).textContentType(.password).textFieldStyle(.roundedBorder)
                    .onChange(of: pin) { _, value in pin = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6)) }
                if setup {
                    SecureField("Confirm PIN", text: $confirmation).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        .onChange(of: confirmation) { _, value in confirmation = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6)) }
                }
                if !message.isEmpty { Text(message).foregroundStyle(TrailTheme.gold) }
                ActionButton(title: setup ? "Create parent profile" : "Unlock", icon: "arrow.right") {
                    guard Date() >= lockedUntil else { message = "Please wait a minute before trying again."; return }
                    if setup {
                        guard pin == confirmation else { message = "The PINs do not match."; return }
                        if ParentPIN.set(pin) { onUnlock() } else { message = "The PIN could not be saved. Please try again." }
                    } else if ParentPIN.verify(pin) { onUnlock() }
                    else {
                        failures += 1; pin = ""; message = "That PIN did not match."
                        if failures >= 5 { lockedUntil = Date().addingTimeInterval(60); failures = 0; message = "Please wait a minute before trying again." }
                    }
                }.disabled(pin.count != 6 || (setup && confirmation.count != 6))
                Spacer()
            }.padding(36).frame(maxWidth: 540).frame(maxWidth: .infinity).background(TrailTheme.background)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.interactiveDismissDisabled(false)
    }
}

enum NoahPage: String, CaseIterable, Identifiable {
    case today = "Today", math = "Math", spelling = "Spelling", writing = "Handwriting", quiz = "Weekly checkpoint", camp = "Base camp"
    var id: String { rawValue }
    var icon: String { switch self { case .today: "sun.max"; case .math: "function"; case .spelling: "waveform"; case .writing: "pencil.tip.crop.circle"; case .quiz: "flag.checkered"; case .camp: "tent" } }
}

struct NoahShell: View {
    @EnvironmentObject var store: AppStore
    let signOut: () -> Void
    @State private var page = NoahPage.today
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    init(signOut: @escaping () -> Void) {
        self.signOut = signOut
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-screen=") }),
           let selected = NoahPage(rawValue: String(argument.dropFirst("--preview-screen=".count))) {
            _page = State(initialValue: selected)
        }
        #endif
    }
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 24) {
                Brand()
                Label("NOAH'S EXPEDITION", systemImage: "figure.hiking").font(.caption.bold()).foregroundStyle(TrailTheme.muted).padding(.horizontal, 20)
                ForEach(NoahPage.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 14) { Image(systemName: item.icon).frame(width: 22); Text(item.rawValue); Spacer() }
                            .font(.system(size: 16, weight: .semibold)).padding(16)
                            .foregroundStyle(page == item ? TrailTheme.mint : .white)
                            .background(page == item ? TrailTheme.mint.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).padding(.horizontal, 12).accessibilityIdentifier("nav.\(item.id)")
                }
                Spacer()
                HStack { Image(systemName: "sparkle").foregroundStyle(TrailTheme.gold); Text("\(store.data.xp) supplies").bold() }.padding(.horizontal, 24)
                Button("Switch profile", systemImage: "person.crop.circle.badge.arrow.trianglehead.counterclockwise") { signOut() }.padding(24).font(.footnote)
            }.padding(.top, 24).background(TrailTheme.background).navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 290)
        } detail: {
            Group {
                switch page {
                case .today: TodayView { page = $0 }
                case .math: MathPracticeView()
                case .spelling: SpellingPracticeView()
                case .writing: WritingPracticeView()
                case .quiz: QuizView()
                case .camp: CampView()
                }
            }.id(page).frame(maxWidth: .infinity, maxHeight: .infinity).background(TrailTheme.background)
        }.navigationSplitViewStyle(.balanced)
    }
}

struct Brand: View {
    var body: some View {
        HStack(spacing: 10) { Image(systemName: "mountain.2.fill").foregroundStyle(TrailTheme.mint); Text("TRAILHEAD").tracking(3).font(.system(size: 16, weight: .heavy)) }.padding(.horizontal, 24)
    }
}

struct PageHeader: View {
    var eyebrow: String
    var title: String
    var detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased()).font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(3).foregroundStyle(TrailTheme.mint)
            Text(title).font(.system(size: 36, weight: .bold, design: .rounded))
            Text(detail).font(.body).foregroundStyle(TrailTheme.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(TrailTheme.panel, in: RoundedRectangle(cornerRadius: 22)) }
}

struct ActionButton: View {
    var title: String
    var icon: String = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) { HStack(spacing: 12) { Text(title); Image(systemName: icon) }.font(.headline).padding(.horizontal, 22).padding(.vertical, 16).frame(minHeight: 52).foregroundStyle(TrailTheme.background).background(TrailTheme.mint, in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain)
    }
}

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    var navigate: (NoahPage) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(eyebrow: Date().formatted(.dateTime.weekday(.wide).month().day()), title: "Your next step, Noah.", detail: "Three small missions. A stronger foundation. Your expedition starts here.")
                Panel {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(store.data.settings.recoveryMode ? "RECOVERY MISSION" : "DAILY MISSION", systemImage: "location.north.circle").font(.caption.bold()).foregroundStyle(TrailTheme.mint)
                            Text("Make steady ground.").font(.title.bold())
                            Text("\(store.today.total / 60) of \(store.data.settings.recoveryMode ? 10 : store.data.settings.dailyMinutes) active minutes").foregroundStyle(TrailTheme.muted)
                            ProgressView(value: min(Double(store.today.total) / Double(store.data.settings.targetPerSubject * 3), 1)).tint(TrailTheme.mint)
                            Text(store.today.completionRewarded ? "Mission complete · 50 supplies earned" : "Complete all three practice targets to earn 50 supplies.").font(.footnote).foregroundStyle(TrailTheme.gold)
                        }
                        Spacer(minLength: 30)
                        Image(systemName: "mountain.2.fill").font(.system(size: 80)).foregroundStyle(TrailTheme.mint.opacity(0.65)).accessibilityHidden(true)
                    }
                }
                ForEach(Subject.allCases) { subject in
                    let seconds = store.today.seconds[subject.rawValue, default: 0]
                    Button { navigate(subject == .math ? .math : subject == .spelling ? .spelling : .writing) } label: {
                        Panel {
                            HStack(spacing: 22) {
                                Image(systemName: subject.icon).font(.title).foregroundStyle(subject == .spelling ? TrailTheme.gold : TrailTheme.mint).frame(width: 40)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(subject.title).font(.title3.bold())
                                    Text(subject == .math ? "Build your recall. Find your rhythm." : subject == .spelling ? "Listen. Learn the pattern. Make it stick." : "Clear letters. Steady lines. Words with meaning.").font(.subheadline).foregroundStyle(TrailTheme.muted)
                                }
                                Spacer()
                                Text("\(seconds / 60) / \(store.data.settings.targetPerSubject / 60) min").monospacedDigit().font(.subheadline.bold()).foregroundStyle(TrailTheme.mint)
                                Image(systemName: seconds >= store.data.settings.targetPerSubject ? "checkmark.circle.fill" : "arrow.right")
                            }
                        }
                    }.buttonStyle(.plain)
                }
                Button { navigate(.quiz) } label: {
                    HStack { Label("Weekly checkpoint", systemImage: "flag.checkered"); Spacer(); Text(store.currentQuiz?.submitted != nil ? "View results" : "Ready when you are"); Image(systemName: "arrow.right") }.font(.subheadline.bold()).foregroundStyle(TrailTheme.gold).padding(22).background(TrailTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
                Text("Weekday goal · Work in one session or come back between breaks. Progress is never lost for missing a day.").font(.footnote).foregroundStyle(TrailTheme.muted)
            }.padding(32).frame(maxWidth: 1100)
        }
    }
}

struct CampView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(eyebrow: "Your expedition", title: "Build your base camp.", detail: "Every practice round earns supplies. Choose what to build next.")
                Panel {
                    ZStack {
                        MountainLandscape().fill(LinearGradient(colors: [TrailTheme.mint.opacity(0.3), TrailTheme.background], startPoint: .top, endPoint: .bottom)).frame(height: 230)
                        VStack {
                            HStack { Spacer(); Label("\(store.data.xp) supplies", systemImage: "sparkle").font(.headline).foregroundStyle(TrailTheme.gold) }
                            Spacer()
                            HStack(spacing: 35) {
                                ForEach(Upgrade.all.filter { store.data.upgrades.contains($0.id) }) { item in
                                    VStack { Image(systemName: item.icon).font(.system(size: 42)); Text(item.title).font(.caption) }.foregroundStyle(TrailTheme.gold)
                                }
                            }
                            if store.data.upgrades.isEmpty { Text("Your first campsite is waiting.").foregroundStyle(TrailTheme.muted) }
                        }.padding(12)
                    }.frame(height: 240)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 18) {
                    ForEach(Upgrade.all) { item in
                        Panel {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(systemName: item.icon).font(.largeTitle).foregroundStyle(TrailTheme.gold)
                                Text(item.title).font(.title3.bold())
                                Text(item.detail).foregroundStyle(TrailTheme.muted)
                                ActionButton(title: store.data.upgrades.contains(item.id) ? "Built" : "Build · \(item.cost)", icon: "plus") { store.purchase(item) }
                                    .disabled(store.data.upgrades.contains(item.id) || store.data.xp < item.cost)
                                    .opacity(store.data.upgrades.contains(item.id) || store.data.xp < item.cost ? 0.5 : 1)
                            }
                        }
                    }
                }
            }.padding(32).frame(maxWidth: 1100)
        }
    }
}

struct MountainLandscape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLines([CGPoint(x: 0, y: rect.height * 0.7), CGPoint(x: rect.width * 0.23, y: rect.height * 0.15), CGPoint(x: rect.width * 0.42, y: rect.height * 0.6), CGPoint(x: rect.width * 0.65, y: 5), CGPoint(x: rect.width * 0.84, y: rect.height * 0.55), CGPoint(x: rect.width, y: rect.height * 0.35), CGPoint(x: rect.width, y: rect.height)])
        p.closeSubpath(); return p
    }
}
