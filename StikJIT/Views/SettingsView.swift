//  SettingsView.swift
//  StikJIT
//
//  Created by Stephen on 3/27/25.

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @AppStorage("username") private var username = "User"
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String = "AppIcon"
    @AppStorage("enableAdvancedOptions") private var enableAdvancedOptions = false
    @AppStorage("enableAdvancedBetaOptions") private var enableAdvancedBetaOptions = false
    @AppStorage("enableTesting") private var enableTesting = false
    @AppStorage("enablePiP") private var enablePiP = false
    @AppStorage(UserDefaults.Keys.txmOverride) private var overrideTXMDetection = false
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage(TabConfiguration.storageKey) private var enabledTabIdentifiers = TabConfiguration.defaultRawValue
    @AppStorage("primaryTabSelection") private var tabSelection = TabConfiguration.defaultIDs.first ?? "home"
    @Environment(\.themeExpansionManager) private var themeExpansion
    private var backgroundStyle: BackgroundStyle { themeExpansion?.backgroundStyle(for: appThemeRaw) ?? AppTheme.system.backgroundStyle }
    private var preferredScheme: ColorScheme? { themeExpansion?.preferredColorScheme(for: appThemeRaw) }
    private var isAppStoreBuild: Bool {
        #if APPSTORE
        return true
        #else
        return false
        #endif
    }
    
    @State private var isShowingPairingFilePicker = false
    @Environment(\.colorScheme) private var colorScheme

    @State private var showIconPopover = false
    @State private var showPairingFileMessage = false
    @State private var isImportingFile = false
    @State private var importProgress: Float = 0.0
    @State private var pairingStatusMessage: String? = nil
    @State private var showRemovePairingFileDialog = false
    @State private var is_lc = false
    @State private var showColorPickerPopup = false
    @State private var showDDIConfirmation = false
    @State private var isRedownloadingDDI = false
    @State private var ddiDownloadProgress: Double = 0.0
    @State private var ddiStatusMessage: String = ""
    @State private var ddiResultMessage: (text: String, isError: Bool)?

    @State private var showingDisplayView = false
    @State private var tabSelectionMessage: String?
    
    private var appVersion: String {
        let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return marketingVersion
    }
    
    private var accentColor: Color {
        themeExpansion?.resolvedAccentColor(from: customAccentColorHex) ?? .blue
    }

    private var currentThemeName: String {
        AppTheme(rawValue: appThemeRaw)?.displayName ?? "Default"
    }

    private var accentColorDescription: String {
        customAccentColorHex.isEmpty ? "System Blue" : customAccentColorHex.uppercased()
    }
    struct TabOption: Identifiable {
        let id: String
        let title: String
        let detail: String
        let icon: String
        let isBeta: Bool
    }
    
    private let developerProfiles: [String: String] = [
        "Stephen": "https://github.com/StephenDev0.png",
        "jkcoxson": "https://github.com/jkcoxson.png",
        "Stossy11": "https://github.com/Stossy11.png",
        "Neo": "https://github.com/neoarz.png",
        "Se2crid": "https://github.com/Se2crid.png",
        "Huge_Black": "https://github.com/HugeBlack.png",
        "Wynwxst": "https://github.com/Wynwxst.png"
    ]
    
    private var tabOptions: [TabOption] {
        var options: [TabOption] = [
            TabOption(id: "home", title: "Home", detail: "Dashboard overview", icon: "house", isBeta: false),
            TabOption(id: "console", title: "Console", detail: "Live device logs", icon: "terminal", isBeta: false),
            TabOption(id: "scripts", title: "Scripts", detail: "Manage automation scripts", icon: "scroll", isBeta: false)
        ]
        options.append(TabOption(id: "deviceinfo", title: "Device Info", detail: "View detailed device metadata", icon: "iphone.and.arrow.forward", isBeta: false))
        if FeatureFlags.showBetaTabs {
            options.append(TabOption(id: "profiles", title: "Profiles", detail: "Install/remove profiles", icon: "magazine", isBeta: true))
        }
        if FeatureFlags.showBetaTabs {
            options.append(TabOption(id: "processes", title: "Processes", detail: "Inspect running apps", icon: "rectangle.stack.person.crop", isBeta: true))
            options.append(TabOption(id: "devicelibrary", title: "Devices", detail: "Manage external devices", icon: "list.bullet.rectangle", isBeta: true))
            if FeatureFlags.isLocationSpoofingEnabled && !isAppStoreBuild {
                options.append(TabOption(id: "location", title: "Location Sim", detail: "Sideload only", icon: "location", isBeta: true))
            }
        }
        return options
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle depth gradient background
                ThemedBackground(style: backgroundStyle)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        appearanceCard
                        tabCustomizationCard
                        pairingCard
                        behaviorCard
                        advancedCard
                        helpCard
                        versionInfo
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
                }
                
                // Busy overlay while importing pairing file
                if isImportingFile {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView("Processing pairing file…")
                        VStack(spacing: 8) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(UIColor.tertiarySystemFill))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.green)
                                        .frame(width: geometry.size.width * CGFloat(importProgress), height: 8)
                                        .animation(.linear(duration: 0.3), value: importProgress)
                                }
                            }
                            .frame(height: 8)
                            Text("\(Int(importProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                }
                
                // Success toast after import
                if let pairingStatusMessage,
                   showPairingFileMessage,
                   !isImportingFile {
                    VStack {
                        Spacer()
                        Text(pairingStatusMessage)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 3)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 30)
                    }
                    .animation(.easeInOut(duration: 0.25), value: showPairingFileMessage)
                }
            }
            .navigationTitle("Settings")
        }
        // Match controls to the active accent color (defaults to blue)
        .tint(accentColor)
        .preferredColorScheme(preferredScheme)
        .fileImporter(
            isPresented: $isShowingPairingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                
                let fileManager = FileManager.default
                let accessing = url.startAccessingSecurityScopedResource()
                
                if fileManager.fileExists(atPath: url.path) {
                    do {
                        if fileManager.fileExists(atPath: URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path) {
                            try fileManager.removeItem(at: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        }
                        
                        try fileManager.copyItem(at: url, to: URL.documentsDirectory.appendingPathComponent("pairingFile.plist"))
                        print("File copied successfully!")
                        
                        DispatchQueue.main.async {
                            isImportingFile = true
                            importProgress = 0.0
                            pairingStatusMessage = nil
                            showPairingFileMessage = false
                        }
                        
                        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                            DispatchQueue.main.async {
                                if importProgress < 1.0 {
                                    importProgress += 0.05
                                } else {
                                    timer.invalidate()
                                    isImportingFile = false
                                }
                            }
                        }
                        
                        RunLoop.current.add(progressTimer, forMode: .common)
                        DispatchQueue.main.async {
                            startHeartbeatInBackground()
                        }
                        
                    } catch {
                        print("Error copying file: \(error)")
                    }
                } else {
                    print("Source file does not exist.")
                }
                
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("Failed to import file: \(error)")
            }
        }
        .confirmationDialog("Redownload DDI Files?", isPresented: $showDDIConfirmation, titleVisibility: .visible) {
            Button("Redownload", role: .destructive) {
                redownloadDDIPressed()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Existing DDI files will be removed before downloading fresh copies.")
        }
    }
    
    // MARK: - Cards
    
    private var headerCard: some View {
        glassCard {
            VStack(spacing: 16) {
                VStack {
                    Image("StikDebug")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                Text("StikDebug")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private var appearanceCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Appearance")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentThemeName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("Accent · \(accentColorDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                Button(action: { showingDisplayView = true }) {
                    HStack {
                        Image(systemName: "paintbrush")
                            .font(.system(size: 18))
                            .foregroundColor(.primary.opacity(0.85))
                        Text("Customize Display")
                            .foregroundColor(.primary.opacity(0.85))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(4)
        }
        .sheet(isPresented: $showingDisplayView) {
            if let manager = themeExpansion {
                DisplayView().themeExpansionManager(manager)
            } else {
                DisplayView()
            }
        }
    }
    
    private var tabCustomizationCard: some View {
        let selection = selectedTabIDs
        let pinnedOptions = selectedTabIDs.compactMap { id in
            tabOptions.first(where: { $0.id == id })
        }
        let unpinnedOptions = tabOptions.filter { !selection.contains($0.id) }
        return glassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tab Bar")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Pick up to \(TabConfiguration.maxSelectableTabs) tabs to pin. Settings is always available as the final tab.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(pinnedOptions) { option in
                    TabRow(option: option,
                           isPinned: true,
                           isFirst: pinnedOptions.first?.id == option.id,
                           isLast: pinnedOptions.last?.id == option.id,
                           isBeta: option.isBeta,
                           onMove: { moveTab(option.id, offset: $0) },
                           onToggle: { toggleTabOption(option, enable: $0) },
                           onSelect: { if $0 { tabSelection = option.id }; switchToTab(option.id) })
                }
                if !unpinnedOptions.isEmpty {
                    Divider()
                    ForEach(unpinnedOptions) { option in
                        TabRow(option: option,
                               isPinned: false,
                               isFirst: false,
                               isLast: false,
                               isBeta: option.isBeta,
                               onMove: { _ in },
                               onToggle: { toggleTabOption(option, enable: $0) },
                               onSelect: { _ in switchToTab(option.id) })
                    }
                }
                Text("\(selection.count) / \(TabConfiguration.maxSelectableTabs) slots used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let message = tabSelectionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(4)
        }
    }
    
    private var pairingCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Pairing File")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button {
                    isShowingPairingFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18))
                        Text("Import New Pairing File")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(accentColor.contrastText())
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                if showPairingFileMessage && !isImportingFile {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Pairing file successfully imported")
                            .font(.callout)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .transition(.opacity)
                }
            }
        }
    }
    
    private var behaviorCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Behavior")
                    .font(.headline)
                    .foregroundColor(.primary)

                Toggle("Picture in Picture", isOn: $enablePiP)
                    .tint(accentColor)
                Toggle(isOn: $overrideTXMDetection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Always Run Scripts")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary.opacity(0.9))
                        Text("Treat this device as TXM-capable to bypass hardware checks.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(accentColor)
            }
            .onChange(of: enableAdvancedOptions) { _, newValue in
                if !newValue {
                    enablePiP = false
                    enableAdvancedBetaOptions = false
                    enableTesting = false
                }
            }
            .onChange(of: enableAdvancedBetaOptions) { _, newValue in
                if !newValue {
                    enableTesting = false
                }
            }
        }
    }
        
    private var advancedCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Advanced")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button(action: { openAppFolder() }) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 18))
                            .foregroundColor(.primary.opacity(0.8))
                        Text("App Folder")
                            .foregroundColor(.primary.opacity(0.8))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                }
                Button(action: { showDDIConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.primary.opacity(0.8))
                        Text("Redownload DDI")
                            .foregroundColor(.primary.opacity(0.8))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .disabled(isRedownloadingDDI)
                
                if isRedownloadingDDI {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: ddiDownloadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(accentColor)
                        Text(ddiStatusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let result = ddiResultMessage {
                    Text(result.text)
                        .font(.caption)
                        .foregroundColor(result.isError ? .red : .green)
                }
            }
        }
    }

    private var helpCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Help")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button(action: {
                    if let url = URL(string: "https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.primary.opacity(0.8))
                        Text("Pairing File Guide")
                            .foregroundColor(.primary.opacity(0.8))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Button(action: {
                    if let url = URL(string: "https://apps.apple.com/us/app/localdevvpn/id6755608044") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.primary.opacity(0.8))
                        Text("Download LocalDevVPN")
                            .foregroundColor(.primary.opacity(0.8))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Button(action: {
                    if let url = URL(string: "https://discord.gg/qahjXNTDwS") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.primary.opacity(0.8))
                        Text("Need support? Join the Discord!")
                            .foregroundColor(.primary.opacity(0.8))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
            }
        }
    }

    private var versionInfo: some View {
        let processInfo = ProcessInfo.processInfo
        let txmLabel: String
        if processInfo.isTXMOverridden {
            txmLabel = "TXM (Override)"
        } else {
            txmLabel = processInfo.hasTXM ? "TXM" : "Non TXM"
        }
        return HStack {
            Spacer()
            Text("Version \(appVersion) • iOS \(UIDevice.current.systemVersion) • \(txmLabel)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 6)
    }
    
    // MARK: - Helpers (UI + logic)
    
    private var selectedTabIDs: [String] {
        TabConfiguration.sanitize(raw: enabledTabIdentifiers)
    }
    
    private func toggleTabOption(_ option: TabOption, enable: Bool) {
        var ids = selectedTabIDs
        if enable {
            guard !ids.contains(option.id) else { return }
            guard ids.count < TabConfiguration.maxSelectableTabs else {
                tabSelectionMessage = "You can only pin \(TabConfiguration.maxSelectableTabs) tabs besides Settings."
                return
            }
            ids.append(option.id)
        } else {
            ids.removeAll { $0 == option.id }
            if ids.isEmpty {
                ids = TabConfiguration.defaultIDs
            }
        }
        tabSelectionMessage = nil
        enabledTabIdentifiers = TabConfiguration.serialize(ids)
    }
    
    private func moveTab(_ id: String, offset: Int) {
        var ids = selectedTabIDs
        guard let currentIndex = ids.firstIndex(of: id) else { return }
        let targetIndex = max(0, min(ids.count - 1, currentIndex + offset))
        guard currentIndex != targetIndex else { return }
        let element = ids.remove(at: currentIndex)
        ids.insert(element, at: targetIndex)
        enabledTabIdentifiers = TabConfiguration.serialize(ids)
    }
    
    private func switchToTab(_ id: String) {
        NotificationCenter.default.post(name: .switchToTab, object: id)
    }

    private struct TabRow: View {
        let option: TabOption
        let isPinned: Bool
        let isFirst: Bool
        let isLast: Bool
        let isBeta: Bool
        let onMove: (Int) -> Void
        let onToggle: (Bool) -> Void
        let onSelect: (Bool) -> Void

        var body: some View {
            HStack(spacing: 12) {
                Button {
                    onSelect(isPinned)
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        Image(systemName: option.icon)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.primary.opacity(0.8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                            Text(option.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                        if isBeta {
                            Spacer(minLength: 12)
                            Text("BETA")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .foregroundColor(.orange)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if isPinned {
                    HStack(spacing: 8) {
                        Button {
                            onMove(-1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(isFirst)

                        Button {
                            onMove(1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(isLast)
                    }
                    .buttonStyle(.borderless)
                }

                Toggle(isOn: Binding(
                    get: { isPinned },
                    set: { newValue in onToggle(newValue) }
                )) {
                    EmptyView()
                }
                .labelsHidden()
            }
        }
    }
    
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        MaterialCard {
            content()
        }
    }
        
    private func changeAppIcon(to iconName: String) {
        selectedAppIcon = iconName
        UIApplication.shared.setAlternateIconName(iconName == "AppIcon" ? nil : iconName) { error in
            if let error = error {
                print("Error changing app icon: \(error.localizedDescription)")
            }
        }
    }
    
    private func iconButton(_ label: String, icon: String) -> some View {
        Button(action: {
            changeAppIcon(to: icon)
            showIconPopover = false
        }) {
            HStack {
                Image(uiImage: UIImage(named: icon) ?? UIImage())
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func openAppFolder() {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let path = documentsURL.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")
            if let url = URL(string: path) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        print("Failed to open app folder")
                    }
                }
            }
        }
    }

    private func redownloadDDIPressed() {
        guard !isRedownloadingDDI else { return }
        Task {
            await MainActor.run {
                isRedownloadingDDI = true
                ddiDownloadProgress = 0
                ddiStatusMessage = "Preparing download…"
                ddiResultMessage = nil
            }
            do {
                try await redownloadDDI { progress, status in
                    Task { @MainActor in
                        self.ddiDownloadProgress = progress
                        self.ddiStatusMessage = status
                    }
                }
                await MainActor.run {
                    isRedownloadingDDI = false
                    ddiResultMessage = ("DDI files refreshed successfully.", false)
                }
            } catch {
                await MainActor.run {
                    isRedownloadingDDI = false
                    ddiResultMessage = ("Failed to redownload DDI files: \(error.localizedDescription)", true)
                }
            }
        }
        scheduleDDIStatusDismiss()
    }
    
    private func scheduleDDIStatusDismiss() {
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                if !isRedownloadingDDI {
                    ddiResultMessage = nil
                }
            }
        }
    }
}

// MARK: - Helper Components

struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
}

struct InfoRow: View {
    var title: String
    var value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

struct LinkRow: View {
    var icon: String
    var title: String
    var url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(alignment: .center) {
                Text(title)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 24)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ConsoleLogsView_Preview: PreviewProvider {
    static var previews: some View {
        ConsoleLogsView()
            .themeExpansionManager(ThemeExpansionManager(previewUnlocked: true))
    }
}

class FolderViewController: UIViewController {
    func openAppFolder() {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let documentsDirectory = paths.first else { return }
        let containerPath = (documentsDirectory as NSString).deletingLastPathComponent
        
        if let folderURL = URL(string: "shareddocuments://\(containerPath)") {
            UIApplication.shared.open(folderURL, options: [:]) { success in
                if !success {
                    let regularURL = URL(fileURLWithPath: containerPath)
                    UIApplication.shared.open(regularURL, options: [:], completionHandler: nil)
                }
            }
        }
    }
}
