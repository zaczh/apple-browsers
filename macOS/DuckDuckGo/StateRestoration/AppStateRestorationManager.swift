//
//  AppStateRestorationManager.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Combine
import Common
import PixelKit
import os.log

@MainActor
final class AppStateRestorationManager: NSObject {
    static let fileName = "persistentState"

    private let service: StatePersistenceService
    private let tabSnapshotCleanupService: TabSnapshotCleanupService
    private var appWillRelaunchCancellable: AnyCancellable?
    private var stateChangedCancellable: AnyCancellable?
    private let pinnedTabsManagerProvider: PinnedTabsManagerProviding = Application.appDelegate.pinnedTabsManagerProvider

    @UserDefaultsWrapper(key: .appIsRelaunchingAutomatically, defaultValue: false)
    private var appIsRelaunchingAutomatically: Bool
    private var shouldRestoreRegularTabs: Bool {
        return StartupPreferences().restorePreviousSession
    }

    convenience init(fileStore: FileStore) {
        let service = StatePersistenceService(fileStore: fileStore, fileName: AppStateRestorationManager.fileName)
        self.init(fileStore: fileStore, service: service)
    }

    init(
        fileStore: FileStore,
        service: StatePersistenceService) {
        self.service = service
        self.tabSnapshotCleanupService = TabSnapshotCleanupService(fileStore: fileStore)
    }

    func subscribeToAutomaticAppRelaunching(using relaunchPublisher: AnyPublisher<Void, Never>) {
        appWillRelaunchCancellable = relaunchPublisher
            .map { true }
            .assign(to: \.appIsRelaunchingAutomatically, onWeaklyHeld: self)
    }

    var canRestoreLastSessionState: Bool {
        service.canRestoreLastSessionState
    }

    @discardableResult
    func restoreLastSessionState(interactive: Bool, includeRegularTabs: Bool) -> WindowManagerStateRestoration? {
        var state: WindowManagerStateRestoration?
        do {
            let isCalledAtStartup = !interactive
            try service.restoreState(using: { coder in
                state = try WindowsManager.restoreState(from: coder, includeRegularTabs: includeRegularTabs, includePinnedTabs: isCalledAtStartup)
            })
            // rename loaded app state file
            service.didLoadState()
        } catch CocoaError.fileReadNoSuchFile {
            // ignore
        } catch {
            Logger.general.error("App state could not be decoded: \(error.localizedDescription)")
            PixelKit.fire(DebugEvent(GeneralPixel.appStateRestorationFailed, error: error),
                          withAdditionalParameters: ["interactive": String(interactive)])
        }

        return state
    }

    func clearLastSessionState() {
        service.clearState(sync: true)
    }

    // Cleans all stored snapshots except snapshots listed in the state
    func cleanTabSnapshots(state: WindowManagerStateRestoration? = nil) {
        let tabs = state?.windows.flatMap { $0.model.tabCollection.tabs } ?? []
        let perWindowPinnedTabs = state?.windows.flatMap { $0.pinnedTabs?.tabs ?? [] } ?? []
        let applicationPinnedTabs = state?.applicationPinnedTabs?.tabs ?? []
        let stateSnapshotIds = (tabs + perWindowPinnedTabs + applicationPinnedTabs).compactMap { $0.tabSnapshotIdentifier }
        Task {
            await tabSnapshotCleanupService.cleanStoredSnapshots(except: Set(stateSnapshotIds))
        }
    }

    func applicationDidFinishLaunching() {
        let isRelaunchingAutomatically = self.appIsRelaunchingAutomatically
        self.appIsRelaunchingAutomatically = false
        // don‘t automatically restore windows if relaunched 2nd time with no recently updated app session state
        readLastSessionState(restoreWindows: !service.isAppStateFileStale || isRelaunchingAutomatically, restoreRegularTabs: shouldRestoreRegularTabs)

        stateChangedCancellable = Publishers.Merge(
                WindowControllersManager.shared.stateChanged,
                pinnedTabsManagerProvider.settingChangedPublisher
            )
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            // There is a favicon assignment after a restored tab loads that triggered unnecessary
            // saving of the state
            .sink { [weak self] _ in
                self?.persistAppState()
            }
    }

    func applicationWillTerminate() {
        stateChangedCancellable?.cancel()
        if WindowControllersManager.shared.isInInitialState {
            service.clearState(sync: true)
        } else {
            persistAppState(sync: true)
        }
    }

    private func readLastSessionState(restoreWindows: Bool, restoreRegularTabs: Bool) {
        service.loadLastSessionState()
        if restoreWindows {
            let state = restoreLastSessionState(interactive: false, includeRegularTabs: restoreRegularTabs)
            cleanTabSnapshots(state: state)
        } else {
            migratePinnedTabsSettingIfNecessary()
            restorePinnedTabs()
            cleanTabSnapshots()
        }
        WindowControllersManager.shared.updateIsInInitialState()
    }

    @MainActor
    private func restorePinnedTabs() {
        do {
            try service.restoreState(using: { coder in
                try WindowsManager.restoreState(from: coder, includeRegularTabs: false, includeWindows: false)
            })
        } catch CocoaError.fileReadNoSuchFile {
            // ignore
        } catch {
            Logger.general.error("Pinned tabs state could not be decoded: \(error)")
            PixelKit.fire(DebugEvent(GeneralPixel.appStateRestorationFailed, error: error))
        }
    }

    @MainActor
    private func persistAppState(sync: Bool = false) {
        service.persistState(using: WindowControllersManager.shared.encodeState(with:), sync: sync)
    }

    private func migratePinnedTabsSettingIfNecessary() {
        TabsPreferences.shared.migratePinnedTabsSettingIfNecessary(nil)
    }
}
