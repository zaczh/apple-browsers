//
//  DataBrokerJobRunner.swift
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
import BrowserServicesKit
import Common
import os.log

public protocol WebJobRunner {

    func scan(_ profileQuery: BrokerProfileQueryData,
              stageCalculator: StageDurationCalculator,
              pixelHandler: EventMapping<DataBrokerProtectionSharedPixels>,
              showWebView: Bool,
              shouldRunNextStep: @escaping () -> Bool) async throws -> [ExtractedProfile]

    func optOut(profileQuery: BrokerProfileQueryData,
                extractedProfile: ExtractedProfile,
                stageCalculator: StageDurationCalculator,
                pixelHandler: EventMapping<DataBrokerProtectionSharedPixels>,
                showWebView: Bool,
                shouldRunNextStep: @escaping () -> Bool) async throws
}

@MainActor
public final class DataBrokerJobRunner: WebJobRunner {
    let privacyConfigManager: PrivacyConfigurationManaging
    let contentScopeProperties: ContentScopeProperties
    let emailService: EmailServiceProtocol
    let captchaService: CaptchaServiceProtocol

    internal init(privacyConfigManager: PrivacyConfigurationManaging,
                  contentScopeProperties: ContentScopeProperties,
                  emailService: EmailServiceProtocol,
                  captchaService: CaptchaServiceProtocol) {
        self.privacyConfigManager = privacyConfigManager
        self.contentScopeProperties = contentScopeProperties
        self.emailService = emailService
        self.captchaService = captchaService
    }

    public func scan(_ profileQuery: BrokerProfileQueryData,
                     stageCalculator: StageDurationCalculator,
                     pixelHandler: EventMapping<DataBrokerProtectionSharedPixels>,
                     showWebView: Bool,
                     shouldRunNextStep: @escaping () -> Bool) async throws -> [ExtractedProfile] {
        let scan = ScanJob(
            privacyConfig: privacyConfigManager,
            prefs: contentScopeProperties,
            query: profileQuery,
            emailService: emailService,
            captchaService: captchaService,
            stageDurationCalculator: stageCalculator,
            pixelHandler: pixelHandler,
            shouldRunNextStep: shouldRunNextStep
        )
        return try await scan.run(inputValue: (), showWebView: showWebView)
    }

    public func optOut(profileQuery: BrokerProfileQueryData,
                       extractedProfile: ExtractedProfile,
                       stageCalculator: StageDurationCalculator,
                       pixelHandler: EventMapping<DataBrokerProtectionSharedPixels>,
                       showWebView: Bool,
                       shouldRunNextStep: @escaping () -> Bool) async throws {
        let optOut = OptOutJob(
            privacyConfig: privacyConfigManager,
            prefs: contentScopeProperties,
            query: profileQuery,
            emailService: emailService,
            captchaService: captchaService,
            stageCalculator: stageCalculator,
            pixelHandler: pixelHandler,
            shouldRunNextStep: shouldRunNextStep
        )
        try await optOut.run(inputValue: extractedProfile, showWebView: showWebView)
    }

    deinit {
        Logger.dataBrokerProtection.log("WebOperationRunner Deinit")
    }
}
