//
//  MainTabView.swift
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

import SwiftUI

private struct TabDescriptor: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let builder: () -> AnyView
}

extension Notification.Name {
    static let switchToTab = Notification.Name("MainTabSwitchNotification")
}

struct MainTabView: View {
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage(TabConfiguration.storageKey) private var enabledTabIdentifiers: String = TabConfiguration.defaultRawValue
    @AppStorage("primaryTabSelection") private var selection: String = TabConfiguration.defaultIDs.first ?? "home"
    @State private var switchObserver: Any?
    @State private var detachedTab: TabDescriptor?
    @State private var didSetInitialHome = false

    // Update checking
    @State private var showForceUpdate: Bool = false
    @State private var latestVersion: String? = nil

    @Environment(\.themeExpansionManager) private var themeExpansion

    private var accentColor: Color {
        themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue
    }
    
    private var preferredScheme: ColorScheme? {
        themeExpansion?.preferredColorScheme(for: appThemeRaw)
    }

    private var isAppStoreBuild: Bool {
        #if APPSTORE
        return true
        #else
        return false
        #endif
    }

    private var configurableTabs: [TabDescriptor] {
        var tabs: [TabDescriptor] = [
            TabDescriptor(id: "home", title: "Home", systemImage: "house") { AnyView(HomeView()) },
            TabDescriptor(id: "console", title: "Console", systemImage: "terminal") { AnyView(ConsoleLogsView()) },
            TabDescriptor(id: "scripts", title: "Scripts", systemImage: "scroll") { AnyView(ScriptListView()) },
            TabDescriptor(id: "deviceinfo", title: "Device Info", systemImage: "iphone.and.arrow.forward") { AnyView(DeviceInfoView()) }
        ]
        if FeatureFlags.showBetaTabs {
            tabs.append(TabDescriptor(id: "profiles", title: "Profiles", systemImage: "magazine.fill") { AnyView(ProfileView()) })
            tabs.append(TabDescriptor(id: "processes", title: "Processes", systemImage: "rectangle.stack.person.crop") { AnyView(ProcessInspectorView()) })
            tabs.append(TabDescriptor(id: "devicelibrary", title: "Devices", systemImage: "list.bullet.rectangle") { AnyView(DeviceLibraryView()) })
            if FeatureFlags.isLocationSpoofingEnabled {
                tabs.append(TabDescriptor(id: "location", title: "Location", systemImage: "location") { AnyView(LocationSimulationView()) })
            }
        }
        return tabs
    }
    
    private var availableTabs: [TabDescriptor] {
        configurableTabs.filter { descriptor in
            descriptor.id != "location" || (!isAppStoreBuild && FeatureFlags.isLocationSpoofingEnabled && FeatureFlags.showBetaTabs)
        }
    }
    
    private let settingsTab = TabDescriptor(id: "settings", title: "Settings", systemImage: "gearshape.fill") {
        AnyView(SettingsView())
    }
    
    private var selectedTabDescriptors: [TabDescriptor] {
        let ids = TabConfiguration.sanitize(raw: enabledTabIdentifiers)
        return ids.compactMap { id in
            availableTabs.first(where: { $0.id == id })
        }
    }
    
    private func ensureSelectionIsValid() {
        let ids = selectedTabDescriptors.map { $0.id }
        if ids.contains(selection) || selection == settingsTab.id {
            return
        }
        selection = ids.first ?? settingsTab.id
    }
    
    var body: some View {
        ZStack {
            // Allow global themed background to show
            Color.clear.ignoresSafeArea()
            
            // Main tabs
            TabView(selection: $selection) {
                ForEach(selectedTabDescriptors) { descriptor in
                    descriptor.builder()
                        .tabItem { Label(descriptor.title, systemImage: descriptor.systemImage) }
                        .tag(descriptor.id)
                }
                
                settingsTab.builder()
                    .tabItem { Label(settingsTab.title, systemImage: settingsTab.systemImage) }
                    .tag(settingsTab.id)
            }
            .id((themeExpansion?.hasThemeExpansion == true) ? customAccentColorHex : "default-accent")
            .tint(accentColor)
            .preferredColorScheme(preferredScheme)
            .onAppear {
                enabledTabIdentifiers = TabConfiguration.serialize(TabConfiguration.sanitize(raw: enabledTabIdentifiers))
                ensureSelectionIsValid()
                if !didSetInitialHome {
                    if selectedTabDescriptors.contains(where: { $0.id == "home" }) {
                        selection = "home"
                    } else if let descriptor = availableTabs.first(where: { $0.id == "home" }) {
                        detachedTab = descriptor
                    }
                    didSetInitialHome = true
                }
                checkForUpdate()
                switchObserver = NotificationCenter.default.addObserver(forName: .switchToTab, object: nil, queue: .main) { note in
                    guard let id = note.object as? String else { return }
                    if selectedTabDescriptors.contains(where: { $0.id == id }) {
                        selection = id
                    } else if let descriptor = availableTabs.first(where: { $0.id == id }) {
                        detachedTab = descriptor
                    }
                }
            }
            .onDisappear {
                if let observer = switchObserver {
                    NotificationCenter.default.removeObserver(observer)
                    switchObserver = nil
                }
            }
            .onChange(of: enabledTabIdentifiers) { _ in
                ensureSelectionIsValid()
            }
            .sheet(item: $detachedTab) { descriptor in
                NavigationStack {
                    descriptor.builder()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    detachedTab = nil
                                }
                            }
                        }
                }
            }

            if showForceUpdate {
                ZStack {
                    Color.black.opacity(0.001).ignoresSafeArea()

                    appGlassCard {
                        VStack(spacing: 20) {
                            Text("Update Required")
                                .font(.title.bold())
                                .multilineTextAlignment(.center)

                            Text("A new version (\(latestVersion ?? "unknown")) is available. Please update to continue using the app.")
                                .multilineTextAlignment(.center)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            Button(action: {
                                let urlString: String
                                if isAppStoreBuild {
                                    urlString = "itms-apps://itunes.apple.com/app/id6744045754"
                                } else {
                                    urlString = "altstore://source?url=https://StikDebug.xyz/apps.json"
                                }
                                if let url = URL(string: urlString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Update Now")
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.accentColor)
                                    )
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut, value: showForceUpdate)
            }
        }
    }

    // MARK: - Update Checker
    private func checkForUpdate() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

        fetchLatestVersion { latest in
            latestVersion = latest
            if let latest = latest,
               latest.compare(currentVersion, options: .numeric) == .orderedDescending {
                DispatchQueue.main.async {
                    showForceUpdate = true
                }
            }
        }
    }

    private func fetchLatestVersion(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=6744045754") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let appStoreVersion = results.first?["version"] as? String {
                    completion(appStoreVersion)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .themeExpansionManager(ThemeExpansionManager(previewUnlocked: true))
    }
}
