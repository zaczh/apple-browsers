//
//  DataBrokerProtectionAgentManager.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import Configuration
import PixelKit
import AppKitExtensions
import os.log
import Freemium
import Subscription
import UserNotifications
import DataBrokerProtectionCore

// This is to avoid exposing all the dependancies outside of the DBP package
public class DataBrokerProtectionAgentManagerProvider {

    private let databaseURL = DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: DatabaseConstants.directoryName, fileName: DatabaseConstants.fileName, appGroupIdentifier: Bundle.main.appGroupName)

    public static func agentManager(authenticationManager: DataBrokerProtectionAuthenticationManaging, vpnBypassService: VPNBypassFeatureProvider) -> DataBrokerProtectionAgentManager? {
        guard let pixelKit = PixelKit.shared else {
            assertionFailure("PixelKit not set up")
            return nil
        }
        let pixelHandler = DataBrokerProtectionMacOSPixelsHandler()
        let sharedPixelsHandler = DataBrokerProtectionSharedPixelsHandler(pixelKit: pixelKit, platform: .macOS)

        let dbpSettings = DataBrokerProtectionSettings(defaults: .dbp)
        let schedulingConfig = DataBrokerMacOSSchedulingConfig(mode: dbpSettings.runType == .integrationTests ? .fastForIntegrationTests : .normal)
        let activityScheduler = DefaultDataBrokerProtectionBackgroundActivityScheduler(config: schedulingConfig)

        let notificationService = DefaultDataBrokerProtectionUserNotificationService(pixelHandler: pixelHandler, userNotificationCenter: UNUserNotificationCenter.current(), authenticationManager: authenticationManager)
        let eventsHandler = DefaultOperationEventsHandler(userNotificationService: notificationService)

        Configuration.setURLProvider(DBPAgentConfigurationURLProvider())
        let configStore = ConfigurationStore()
        let privacyConfigurationManager = DBPPrivacyConfigurationManager()
        let configurationManager = ConfigurationManager(privacyConfigManager: privacyConfigurationManager, store: configStore)
        configurationManager.start()
        // Load cached config (if any)
        privacyConfigurationManager.reload(etag: configStore.loadEtag(for: .privacyConfiguration), data: configStore.loadData(for: .privacyConfiguration))
        let ipcServer = DefaultDataBrokerProtectionIPCServer(machServiceName: Bundle.main.bundleIdentifier!)

        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false,
                                                  unknownUsernameCategorization: false,
                                                  partialFormSaves: false)
        let contentScopeProperties = ContentScopeProperties(gpcEnabled: false,
                                                            sessionKey: UUID().uuidString,
                                                            messageSecret: UUID().uuidString,
                                                            featureToggles: features)

        let fakeBroker = DataBrokerDebugFlagFakeBroker()
        let databaseURL = DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: DatabaseConstants.directoryName, fileName: DatabaseConstants.fileName, appGroupIdentifier: Bundle.main.appGroupName)
        let vaultFactory = createDataBrokerProtectionSecureVaultFactory(appGroupName: Bundle.main.appGroupName, databaseFileURL: databaseURL)

        let reporter = DataBrokerProtectionSecureVaultErrorReporter(pixelHandler: sharedPixelsHandler)

        let vault: DefaultDataBrokerProtectionSecureVault<DefaultDataBrokerProtectionDatabaseProvider>
        do {
            vault = try vaultFactory.makeVault(reporter: reporter)
        } catch let error {
            assertionFailure("Failed to make secure storage vault")
            pixelHandler.fire(.backgroundAgentSetUpFailedSecureVaultInitFailed(error: error))
            return nil
        }

        let database = DataBrokerProtectionDatabase(fakeBrokerFlag: fakeBroker, pixelHandler: sharedPixelsHandler, vault: vault)
        let dataManager = DataBrokerProtectionDataManager(database: database)

        let operationQueue = OperationQueue()
        let operationsBuilder = DefaultDataBrokerOperationsCreator()
        let mismatchCalculator = DefaultMismatchCalculator(database: dataManager.database,
                                                           pixelHandler: sharedPixelsHandler)

        let brokerUpdater = DefaultDataBrokerProtectionBrokerUpdater(vault: vault, pixelHandler: sharedPixelsHandler)
        let queueManager =  DefaultDataBrokerProtectionQueueManager(operationQueue: operationQueue,
                                                                    operationsCreator: operationsBuilder,
                                                                    mismatchCalculator: mismatchCalculator,
                                                                    brokerUpdater: brokerUpdater,
                                                                    pixelHandler: sharedPixelsHandler)

        let backendServicePixels = DefaultDataBrokerProtectionBackendServicePixels(pixelHandler: sharedPixelsHandler,
                                                                                   settings: dbpSettings)
        let emailService = EmailService(authenticationManager: authenticationManager,
                                        settings: dbpSettings,
                                        servicePixel: backendServicePixels)
        let captchaService = CaptchaService(authenticationManager: authenticationManager, settings: dbpSettings, servicePixel: backendServicePixels)
        let runnerProvider = DataBrokerJobRunnerProvider(privacyConfigManager: privacyConfigurationManager,
                                                         contentScopeProperties: contentScopeProperties,
                                                         emailService: emailService,
                                                         captchaService: captchaService)

        let freemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp)

        let agentstopper = DefaultDataBrokerProtectionAgentStopper(dataManager: dataManager,
                                                                   entitlementMonitor: DataBrokerProtectionEntitlementMonitor(),
                                                                   authenticationManager: authenticationManager,
                                                                   pixelHandler: pixelHandler,
                                                                   freemiumDBPUserStateManager: freemiumDBPUserStateManager)

        let executionConfig = DataBrokerExecutionConfig()
        let operationDependencies = DefaultDataBrokerOperationDependencies(
            database: dataManager.database,
            config: executionConfig,
            runnerProvider: runnerProvider,
            notificationCenter: NotificationCenter.default,
            pixelHandler: sharedPixelsHandler,
            eventsHandler: eventsHandler,
            dataBrokerProtectionSettings: dbpSettings,
            vpnBypassService: vpnBypassService)

        return DataBrokerProtectionAgentManager(
            eventsHandler: eventsHandler,
            activityScheduler: activityScheduler,
            ipcServer: ipcServer,
            queueManager: queueManager,
            dataManager: dataManager,
            operationDependencies: operationDependencies,
            sharedPixelsHandler: sharedPixelsHandler,
            pixelHandler: pixelHandler,
            agentStopper: agentstopper,
            configurationManager: configurationManager,
            privacyConfigurationManager: privacyConfigurationManager,
            authenticationManager: authenticationManager,
            freemiumDBPUserStateManager: freemiumDBPUserStateManager)
    }
}

public final class DataBrokerProtectionAgentManager {

    private let eventsHandler: EventMapping<OperationEvent>
    private var activityScheduler: DataBrokerProtectionBackgroundActivityScheduler
    private var ipcServer: DataBrokerProtectionIPCServer
    private let queueManager: DataBrokerProtectionQueueManager
    private let dataManager: DataBrokerProtectionDataManaging
    private let operationDependencies: DataBrokerOperationDependencies
    private let sharedPixelsHandler: EventMapping<DataBrokerProtectionSharedPixels>
    private let pixelHandler: EventMapping<DataBrokerProtectionMacOSPixels>
    private let agentStopper: DataBrokerProtectionAgentStopper
    private let configurationManger: DefaultConfigurationManager
    private let privacyConfigurationManager: DBPPrivacyConfigurationManager
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let freemiumDBPUserStateManager: FreemiumDBPUserStateManager

    // Used for debug functions only, so not injected
    private lazy var browserWindowManager = BrowserWindowManager()

    private var didStartActivityScheduler = false

    init(eventsHandler: EventMapping<OperationEvent>,
         activityScheduler: DataBrokerProtectionBackgroundActivityScheduler,
         ipcServer: DataBrokerProtectionIPCServer,
         queueManager: DataBrokerProtectionQueueManager,
         dataManager: DataBrokerProtectionDataManaging,
         operationDependencies: DataBrokerOperationDependencies,
         sharedPixelsHandler: EventMapping<DataBrokerProtectionSharedPixels>,
         pixelHandler: EventMapping<DataBrokerProtectionMacOSPixels>,
         agentStopper: DataBrokerProtectionAgentStopper,
         configurationManager: DefaultConfigurationManager,
         privacyConfigurationManager: DBPPrivacyConfigurationManager,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         freemiumDBPUserStateManager: FreemiumDBPUserStateManager
    ) {
        self.eventsHandler = eventsHandler
        self.activityScheduler = activityScheduler
        self.ipcServer = ipcServer
        self.queueManager = queueManager
        self.dataManager = dataManager
        self.operationDependencies = operationDependencies
        self.sharedPixelsHandler = sharedPixelsHandler
        self.pixelHandler = pixelHandler
        self.agentStopper = agentStopper
        self.configurationManger = configurationManager
        self.privacyConfigurationManager = privacyConfigurationManager
        self.authenticationManager = authenticationManager
        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager

        self.activityScheduler.delegate = self
        self.ipcServer.serverDelegate = self
        self.ipcServer.activate()
    }

    public func agentFinishedLaunching() {

        Task { @MainActor in
            // The browser shouldn't start the agent if these prerequisites aren't met.
            // However, since the agent can auto-start after a reboot without the browser, we need to validate it again.
            // If the agent needs to be stopped, this function will stop it, so the subsequent calls after it will not be made.
            await agentStopper.validateRunPrerequisitesAndStopAgentIfNecessary()

            activityScheduler.startScheduler()
            didStartActivityScheduler = true
            fireMonitoringPixels()
            startFreemiumOrSubscriptionScheduledOperations(showWebView: false, operationDependencies: operationDependencies, errorHandler: nil, completion: nil)

            /// Monitors entitlement changes every 60 minutes to optimize system performance and resource utilization by avoiding unnecessary operations when entitlement is invalid.
            /// While keeping the agent active with invalid entitlement has no significant risk, setting the monitoring interval at 60 minutes is a good balance to minimize backend checks.
            agentStopper.monitorEntitlementAndStopAgentIfEntitlementIsInvalidAndUserIsNotFreemium(interval: .minutes(60))
        }
    }
}

// MARK: - Regular monitoring pixels

extension DataBrokerProtectionAgentManager {
    func fireMonitoringPixels() {
        // Only send pixels for authenticated users
        guard authenticationManager.isUserAuthenticated else { return }

        let database = operationDependencies.database

        let engagementPixels = DataBrokerProtectionEngagementPixels(database: database, handler: sharedPixelsHandler)
        let eventPixels = DataBrokerProtectionEventPixels(database: database, handler: sharedPixelsHandler)
        let statsPixels = DataBrokerProtectionStatsPixels(database: database, handler: sharedPixelsHandler)

        // This will fire the DAU/WAU/MAU pixels,
        engagementPixels.fireEngagementPixel()
        // This will try to fire the event weekly report pixels
        eventPixels.tryToFireWeeklyPixels()
        // This will try to fire the stats pixels
        statsPixels.tryToFireStatsPixels()

        // If a user upgraded from Freemium, don't send 24-hour opt-out submit pixels
        guard !freemiumDBPUserStateManager.didActivate else { return }

        // Fire custom stats pixels if needed
        statsPixels.fireCustomStatsPixelsIfNeeded()
    }
}

private extension DataBrokerProtectionAgentManager {

    /// Starts either Subscription (scan and opt-out) or Freemium (scan-only) scheduled operations
    /// - Parameters:
    ///   - showWebView: Whether to show the web view or not
    ///   - operationDependencies: Operation dependencies
    ///   - errorHandler: Error handler
    ///   - completion: Completion handler
    func startFreemiumOrSubscriptionScheduledOperations(showWebView: Bool,
                                                        operationDependencies: DataBrokerOperationDependencies,
                                                        errorHandler: ((DataBrokerProtectionJobsErrorCollection?) -> Void)?,
                                                        completion: (() -> Void)?) {
        if authenticationManager.isUserAuthenticated {
            queueManager.startScheduledAllOperationsIfPermitted(showWebView: showWebView, operationDependencies: operationDependencies, errorHandler: errorHandler, completion: completion)
        } else {
            queueManager.startScheduledScanOperationsIfPermitted(showWebView: showWebView, operationDependencies: operationDependencies, errorHandler: errorHandler, completion: completion)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionBackgroundActivitySchedulerDelegate {

    public func dataBrokerProtectionBackgroundActivitySchedulerDidTrigger(_ activityScheduler: DataBrokerProtectionBackgroundActivityScheduler, completion: (() -> Void)?) {
        startScheduledOperations(completion: completion)
    }

    func startScheduledOperations(completion: (() -> Void)?) {
        fireMonitoringPixels()
        startFreemiumOrSubscriptionScheduledOperations(showWebView: false, operationDependencies: operationDependencies, errorHandler: nil) {
            completion?()
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentAppEvents {
    public func profileSaved() {
        let backgroundAgentInitialScanStartTime = Date()

        eventsHandler.fire(.profileSaved)
        fireMonitoringPixels()
        queueManager.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: operationDependencies) { [weak self] errors in
            guard let self = self else { return }

            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    switch oneTimeError {
                    case DataBrokerProtectionQueueError.interrupted:
                        self.pixelHandler.fire(.ipcServerImmediateScansInterrupted)
                        Logger.dataBrokerProtection.error("Interrupted during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateOperationsIfPermitted(), error: \(oneTimeError.localizedDescription, privacy: .public)")
                    default:
                        self.pixelHandler.fire(.ipcServerImmediateScansFinishedWithError(error: oneTimeError))
                        Logger.dataBrokerProtection.error("Error during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateOperationsIfPermitted, error: \(oneTimeError.localizedDescription, privacy: .public)")
                    }
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    Logger.dataBrokerProtection.log("Operation error(s) during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateOperationsIfPermitted, count: \(operationErrors.count, privacy: .public)")
                }
            }

            if errors?.oneTimeError == nil {
                self.pixelHandler.fire(.ipcServerImmediateScansFinishedWithoutError)
                self.eventsHandler.fire(.firstScanCompleted)
            }
        } completion: { [weak self] in
            guard let self else { return }

            if let hasMatches = try? self.dataManager.hasMatches(),
               hasMatches {
                self.eventsHandler.fire(.firstScanCompletedAndMatchesFound)
            }

            fireImmediateScansCompletionPixel(startTime: backgroundAgentInitialScanStartTime)

            self.startScheduledOperations(completion: nil)
        }
    }

    public func appLaunched() {
        fireMonitoringPixels()
        startFreemiumOrSubscriptionScheduledOperations(showWebView: false,
                                                         operationDependencies:
                                                        operationDependencies, errorHandler: { [weak self] errors in
            guard let self = self else { return }

            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    switch oneTimeError {
                    case DataBrokerProtectionQueueError.interrupted:
                        self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansInterrupted)
                        Logger.dataBrokerProtection.log("Interrupted during DataBrokerProtectionAgentManager.appLaunched in queueManager.startScheduledOperationsIfPermitted(), error: \(oneTimeError.localizedDescription, privacy: .public)")
                    case DataBrokerProtectionQueueError.cannotInterrupt:
                        self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansBlocked)
                        Logger.dataBrokerProtection.log("Cannot interrupt during DataBrokerProtectionAgentManager.appLaunched in queueManager.startScheduledOperationsIfPermitted()")
                    default:
                        self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansFinishedWithError(error: oneTimeError))
                        Logger.dataBrokerProtection.log("Error during DataBrokerProtectionAgentManager.appLaunched in queueManager.startScheduledOperationsIfPermitted, error: \(oneTimeError.localizedDescription, privacy: .public)")
                    }
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    Logger.dataBrokerProtection.log("Operation error(s) during DataBrokerProtectionAgentManager.profileSaved in queueManager.startImmediateOperationsIfPermitted, count: \(operationErrors.count, privacy: .public)")
                }
            }

            if errors?.oneTimeError == nil {
                self.pixelHandler.fire(.ipcServerAppLaunchedScheduledScansFinishedWithoutError)
            }
        }, completion: nil)
    }

    private func fireImmediateScansCompletionPixel(startTime: Date) {
        do {
            let profileQueries = try dataManager.profileQueriesCount()
            let durationSinceStart = Date().timeIntervalSince(startTime) * 1000
            self.sharedPixelsHandler.fire(.initialScanTotalDuration(duration: durationSinceStart.rounded(.towardZero),
                                                             profileQueries: profileQueries))
        } catch {
            Logger.dataBrokerProtection.log("Initial Scans Error when trying to fetch the profile to get the profile queries")
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAgentDebugCommands {
    public func openBrowser(domain: String) {
        Task { @MainActor in
            browserWindowManager.show(domain: domain)
        }
    }

    public func startImmediateOperations(showWebView: Bool) {
        queueManager.startImmediateScanOperationsIfPermitted(showWebView: showWebView,
                                                         operationDependencies: operationDependencies,
                                                         errorHandler: nil,
                                                         completion: nil)
    }

    public func startScheduledOperations(showWebView: Bool) {
        startFreemiumOrSubscriptionScheduledOperations(showWebView: showWebView,
                                                         operationDependencies: operationDependencies,
                                                         errorHandler: nil,
                                                         completion: nil)
    }

    public func runAllOptOuts(showWebView: Bool) {
        queueManager.execute(.startOptOutOperations(showWebView: showWebView,
                                                    operationDependencies: operationDependencies,
                                                    errorHandler: nil,
                                                    completion: nil))
    }

    public func getDebugMetadata() async -> DBPBackgroundAgentMetadata? {

        if let backgroundAgentVersion = Bundle.main.releaseVersionNumber,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {

            return DBPBackgroundAgentMetadata(backgroundAgentVersion: backgroundAgentVersion + " (build: \(buildNumber))",
                                              isAgentRunning: true,
                                              agentSchedulerState: queueManager.debugRunningStatusString,
                                              lastSchedulerSessionStartTimestamp: activityScheduler.lastTriggerTimestamp?.timeIntervalSince1970)
        } else {
            return DBPBackgroundAgentMetadata(backgroundAgentVersion: "ERROR: Error fetching background agent version",
                                              isAgentRunning: true,
                                              agentSchedulerState: queueManager.debugRunningStatusString,
                                              lastSchedulerSessionStartTimestamp: activityScheduler.lastTriggerTimestamp?.timeIntervalSince1970)
        }
    }
}

extension DataBrokerProtectionAgentManager: DataBrokerProtectionAppToAgentInterface {

}
