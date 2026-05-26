import SwiftUI
import UIKit
import Combine
import PhotosUI
import AVFoundation
import AudioToolbox

struct AvatarPreset: Identifiable, Equatable {
    let id: String
    let title: String
    let fallbackSymbol: String

    static let all: [AvatarPreset] = [
        AvatarPreset(id: "profile_avatar_ice_tracker", title: "Ice", fallbackSymbol: "cube.transparent"),
        AvatarPreset(id: "profile_avatar_arctic_fish", title: "Bass", fallbackSymbol: "fish"),
        AvatarPreset(id: "profile_avatar_frozen_slot", title: "Slots", fallbackSymbol: "rectangle.portrait.on.rectangle.portrait"),
        AvatarPreset(id: "profile_avatar_snow_bonus", title: "Bonus", fallbackSymbol: "snowflake")
    ]

    static func fallback(for id: String) -> String {
        all.first(where: { $0.id == id })?.fallbackSymbol ?? "person.crop.circle"
    }
}

enum SlotUniverse: String, Codable, CaseIterable, Identifiable {
    case joker
    case bigBass
    case bonanza

    var id: String { rawValue }

    var title: String {
        switch self {
        case .joker: "Joker Slots"
        case .bigBass: "Big Bass Slots"
        case .bonanza: "Bonanza Slots"
        }
    }

    var shortTitle: String {
        switch self {
        case .joker: "Joker"
        case .bigBass: "Big Bass"
        case .bonanza: "Bonanza"
        }
    }

    var symbol: String {
        switch self {
        case .joker: "rectangle.portrait.on.rectangle.portrait"
        case .bigBass: "fish"
        case .bonanza: "circle.hexagongrid.circle"
        }
    }

    var assetName: String {
        switch self {
        case .joker: "universe_joker_slots"
        case .bigBass: "universe_big_bass_slots"
        case .bonanza: "universe_bonanza_slots"
        }
    }

    var backgroundAssetName: String {
        switch self {
        case .joker: "background_joker_slots"
        case .bigBass: "background_big_bass_slots"
        case .bonanza: "background_bonanza_slots"
        }
    }

    var primary: Color {
        switch self {
        case .joker: Color(red: 1.0, green: 0.08, blue: 0.22)
        case .bigBass: Color(red: 0.02, green: 0.84, blue: 0.94)
        case .bonanza: Color(red: 1.0, green: 0.42, blue: 0.78)
        }
    }

    var secondary: Color {
        switch self {
        case .joker: Color(red: 1.0, green: 0.72, blue: 0.1)
        case .bigBass: Color(red: 0.0, green: 1.0, blue: 0.78)
        case .bonanza: Color(red: 1.0, green: 0.87, blue: 0.22)
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case lobby = "Lobby"
    case live = "Live"
    case history = "History"
    case insights = "Insights"
    case rules = "Rules"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .lobby: "house"
        case .live: "waveform.path.ecg"
        case .history: "clock.arrow.circlepath"
        case .insights: "chart.bar"
        case .rules: "shield"
        }
    }
}

enum GraphicMode {
    case cover
    case contain
    case fill
}

struct SessionRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let universe: SlotUniverse
    let startedAt: Date
    let durationSeconds: Int
    let startingBalance: Int
    let endingBalance: Int
    let takeProfit: Int
    let stopLoss: Int
    let peakProfit: Int
    let biggestDrop: Int
    let progression: [BalancePoint]
    var note: String
    let closedByLimit: Bool

    var profit: Int { endingBalance - startingBalance }
    var roi: Double { startingBalance == 0 ? 0 : Double(profit) / Double(startingBalance) }
    var resultText: String {
        if profit > 0 { return "+$\(profit)" }
        if profit < 0 { return "-$\(abs(profit))" }
        return "$0"
    }
}

struct BalancePoint: Identifiable, Codable, Equatable {
    let id: UUID
    let second: Int
    let balance: Int

    init(id: UUID = UUID(), second: Int, balance: Int) {
        self.id = id
        self.second = second
        self.balance = balance
    }
}

struct SessionSetup: Codable, Equatable {
    var universe: SlotUniverse = .bigBass
    var startingBalance: Double = 100
    var takeProfit: Double = 200
    var stopLoss: Double = 50
    var timerMinutes: Double = 30

    var validationMessage: String? {
        guard startingBalance >= 10 else { return "Starting balance must be at least $10." }
        guard takeProfit > startingBalance else { return "Take profit should be greater than your starting balance." }
        guard stopLoss > 0, stopLoss <= startingBalance else { return "Stop loss must be between $1 and your starting balance." }
        guard timerMinutes >= 10 else { return "Session timer must be at least 10 minutes." }
        return nil
    }
}

struct PlayerProfile: Codable, Equatable {
    var name: String = "Ice Tracker Pro"
    var avatarAssetName: String = "profile_avatar_ice_tracker"
    var preferredUniverse: SlotUniverse = .bigBass
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var notificationsEnabled: Bool = true
    var autoStopLossEnabled: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Ice Tracker Pro"
        avatarAssetName = try container.decodeIfPresent(String.self, forKey: .avatarAssetName) ?? "profile_avatar_ice_tracker"
        preferredUniverse = try container.decodeIfPresent(SlotUniverse.self, forKey: .preferredUniverse) ?? .bigBass
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        autoStopLossEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoStopLossEnabled) ?? false
    }
}

struct StoredAppState: Codable {
    var didFinishOnboarding = false
    var profile = PlayerProfile()
    var setup = SessionSetup()
    var sessions: [SessionRecord] = []
    var activeSession: LiveSession?
}

final class AppStateStore {
    private let fileURL: URL
    private let avatarURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let appDirectory = directory.appendingPathComponent("SlotsHubHelper", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        fileURL = appDirectory.appendingPathComponent("app_state.json")
        avatarURL = appDirectory.appendingPathComponent("profile_avatar.jpg")
    }

    func load() async -> StoredAppState {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder.appDecoder.decode(StoredAppState.self, from: data)
        } catch {
            return StoredAppState()
        }
    }

    func save(_ state: StoredAppState) async throws {
        let data = try JSONEncoder.prettyAppEncoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    func loadAvatarImage() async -> Data? {
        try? Data(contentsOf: avatarURL)
    }

    func saveAvatarImage(_ data: Data) async throws {
        try data.write(to: avatarURL, options: [.atomic])
    }

    func deleteAvatarImage() async throws {
        if FileManager.default.fileExists(atPath: avatarURL.path) {
            try FileManager.default.removeItem(at: avatarURL)
        }
    }
}

extension JSONEncoder {
    static var prettyAppEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var appDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var didLoad = false
    @Published var didFinishOnboarding = false
    @Published var selectedTab: AppTab = .lobby
    @Published var profile = PlayerProfile()
    @Published var setup = SessionSetup()
    @Published var sessions: [SessionRecord] = []
    @Published var activeSession: LiveSession?
    @Published var avatarImageData: Data?
    @Published var bannerMessage: String?
    @Published var validationMessage: String?

    private let store = AppStateStore()
    private var audioPlayer: AVAudioPlayer?

    func load() {
        guard !didLoad else { return }
        Task {
            let state = await store.load()
            didFinishOnboarding = state.didFinishOnboarding
            profile = state.profile
            setup = state.setup
            sessions = state.sessions.sorted { $0.startedAt > $1.startedAt }
            activeSession = state.activeSession
            avatarImageData = await store.loadAvatarImage()
            didLoad = true
        }
    }

    func finishOnboarding() {
        didFinishOnboarding = true
        persist()
    }

    func updateProfileName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name = trimmed.isEmpty ? "Ice Tracker Pro" : trimmed
        persist()
    }

    func updateAvatar(_ assetName: String) {
        guard AvatarPreset.all.contains(where: { $0.id == assetName }) else { return }
        profile.avatarAssetName = assetName
        persist()
    }

    func updateAvatarImage(_ data: Data) {
        avatarImageData = data
        Task {
            do {
                try await store.saveAvatarImage(data)
            } catch {
                bannerMessage = "Could not save profile image. Try another photo."
            }
        }
    }

    func updateSoundEnabled(_ isEnabled: Bool) {
        profile.soundEnabled = isEnabled
        persist()
    }

    func updateHapticsEnabled(_ isEnabled: Bool) {
        profile.hapticsEnabled = isEnabled
        persist()
    }

    func updateNotificationsEnabled(_ isEnabled: Bool) {
        profile.notificationsEnabled = isEnabled
        persist()
    }

    func updateAutoStopLossEnabled(_ isEnabled: Bool) {
        profile.autoStopLossEnabled = isEnabled
        persist()
    }

    func selectUniverse(_ universe: SlotUniverse) {
        setup.universe = universe
        profile.preferredUniverse = universe
        persist()
    }

    func startSession() {
        if let message = setup.validationMessage {
            validationMessage = message
            return
        }

        validationMessage = nil
        profile.preferredUniverse = setup.universe
        activeSession = LiveSession(setup: setup)
        selectedTab = .live
        persist()
    }

    func applyBalanceDelta(_ delta: Int) {
        guard var session = activeSession else { return }
        let previousLimitState = session.limitState
        session.apply(delta: delta)
        activeSession = session
        let currentLimitState = session.limitState

        if currentLimitState != .clear && previousLimitState == .clear {
            playLimitFeedback(currentLimitState)
        }

        if profile.autoStopLossEnabled && currentLimitState == .stopLoss {
            finishActiveSession(reason: .limit)
        } else if currentLimitState == .takeProfit {
            if profile.notificationsEnabled {
                bannerMessage = "Take-Profit reached. Cash out to lock the result."
            }
        } else if currentLimitState == .stopLoss {
            if profile.notificationsEnabled {
                bannerMessage = "Stop-loss reached. It is time to finish the session."
            }
            persist()
        } else {
            persist()
        }
    }

    func tickLiveSession() {
        guard var session = activeSession else { return }
        session.tick()
        activeSession = session

        if session.remainingSeconds == 0 {
            finishActiveSession(reason: .timer)
        } else {
            persist()
        }
    }

    func finishActiveSession(reason: FinishReason) {
        guard let session = activeSession else { return }
        let record = session.makeRecord(closedByLimit: reason != .manual && session.limitState != .clear)
        sessions.insert(record, at: 0)
        activeSession = nil
        selectedTab = .history
        bannerMessage = reason == .limit && !profile.notificationsEnabled ? nil : reason.message(for: record)
        persist()
    }

    func deleteSessions(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        persist()
    }

    func updateNote(for record: SessionRecord, note: String) {
        guard let index = sessions.firstIndex(where: { $0.id == record.id }) else { return }
        sessions[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func saveCurrentState() {
        persist()
    }

    func resetLocalProfile() {
        profile = PlayerProfile()
        setup = SessionSetup()
        sessions = []
        activeSession = nil
        avatarImageData = nil
        selectedTab = .lobby
        persist()
        Task {
            try? await store.deleteAvatarImage()
        }
    }

    private func persist() {
        let state = StoredAppState(
            didFinishOnboarding: didFinishOnboarding,
            profile: profile,
            setup: setup,
            sessions: sessions,
            activeSession: activeSession
        )
        Task {
            do {
                try await store.save(state)
            } catch {
                bannerMessage = "Could not save local data. Your latest change may not persist."
            }
        }
    }

    private func playLimitFeedback(_ state: LimitState) {
        if profile.hapticsEnabled {
            let feedback: UINotificationFeedbackGenerator.FeedbackType = state == .takeProfit ? .success : .warning
            UINotificationFeedbackGenerator().notificationOccurred(feedback)
        }

        guard profile.soundEnabled else { return }
        switch state {
        case .takeProfit:
            playSound(named: "limit_take_profit", fallback: 1057)
        case .stopLoss:
            playSound(named: "limit_stop_loss", fallback: 1053)
        case .clear:
            break
        }
    }

    private func playSound(named name: String, fallback: SystemSoundID) {
        let extensions = ["wav", "mp3", "m4a", "caf"]
        if let url = extensions.compactMap({ Bundle.main.url(forResource: name, withExtension: $0) }).first {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                AudioServicesPlaySystemSound(fallback)
            }
        } else {
            AudioServicesPlaySystemSound(fallback)
        }
    }
}

enum FinishReason {
    case manual
    case timer
    case limit

    func message(for record: SessionRecord) -> String {
        switch self {
        case .manual: "Session saved: \(record.resultText)."
        case .timer: "Timer ended. Session saved: \(record.resultText)."
        case .limit: "Limit handled. Session saved: \(record.resultText)."
        }
    }
}

enum LimitState {
    case clear
    case takeProfit
    case stopLoss
}

struct LiveSession: Codable, Equatable {
    let id: UUID
    let universe: SlotUniverse
    let startedAt: Date
    let startingBalance: Int
    let takeProfit: Int
    let stopLoss: Int
    let totalSeconds: Int
    var remainingSeconds: Int
    var currentBalance: Int
    var peakProfit: Int
    var biggestDrop: Int
    var progression: [BalancePoint]

    init(setup: SessionSetup) {
        id = UUID()
        universe = setup.universe
        startedAt = Date()
        startingBalance = Int(setup.startingBalance.rounded())
        takeProfit = Int(setup.takeProfit.rounded())
        stopLoss = Int(setup.stopLoss.rounded())
        totalSeconds = Int(setup.timerMinutes.rounded()) * 60
        remainingSeconds = totalSeconds
        currentBalance = startingBalance
        peakProfit = 0
        biggestDrop = 0
        progression = [BalancePoint(second: 0, balance: Int(setup.startingBalance.rounded()))]
    }

    var elapsedSeconds: Int { max(0, totalSeconds - remainingSeconds) }
    var profit: Int { currentBalance - startingBalance }
    var roi: Double { startingBalance == 0 ? 0 : Double(profit) / Double(startingBalance) }
    var didHitTakeProfit: Bool { currentBalance >= takeProfit }
    var didHitStopLoss: Bool { currentBalance <= startingBalance - stopLoss }
    var limitState: LimitState {
        if didHitTakeProfit { return .takeProfit }
        if didHitStopLoss { return .stopLoss }
        return .clear
    }

    mutating func apply(delta: Int) {
        currentBalance = max(0, currentBalance + delta)
        peakProfit = max(peakProfit, currentBalance - startingBalance)
        biggestDrop = min(biggestDrop, currentBalance - startingBalance)
        progression.append(BalancePoint(second: elapsedSeconds, balance: currentBalance))
    }

    mutating func tick() {
        remainingSeconds = max(0, remainingSeconds - 1)
    }

    func makeRecord(closedByLimit: Bool) -> SessionRecord {
        SessionRecord(
            id: id,
            universe: universe,
            startedAt: startedAt,
            durationSeconds: elapsedSeconds,
            startingBalance: startingBalance,
            endingBalance: currentBalance,
            takeProfit: takeProfit,
            stopLoss: stopLoss,
            peakProfit: peakProfit,
            biggestDrop: biggestDrop,
            progression: progression,
            note: "",
            closedByLimit: closedByLimit
        )
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !viewModel.didLoad {
                LoadingView()
            } else if !viewModel.didFinishOnboarding {
                OnboardingView {
                    viewModel.finishOnboarding()
                }
            } else {
                MainShellView()
                    .environmentObject(viewModel)
            }
        }
        .task {
            viewModel.load()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                viewModel.saveCurrentState()
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            ThemedBackground(universe: .bigBass, assetName: SlotUniverse.bigBass.backgroundAssetName)
            ProgressView("Loading your hub...")
                .tint(.cyan)
                .foregroundStyle(.white)
        }
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            title: "Track Every Spin Through The Ice",
            subtitle: "Manage sessions. Control bankroll. Stay disciplined.",
            symbol: "snowflake",
            button: "Enter The Hub"
        ),
        OnboardingPage(
            title: "Choose Your Session",
            subtitle: "Adapt your tracking experience to your playstyle.",
            symbol: "square.grid.3x1.folder.badge.plus",
            button: "Continue"
        ),
        OnboardingPage(
            title: "Control Your Limits",
            subtitle: "Discipline survives the cold.",
            symbol: "shield.lefthalf.filled",
            button: "Next"
        ),
        OnboardingPage(
            title: "Track Like A Pro",
            subtitle: "Session tracking • Smart alerts • Tilt detection • History archive • Insights",
            symbol: "chart.bar.xaxis",
            button: "Start Tracking"
        )
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemedBackground(universe: .bigBass, assetName: SlotUniverse.bigBass.backgroundAssetName)
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    onboardingPage(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button("Skip", action: onFinish)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white.opacity(0.12), in: Capsule())
                .padding(.top, 58)
                .padding(.trailing, 24)
                .accessibilityLabel("Skip onboarding")
        }
    }

    private func onboardingPage(_ item: OnboardingPage) -> some View {
        VStack(spacing: 30) {
            Spacer(minLength: 70)

            Image(systemName: item.symbol)
                .font(.system(size: 86, weight: .bold))
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 34)

            Spacer()

            VStack(spacing: 16) {
                Text(item.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)

                Text(item.subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            .padding(.horizontal, 22)

            Button {
                if page == pages.count - 1 {
                    onFinish()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        page += 1
                    }
                }
            } label: {
                Text(item.button)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .accessibilityLabel(item.button)

            PageDots(count: pages.count, page: page)
            Spacer(minLength: 110)
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let symbol: String
    let button: String
}

struct PageDots: View {
    let count: Int
    let page: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.cyan : Color.white.opacity(0.22))
                    .frame(width: index == page ? 32 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(count)")
    }
}

struct MainShellView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            TabContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(selectedTab: $viewModel.selectedTab, hasLiveSession: viewModel.activeSession != nil)
        }
        .background(Color(red: 0.02, green: 0.06, blue: 0.14))
        .alert("Slots Hub", isPresented: Binding(
            get: { viewModel.bannerMessage != nil },
            set: { if !$0 { viewModel.bannerMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.bannerMessage = nil }
        } message: {
            Text(viewModel.bannerMessage ?? "")
        }
    }
}

struct TabContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        switch viewModel.selectedTab {
        case .lobby:
            LobbyView()
        case .live:
            LiveSessionView()
        case .history:
            HistoryView()
        case .insights:
            InsightsView()
        case .rules:
            RulesView()
        }
    }
}

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    let hasLiveSession: Bool

    var body: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(selectedTab == tab ? .cyan : .white.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(Rectangle())
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.cyan.opacity(0.18))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if tab == .live && hasLiveSession {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .offset(x: -18, y: 8)
                        }
                    }
                }
                .accessibilityLabel(tab.rawValue)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial.opacity(0.88))
        .background(Color(red: 0.02, green: 0.06, blue: 0.14).opacity(0.86))
    }
}

struct LobbyView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(universe: viewModel.setup.universe, assetName: viewModel.setup.universe.backgroundAssetName)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        universePicker
                        setupCard
                        startButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 72)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .alert("Check your limits", isPresented: Binding(
                get: { viewModel.validationMessage != nil },
                set: { if !$0 { viewModel.validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.validationMessage = nil }
            } message: {
                Text(viewModel.validationMessage ?? "")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome Back")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Ready to track?")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Button {
                showProfile = true
            } label: {
                ProfileAvatarView(
                    imageData: viewModel.avatarImageData,
                    assetName: viewModel.profile.avatarAssetName,
                    fallbackSymbol: AvatarPreset.fallback(for: viewModel.profile.avatarAssetName)
                )
                .frame(width: 48, height: 48)
                .background(Color.cyan, in: Circle())
                .overlay(Circle().stroke(.cyan.opacity(0.55), lineWidth: 1))
                .shadow(color: .cyan.opacity(0.30), radius: 14, y: 5)
            }
            .accessibilityLabel("Open player profile")
        }
    }

    private var universePicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Select Session Type")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(SlotUniverse.allCases) { universe in
                        UniverseCard(
                            universe: universe,
                            isSelected: viewModel.setup.universe == universe,
                            mode: .contain
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                viewModel.selectUniverse(universe)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var setupCard: some View {
        GlassCard(tint: viewModel.setup.universe.primary) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Session Setup")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                MoneySlider(title: "Starting Balance", value: $viewModel.setup.startingBalance, range: 10...500, step: 10, tint: .cyan)
                MoneySlider(title: "Take Profit", value: $viewModel.setup.takeProfit, range: 20...1000, step: 10, tint: .cyan)
                MoneySlider(title: "Stop Loss", value: $viewModel.setup.stopLoss, range: 10...500, step: 5, tint: .red)
                MinuteSlider(title: "Session Timer", value: $viewModel.setup.timerMinutes, range: 10...45, step: 5, tint: .blue)
            }
        }
    }

    private var startButton: some View {
        Button {
            viewModel.startSession()
        } label: {
            Label("Spin & Track", systemImage: "scope")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(colors: [viewModel.setup.universe.primary, viewModel.setup.universe.secondary], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .accessibilityLabel("Start tracking session")
    }
}

struct UniverseCard: View {
    let universe: SlotUniverse
    let isSelected: Bool
    let mode: GraphicMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                GraphicAssetView(name: universe.assetName, fallbackSymbol: universe.symbol, mode: mode)
                    .frame(width: 56, height: 56)
                Text(universe.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 182, height: 122)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? universe.primary : universe.primary.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? universe.primary.opacity(0.7) : .clear, radius: 18)
        }
        .accessibilityLabel("Select \(universe.title)")
    }
}

struct MoneySlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title): $\(Int(value.rounded()))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
            Slider(value: $value, in: range, step: step)
                .tint(tint)
                .accessibilityLabel(title)
        }
    }
}

struct MinuteSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title): \(Int(value.rounded())) min")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
            Slider(value: $value, in: range, step: step)
                .tint(tint)
                .accessibilityLabel(title)
        }
    }
}

struct LiveSessionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showCashOutConfirmation = false

    var body: some View {
        ZStack {
            let universe = viewModel.activeSession?.universe ?? viewModel.setup.universe
            ThemedBackground(universe: universe, assetName: universe.backgroundAssetName)

            if let session = viewModel.activeSession {
                ScrollView {
                    VStack(spacing: 24) {
                        timerCard(session)
                        balanceCard(session)
                        summaryStrip(session)
                        actionRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 78)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .top) {
                    if session.limitState != .clear {
                        limitBanner(session)
                    }
                }
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    viewModel.tickLiveSession()
                }
                .alert("Cash out?", isPresented: $showCashOutConfirmation) {
                    Button("Keep tracking", role: .cancel) {}
                    Button("Cash Out", role: .destructive) {
                        viewModel.finishActiveSession(reason: .manual)
                    }
                } message: {
                    Text("This will save the current balance and close the live session.")
                }
            } else {
                EmptyStateView(
                    title: "No live session",
                    message: "Set your universe and limits in Lobby, then start tracking.",
                    symbol: "play.circle",
                    buttonTitle: "Go to Lobby"
                ) {
                    viewModel.selectedTab = .lobby
                }
            }
        }
    }

    private func timerCard(_ session: LiveSession) -> some View {
        GlassCard(tint: timerTint(session)) {
            VStack(spacing: 8) {
                CircularTimer(progress: Double(session.remainingSeconds) / Double(max(session.totalSeconds, 1)), tint: timerTint(session))
                    .frame(width: 176, height: 176)
                    .overlay {
                        VStack(spacing: 4) {
                            Text(timeString(session.remainingSeconds))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("Time Left")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.74))
                        }
                    }
            }
        }
        .frame(maxWidth: 260)
        .frame(maxWidth: .infinity)
    }

    private func balanceCard(_ session: LiveSession) -> some View {
        GlassCard(tint: session.universe.primary) {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("Current Balance")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))
                    Text("$\(session.currentBalance)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.65)
                    Label("\(session.profit >= 0 ? "+" : "-")$\(abs(session.profit))  (\(session.roi.formatted(.percent.precision(.fractionLength(1)))))", systemImage: session.profit >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(session.profit >= 0 ? .green : .red)
                }

                HStack(spacing: 10) {
                    balanceButton("+$5", delta: 5, color: .green)
                    balanceButton("+$10", delta: 10, color: .green)
                    balanceButton("$-5", delta: -5, color: .red)
                    balanceButton("$-10", delta: -10, color: .red)
                }
            }
        }
    }

    private func balanceButton(_ title: String, delta: Int, color: Color) -> some View {
        Button {
            viewModel.applyBalanceDelta(delta)
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(color.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.9), lineWidth: 1))
        }
        .accessibilityLabel(delta > 0 ? "Add \(delta) dollars" : "Subtract \(abs(delta)) dollars")
    }

    private func summaryStrip(_ session: LiveSession) -> some View {
        GlassCard(tint: session.universe.primary) {
            HStack {
                summaryColumn("Session Time", value: "\(max(1, session.elapsedSeconds / 60)) min")
                summaryColumn("ROI", value: session.roi.formatted(.percent.precision(.fractionLength(1))), tint: session.profit >= 0 ? .green : .red)
                summaryColumn("Take Profit", value: "$\(session.takeProfit)")
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button {
                showCashOutConfirmation = true
            } label: {
                Text("Cash Out")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.red.opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel("Cash out and save session")

            Button {
                viewModel.applyBalanceDelta(5)
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel("Continue session and add five dollars")
        }
    }

    private func limitBanner(_ session: LiveSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: session.limitState == .takeProfit ? "checkmark.seal" : "exclamationmark.triangle")
            Text(session.limitState == .takeProfit ? "Take-Profit reached" : "Stop-loss reached")
            Spacer()
            Button("Save") {
                viewModel.finishActiveSession(reason: .limit)
            }
            .font(.headline)
        }
        .foregroundStyle(.white)
        .padding()
        .background((session.limitState == .takeProfit ? Color.green : Color.red).opacity(0.85))
    }

    private func summaryColumn(_ title: String, value: String, tint: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timerTint(_ session: LiveSession) -> Color {
        if session.remainingSeconds < 120 { return .red }
        if session.remainingSeconds < 600 { return .yellow }
        return .cyan
    }
}

struct HistoryView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var recordPendingDelete: SessionRecord?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(universe: viewModel.profile.preferredUniverse, assetName: viewModel.profile.preferredUniverse.backgroundAssetName)

                if viewModel.sessions.isEmpty {
                    EmptyStateView(
                        title: "No saved sessions",
                        message: "Your finished sessions will appear here with notes, limits and results.",
                        symbol: "clock.badge.questionmark",
                        buttonTitle: "Start a Session"
                    ) {
                        viewModel.selectedTab = .lobby
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("History")
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .frame(maxWidth: 760, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)

                        List {
                            ForEach(viewModel.sessions) { record in
                                NavigationLink {
                                    SessionDetailsView(record: record)
                                } label: {
                                    HistoryRow(record: record)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 7, leading: 24, bottom: 7, trailing: 24))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        recordPendingDelete = record
                                    } label: {
                                        Image("history_delete_action_icon")
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 64, height: 64)
                                    }
                                    .tint(.clear)
                                    .accessibilityLabel("Delete history record")
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .scrollIndicators(.hidden)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Delete session?", isPresented: Binding(
                get: { recordPendingDelete != nil },
                set: { if !$0 { recordPendingDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    recordPendingDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let record = recordPendingDelete,
                       let index = viewModel.sessions.firstIndex(where: { $0.id == record.id }) {
                        viewModel.deleteSessions(at: IndexSet(integer: index))
                    }
                    recordPendingDelete = nil
                }
            } message: {
                Text("This removes the saved session from local history.")
            }
        }
    }
}

struct HistoryRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 14) {
            GraphicAssetView(name: record.universe.assetName, fallbackSymbol: record.universe.symbol, mode: .contain)
                .frame(width: 52, height: 52)
                .background(record.universe.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(record.universe.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(record.startedAt.formatted(date: .abbreviated, time: .shortened)) • \(max(1, record.durationSeconds / 60)) min")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(record.resultText)
                .font(.title3.weight(.bold))
                .foregroundStyle(record.profit >= 0 ? .green : .red)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(record.universe.primary.opacity(0.26), lineWidth: 1))
    }
}

struct SessionDetailsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let record: SessionRecord
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(record: SessionRecord) {
        self.record = record
        _note = State(initialValue: record.note)
    }

    var body: some View {
        ZStack {
            ThemedBackground(universe: record.universe, assetName: record.universe.backgroundAssetName)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleRow
                    heroCard
                    metricsGrid
                    progressionCard
                    notesCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 78)
                .padding(.bottom, 32)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var titleRow: some View {
        HStack {
            Text("Session Details")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(record.universe.primary)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Close session details")
        }
    }

    private var heroCard: some View {
        GlassCard(tint: record.universe.primary) {
            VStack(spacing: 9) {
                GraphicAssetView(name: record.universe.assetName, fallbackSymbol: record.universe.symbol, mode: .contain)
                    .frame(width: 58, height: 58)
                Text(record.universe.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(record.startedAt.formatted(date: .numeric, time: .omitted)) • \(max(1, record.durationSeconds / 60)) minutes")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                Label(record.resultText, systemImage: record.profit >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(record.profit >= 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            detailMetric("Starting Balance", value: "$\(record.startingBalance)")
            detailMetric("Ending Balance", value: "$\(record.endingBalance)")
            detailMetric("Peak Profit", value: "+$\(record.peakProfit)", tint: .green)
            detailMetric("Biggest Drop", value: "-$\(abs(record.biggestDrop))", tint: .red)
        }
    }

    private var progressionCard: some View {
        GlassCard(tint: record.universe.primary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Session Progression")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("ROI: \(record.roi.formatted(.percent.precision(.fractionLength(1))))")
                        .font(.headline)
                        .foregroundStyle(record.profit >= 0 ? .green : .red)
                }
                LineChart(points: record.progression, tint: record.profit >= 0 ? .cyan : .pink)
                    .frame(height: 180)
            }
        }
    }

    private var notesCard: some View {
        GlassCard(tint: record.universe.primary) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Session Notes")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                TextEditor(text: $note)
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                    .overlay(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("Add what happened during the session...")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.48))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                Button {
                    viewModel.updateNote(for: record, note: note)
                    dismissKeyboard()
                } label: {
                    Label("Save Note", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func detailMetric(_ title: String, value: String, tint: Color = .white) -> some View {
        GlassCard(tint: record.universe.primary) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct InsightsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            ThemedBackground(universe: viewModel.profile.preferredUniverse, assetName: viewModel.profile.preferredUniverse.backgroundAssetName)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Arctic Insights")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 76)

                    overallCard
                    metricsGrid
                    weeklyCard
                    distributionCard
                    stopLossWarning
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var overallROI: Double {
        let start = viewModel.sessions.reduce(0) { $0 + $1.startingBalance }
        let profit = viewModel.sessions.reduce(0) { $0 + $1.profit }
        return start == 0 ? 0 : Double(profit) / Double(start)
    }

    private var overallCard: some View {
        GlassCard(tint: .cyan) {
            VStack(spacing: 8) {
                Text("Overall ROI")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
                Text(overallROI.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(overallROI >= 0 ? .green : .red)
                Text("Across all sessions")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            insightMetric("Total Sessions", value: "\(viewModel.sessions.count)", symbol: "clock", tint: .cyan)
            insightMetric("Avg Session Time", value: "\(averageMinutes) min", symbol: "timer", tint: .cyan)
            insightMetric("Total ROI", value: overallROI.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())), symbol: "arrow.up.right", tint: .green)
            insightMetric("Best Session", value: bestSessionText, symbol: "dollarsign", tint: .cyan)
        }
    }

    private var weeklyCard: some View {
        GlassCard(tint: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Weekly ROI Performance")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                WeeklyTotalsChart(entries: weeklyTotals, tint: .cyan, hasData: !viewModel.sessions.isEmpty)
                    .frame(height: 210)
            }
        }
    }

    private var distributionCard: some View {
        GlassCard(tint: .cyan) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Session Distribution")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                DonutDistribution(values: universeCounts)
                    .frame(height: 190)
                if !universeCounts.isEmpty {
                    UniverseDistributionLegend(values: universeCounts)
                }
            }
        }
    }

    private var stopLossWarning: some View {
        let violations = viewModel.sessions.filter(\.closedByLimit).count
        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.yellow)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(violations > 0 ? "Watch your stop-loss limits" : "Limits are under control")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(violations > 0 ? "You have \(violations) recent limit events." : "No saved limit violations yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding()
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var averageMinutes: Int {
        guard !viewModel.sessions.isEmpty else { return 0 }
        return max(1, viewModel.sessions.reduce(0) { $0 + $1.durationSeconds } / viewModel.sessions.count / 60)
    }

    private var bestSessionText: String {
        guard let best = viewModel.sessions.max(by: { $0.profit < $1.profit }) else { return "$0" }
        return best.resultText
    }

    private var weeklyTotals: [WeeklyTotalEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        var entries = labels.enumerated().map { index, label in
            WeeklyTotalEntry(label: label, value: 0)
        }

        for session in viewModel.sessions {
            let sessionDay = calendar.startOfDay(for: session.startedAt)
            guard let offset = calendar.dateComponents([.day], from: monday, to: sessionDay).day,
                  entries.indices.contains(offset) else { continue }
            entries[offset].value += Double(session.profit)
        }

        return entries
    }

    private var universeCounts: [SlotUniverse: Int] {
        Dictionary(grouping: viewModel.sessions, by: \.universe).mapValues(\.count)
    }

    private func insightMetric(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.12), radius: 18, x: 0, y: 8)
    }
}

struct RulesView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private let rules = [
        RuleItem(symbol: "shield", title: "Set Your Limits", body: "Always define stop-loss and take-profit before starting a session."),
        RuleItem(symbol: "target", title: "Track Every Session", body: "Record all spins and balance changes to maintain accurate tracking."),
        RuleItem(symbol: "exclamationmark.triangle", title: "Recognize Tilt", body: "Take breaks when consecutive losses occur. The system will alert you."),
        RuleItem(symbol: "chart.bar", title: "Review Insights", body: "Analyze performance weekly to identify patterns and improve discipline.")
    ]

    var body: some View {
        ZStack {
            ThemedBackground(universe: viewModel.profile.preferredUniverse, assetName: viewModel.profile.preferredUniverse.backgroundAssetName)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Ice Tracker Rules")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 76)

                    GlassCard(tint: .cyan) {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Discipline Principles")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Slots Hub helps you maintain discipline through structured tracking and smart alerts. Follow these principles to maximize your tracking effectiveness and stay in control.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.76))
                                .lineSpacing(6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(rules) { rule in
                        ruleCard(rule)
                    }

                    GlassCard(tint: .cyan) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Session Best Practices")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 10) {
                                bullet("Start each session with a clear balance target")
                                bullet("Never exceed your predetermined stop-loss amount")
                                bullet("Take mandatory breaks after reaching take-profit goals")
                                bullet("Review your history weekly to spot behavioral patterns")
                                bullet("Use alerts as hard stop signals")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func ruleCard(_ item: RuleItem) -> some View {
        GlassCard(tint: item.symbol == "exclamationmark.triangle" ? .yellow : .cyan) {
            HStack(spacing: 18) {
                Image(systemName: item.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.symbol == "exclamationmark.triangle" ? .yellow : .cyan)
                    .frame(width: 52, height: 52)
                    .background((item.symbol == "exclamationmark.triangle" ? Color.yellow : Color.cyan).opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .foregroundStyle(.cyan)
            Text(text)
                .foregroundStyle(.white.opacity(0.78))
        }
        .font(.subheadline)
    }
}

struct RuleItem: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let body: String
}

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedName = ""
    @State private var pendingAvatarImageData: Data?
    @State private var showEditProfile = false
    @State private var showResetConfirmation = false

    var body: some View {
        ZStack {
            ThemedBackground(universe: viewModel.profile.preferredUniverse, assetName: viewModel.profile.preferredUniverse.backgroundAssetName)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Player Profile")
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundStyle(.cyan)
                                .frame(width: 48, height: 48)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .accessibilityLabel("Close profile")
                    }

                    GlassCard(tint: .cyan) {
                        VStack(spacing: 16) {
                            ProfileAvatarView(
                                imageData: viewModel.avatarImageData,
                                assetName: viewModel.profile.avatarAssetName,
                                fallbackSymbol: AvatarPreset.fallback(for: viewModel.profile.avatarAssetName)
                            )
                            .frame(width: 96, height: 96)
                            .background(Color.cyan, in: Circle())
                            .shadow(color: .cyan.opacity(0.45), radius: 24, y: 8)

                            Text(viewModel.profile.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Button {
                                editedName = viewModel.profile.name
                                pendingAvatarImageData = viewModel.avatarImageData
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    showEditProfile = true
                                }
                            } label: {
                                Label("Edit Profile", systemImage: "pencil")
                                    .font(.headline)
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 12)
                                    .background(.cyan.opacity(0.14), in: Capsule())
                                    .overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit profile")
                        }
                        .frame(maxWidth: .infinity)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        profileMetric("Total Sessions", value: "\(viewModel.sessions.count)", symbol: "waveform.path.ecg")
                        profileMetric("Lifetime ROI", value: lifetimeROI, symbol: "arrow.up.right")
                        profileMetric("Best Universe", value: bestUniverse, symbol: "rosette")
                        profileMetric("Biggest Profit", value: biggestProfit, symbol: "target")
                    }

                    GlassCard(tint: .cyan) {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Discipline Score")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            HStack {
                                ProgressView(value: Double(disciplineScore), total: 100)
                                    .tint(.cyan)
                                Text("\(disciplineScore)")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }

                    GlassCard(tint: .cyan) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Settings")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Toggle("Sound", isOn: Binding(
                                get: { viewModel.profile.soundEnabled },
                                set: { viewModel.updateSoundEnabled($0) }
                            ))
                                .tint(.cyan)
                            Toggle("Вибрация", isOn: Binding(
                                get: { viewModel.profile.hapticsEnabled },
                                set: { viewModel.updateHapticsEnabled($0) }
                            ))
                                .tint(.cyan)
                            Toggle("Notifications", isOn: Binding(
                                get: { viewModel.profile.notificationsEnabled },
                                set: { viewModel.updateNotificationsEnabled($0) }
                            ))
                                .tint(.cyan)
                            Toggle("Auto Stop-Loss", isOn: Binding(
                                get: { viewModel.profile.autoStopLossEnabled },
                                set: { viewModel.updateAutoStopLossEnabled($0) }
                            ))
                                .tint(.cyan)
                            Button(role: .destructive) {
                                showResetConfirmation = true
                            } label: {
                                Label("Reset Local Data", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 76)
                .padding(.bottom, 32)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            if showEditProfile {
                ProfileEditOverlay(
                    name: $editedName,
                    avatarImageData: $pendingAvatarImageData,
                    fallbackAssetName: viewModel.profile.avatarAssetName,
                    fallbackSymbol: AvatarPreset.fallback(for: viewModel.profile.avatarAssetName)
                ) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showEditProfile = false
                    }
                } onSave: {
                    viewModel.updateProfileName(editedName)
                    if let pendingAvatarImageData {
                        viewModel.updateAvatarImage(pendingAvatarImageData)
                    }
                    dismissKeyboard()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showEditProfile = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }
        }
        .onAppear {
            editedName = viewModel.profile.name
            pendingAvatarImageData = viewModel.avatarImageData
        }
        .alert("Reset local data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetLocalProfile()
                editedName = viewModel.profile.name
            }
        } message: {
            Text("This deletes local sessions and restores default profile settings.")
        }
    }

    private var lifetimeROI: String {
        let start = viewModel.sessions.reduce(0) { $0 + $1.startingBalance }
        let profit = viewModel.sessions.reduce(0) { $0 + $1.profit }
        let roi = start == 0 ? 0 : Double(profit) / Double(start)
        return roi.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()))
    }

    private var bestUniverse: String {
        let grouped = Dictionary(grouping: viewModel.sessions, by: \.universe)
        return grouped.max { lhs, rhs in
            lhs.value.reduce(0) { $0 + $1.profit } < rhs.value.reduce(0) { $0 + $1.profit }
        }?.key.shortTitle ?? "Big Bass"
    }

    private var biggestProfit: String {
        guard let best = viewModel.sessions.max(by: { $0.profit < $1.profit }) else { return "$0" }
        return best.resultText
    }

    private var disciplineScore: Int {
        guard !viewModel.sessions.isEmpty else { return 78 }
        let limitEvents = viewModel.sessions.filter(\.closedByLimit).count
        return max(35, 100 - limitEvents * 12)
    }

    private func profileMetric(_ title: String, value: String, symbol: String) -> some View {
        GlassCard(tint: .cyan) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(.cyan)
                    .frame(width: 42, height: 42)
                    .background(.cyan.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(value)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct ProfileAvatarView: View {
    let imageData: Data?
    let assetName: String
    let fallbackSymbol: String

    var body: some View {
        ZStack {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                GraphicAssetView(name: assetName, fallbackSymbol: fallbackSymbol, mode: .contain)
                    .padding(18)
            }
        }
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct ProfileEditOverlay: View {
    @Binding var name: String
    @Binding var avatarImageData: Data?
    let fallbackAssetName: String
    let fallbackSymbol: String
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.24))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissKeyboard()
                }

            VStack(spacing: 16) {
                ProfileAvatarView(imageData: avatarImageData, assetName: fallbackAssetName, fallbackSymbol: fallbackSymbol)
                    .frame(width: 96, height: 96)
                    .background(Color.cyan, in: Circle())
                    .shadow(color: .cyan.opacity(0.50), radius: 26, y: 8)

                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Label("Choose Photo", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.cyan.opacity(0.14), in: Capsule())
                }
                .accessibilityLabel("Choose profile image from gallery")

                TextField("Ice Tracker Pro...", text: $name)
                    .textInputAutocapitalization(.words)
                    .multilineTextAlignment(.leading)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(.white.opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.cyan, lineWidth: 1.5)
                    )
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }

                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(.white.opacity(0.08), in: Capsule())

                    Button("Save") {
                        onSave()
                    }
                    .font(.headline)
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(.cyan.opacity(0.16), in: Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.38), lineWidth: 1))
                }
            }
            .padding(20)
            .frame(maxWidth: 345)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.10, blue: 0.20).opacity(0.96),
                        Color(red: 0.02, green: 0.07, blue: 0.16).opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.cyan.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .cyan.opacity(0.55), radius: 34)
            .padding(.horizontal, 24)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        avatarImageData = data
                    }
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.cyan)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            Button(action: action) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .padding(.top, 6)
        }
        .padding(26)
        .frame(maxWidth: 420)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(24)
    }
}

struct GlassCard<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(24)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.12), radius: 22, x: 0, y: 10)
    }
}

struct GraphicAssetView: View {
    let name: String
    let fallbackSymbol: String
    let mode: GraphicMode

    var body: some View {
        Group {
            if UIImage(named: name) != nil {
                imageView
            } else {
                fallbackView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var imageView: some View {
        Image(name)
            .resizable()
            .modifier(GraphicModeModifier(mode: mode))
            .accessibilityHidden(true)
    }

    private var fallbackView: some View {
        ZStack {
            LinearGradient(colors: [.cyan.opacity(0.24), .blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: fallbackSymbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.cyan)
                .minimumScaleFactor(0.6)
        }
        .accessibilityHidden(true)
    }
}

struct GraphicModeModifier: ViewModifier {
    let mode: GraphicMode

    func body(content: Content) -> some View {
        switch mode {
        case .cover:
            content.scaledToFill()
        case .contain:
            content.scaledToFit()
        case .fill:
            content
        }
    }
}

struct ThemedBackground: View {
    let universe: SlotUniverse
    let assetName: String

    var body: some View {
        ZStack {
            GraphicAssetView(name: assetName, fallbackSymbol: "snowflake", mode: .cover)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    universe.primary.opacity(0.20),
                    Color(red: 0.0, green: 0.05, blue: 0.13).opacity(0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Canvas { context, size in
                for index in 0..<80 {
                    let x = Double((index * 61) % Int(max(size.width, 1)))
                    let y = Double((index * 97) % Int(max(size.height, 1)))
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.22)))
                }
            }
            .ignoresSafeArea()
        }
    }
}

struct CircularTimer: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 13)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(10)
    }
}

struct WeeklyTotalEntry: Identifiable {
    let id = UUID()
    let label: String
    var value: Double
}

struct WeeklyTotalsChart: View {
    let entries: [WeeklyTotalEntry]
    let tint: Color
    let hasData: Bool

    var body: some View {
        GeometryReader { proxy in
            let chartInsets = EdgeInsets(top: 12, leading: 42, bottom: 30, trailing: 6)
            let chartWidth = max(1, proxy.size.width - chartInsets.leading - chartInsets.trailing)
            let chartHeight = max(1, proxy.size.height - chartInsets.top - chartInsets.bottom)
            let values = entries.map(\.value)
            let maxAbsValue = max(values.map(abs).max() ?? 1, 1)
            let roundedMax = max(15, ceil(maxAbsValue / 15) * 15)
            let minValue = values.contains { $0 < 0 } ? -roundedMax : 0
            let maxValue = roundedMax
            let valueRange = maxValue - minValue
            let zeroY = chartInsets.top + CGFloat(maxValue / valueRange) * chartHeight
            let barSlotWidth = chartWidth / CGFloat(max(entries.count, 1))

            ZStack(alignment: .topLeading) {
                ForEach(0...4, id: \.self) { index in
                    let value = maxValue - (Double(index) * valueRange / 4)
                    let y = chartInsets.top + chartHeight * CGFloat(index) / 4

                    Text(axisLabel(value))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                        .monospacedDigit()
                        .frame(width: chartInsets.leading - 8, alignment: .trailing)
                        .position(x: (chartInsets.leading - 8) / 2, y: y)

                    Path { path in
                        path.move(to: CGPoint(x: chartInsets.leading, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width - chartInsets.trailing, y: y))
                    }
                    .stroke(.cyan.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                ForEach(entries.indices, id: \.self) { index in
                    let x = chartInsets.leading + CGFloat(index) * barSlotWidth + barSlotWidth / 2

                    Path { path in
                        path.move(to: CGPoint(x: x, y: chartInsets.top))
                        path.addLine(to: CGPoint(x: x, y: chartInsets.top + chartHeight))
                    }
                    .stroke(.cyan.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                Path { path in
                    path.move(to: CGPoint(x: chartInsets.leading, y: zeroY))
                    path.addLine(to: CGPoint(x: proxy.size.width - chartInsets.trailing, y: zeroY))
                }
                .stroke(.white.opacity(0.35), lineWidth: 1)

                Path { path in
                    path.move(to: CGPoint(x: chartInsets.leading, y: chartInsets.top))
                    path.addLine(to: CGPoint(x: chartInsets.leading, y: chartInsets.top + chartHeight))
                    path.addLine(to: CGPoint(x: proxy.size.width - chartInsets.trailing, y: chartInsets.top + chartHeight))
                }
                .stroke(.white.opacity(0.55), lineWidth: 1)

                ForEach(entries.indices, id: \.self) { index in
                    let entry = entries[index]
                    let normalizedHeight = CGFloat(abs(entry.value) / valueRange) * chartHeight
                    let barHeight = max(entry.value == 0 ? 0 : 5, normalizedHeight)
                    let barWidth = min(26, max(14, barSlotWidth * 0.52))
                    let x = chartInsets.leading + CGFloat(index) * barSlotWidth + barSlotWidth / 2
                    let y = entry.value >= 0 ? zeroY - barHeight / 2 : zeroY + barHeight / 2

                    RoundedRectangle(cornerRadius: 6)
                        .fill(entry.value >= 0 ? tint : Color.red)
                        .frame(width: barWidth, height: barHeight)
                        .position(x: x, y: y)

                    Text(entry.label)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .position(x: x, y: proxy.size.height - 10)
                }

                if hasNoData {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.46))
                        Text("No weekly session data yet")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                        Text("Finish sessions to see daily totals.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: chartWidth)
                    .position(x: chartInsets.leading + chartWidth / 2, y: chartInsets.top + chartHeight / 2)
                }
            }
        }
    }

    private var hasNoData: Bool { !hasData }

    private func axisLabel(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded == 0 ? "0" : "\(rounded)"
    }
}

struct LineChart: View {
    let points: [BalancePoint]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let balances = points.map(\.balance)
            let minBalance = balances.min() ?? 0
            let maxBalance = balances.max() ?? 1
            let span = max(maxBalance - minBalance, 1)
            let maxSecond = max(points.map(\.second).max() ?? 1, 1)

            ZStack {
                GridLines()
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(point.second) / CGFloat(maxSecond) * proxy.size.width
                        let y = proxy.size.height - CGFloat(point.balance - minBalance) / CGFloat(span) * proxy.size.height
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(points) { point in
                    let x = CGFloat(point.second) / CGFloat(maxSecond) * proxy.size.width
                    let y = proxy.size.height - CGFloat(point.balance - minBalance) / CGFloat(span) * proxy.size.height
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

struct GridLines: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for index in 0...4 {
                    let y = proxy.size.height * CGFloat(index) / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                for index in 0...5 {
                    let x = proxy.size.width * CGFloat(index) / 5
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                }
            }
            .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
}

struct DonutDistribution: View {
    let values: [SlotUniverse: Int]

    var body: some View {
        Canvas { context, size in
            let lineWidth = min(size.width, size.height) * 0.14
            let radius = min(size.width, size.height) * 0.32
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let total = values.values.reduce(0, +)

            if total == 0 {
                var emptyPath = Path()
                emptyPath.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
                context.stroke(emptyPath, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                return
            }

            let displayValues = values
            let safeTotal = max(total, 1)
            var start = Angle.degrees(-104)
            let universes = SlotUniverse.allCases
            let gap = 7.0

            for universe in universes {
                let count = displayValues[universe] ?? 0
                guard count > 0 else { continue }
                let degrees = max(0, 360 * Double(count) / Double(safeTotal) - gap)
                let end = start + .degrees(degrees)
                var path = Path()
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                context.stroke(path, with: .color(universe.primary), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                start = end + .degrees(gap)
            }
        }
        .accessibilityLabel("Session distribution chart")
    }
}

struct UniverseDistributionLegend: View {
    let values: [SlotUniverse: Int]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(SlotUniverse.allCases) { universe in
                HStack(spacing: 12) {
                    Circle()
                        .fill(universe.primary)
                        .frame(width: 12, height: 12)

                    Text(universe.shortTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("\(percentage(for: universe))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .monospacedDigit()

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(universe.primary)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(legendBackground(for: universe), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(universe.primary.opacity(0.28), lineWidth: 1)
                )
            }
        }
    }

    private var displayValues: [SlotUniverse: Int] {
        values
    }

    private func percentage(for universe: SlotUniverse) -> Int {
        let total = max(displayValues.values.reduce(0, +), 1)
        let value = displayValues[universe] ?? 0
        return Int((Double(value) / Double(total) * 100).rounded())
    }

    private func legendBackground(for universe: SlotUniverse) -> LinearGradient {
        LinearGradient(
            colors: [
                universe.primary.opacity(0.35),
                universe.primary.opacity(0.14)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

func timeString(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remaining = seconds % 60
    return "\(minutes):\(remaining < 10 ? "0" : "")\(remaining)"
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
