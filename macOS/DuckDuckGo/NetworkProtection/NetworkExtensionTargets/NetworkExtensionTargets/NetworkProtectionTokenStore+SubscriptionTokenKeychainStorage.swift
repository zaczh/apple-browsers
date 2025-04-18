//
//  NetworkProtectionTokenStore+SubscriptionTokenKeychainStorage.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Subscription
import NetworkProtection
import Common
import os.log

extension NetworkProtectionKeychainTokenStore: SubscriptionTokenStoring {

    public func store(accessToken: String) throws {
        try store(accessToken)
    }

    public func getAccessToken() throws -> String? {
        guard var token = try fetchToken() else { return nil }
        if token.hasPrefix("ddg:") {
            token = token.replacingOccurrences(of: "ddg:", with: "")
        }
        Logger.networkProtection.log("🟢 Wrapper successfully fetched the token")
        return token
    }

    public func removeAccessToken() throws {
        try deleteToken()
    }
}
