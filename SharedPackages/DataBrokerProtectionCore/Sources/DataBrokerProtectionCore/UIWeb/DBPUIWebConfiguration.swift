//
//  DBPUIWebConfiguration.swift
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
import WebKit
import BrowserServicesKit
import UserScript

public final class DBPUIUserContentController: WKUserContentController {

    public let dbpUIUserScripts: DBPUIUserScript

    @MainActor
    init(with privacyConfigurationManager: PrivacyConfigurationManaging,
         prefs: ContentScopeProperties,
         delegate: DBPUICommunicationDelegate,
         webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable,
         vpnBypassService: VPNBypassServiceProvider?) {

        dbpUIUserScripts = DBPUIUserScript(privacyConfig: privacyConfigurationManager,
                                           prefs: prefs,
                                           delegate: delegate,
                                           webUISettings: webUISettings,
                                           vpnBypassService: vpnBypassService)

        super.init()

        dbpUIUserScripts.userScripts.forEach {
            let userScript = $0.makeWKUserScriptSync()
            self.installUserScripts([userScript], handlers: [$0])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    private func installUserScripts(_ wkUserScripts: [WKUserScript], handlers: [UserScript]) {
        handlers.forEach { self.addHandler($0) }
        wkUserScripts.forEach(self.addUserScript)
    }
}

@MainActor
public final class DBPUIUserScript: UserScriptsProvider {
    public lazy var userScripts: [UserScript] = [contentScopeUserScriptIsolated]

    let contentScopeUserScriptIsolated: ContentScopeUserScript
    public var dbpUICommunicationLayer: DBPUICommunicationLayer
    private let webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable

    init(privacyConfig: PrivacyConfigurationManaging,
         prefs: ContentScopeProperties,
         delegate: DBPUICommunicationDelegate,
         webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable,
         vpnBypassService: VPNBypassServiceProvider?) {
        self.webUISettings = webUISettings
        contentScopeUserScriptIsolated = ContentScopeUserScript(privacyConfig, properties: prefs, isIsolated: false, privacyConfigurationJSONGenerator: nil)
        contentScopeUserScriptIsolated.messageNames = ["dbpui"]
        dbpUICommunicationLayer = DBPUICommunicationLayer(webURLSettings: webUISettings,
                                                          vpnBypassService: vpnBypassService,
                                                          privacyConfig: privacyConfig)
        dbpUICommunicationLayer.delegate = delegate
        dbpUICommunicationLayer.broker = contentScopeUserScriptIsolated.broker
        contentScopeUserScriptIsolated.registerSubfeature(delegate: dbpUICommunicationLayer)
    }

    @MainActor
    public func loadWKUserScripts() async -> [WKUserScript] {
        return await withTaskGroup(of: WKUserScriptBox.self) { @MainActor group in
            var wkUserScripts = [WKUserScript]()
            userScripts.forEach { userScript in
                group.addTask { @MainActor in
                    await userScript.makeWKUserScript()
                }
            }
            for await result in group {
                wkUserScripts.append(result.wkUserScript)
            }

            return wkUserScripts
        }
    }
}

extension WKWebViewConfiguration {

    @MainActor
    public func applyDBPUIConfiguration(privacyConfig: PrivacyConfigurationManaging,
                                        prefs: ContentScopeProperties,
                                        delegate: DBPUICommunicationDelegate,
                                        webUISettings: DataBrokerProtectionWebUIURLSettingsRepresentable,
                                        vpnBypassService: VPNBypassServiceProvider?) {
        preferences.isFraudulentWebsiteWarningEnabled = false
        let userContentController = DBPUIUserContentController(with: privacyConfig,
                                                               prefs: prefs,
                                                               delegate: delegate,
                                                               webUISettings: webUISettings,
                                                               vpnBypassService: vpnBypassService)
        self.userContentController = userContentController
     }
}
