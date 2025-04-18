//
//  VPNLogger.swift
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
import os.log

/// Logger for the VPN
///
/// Since we'll want to ensure this adheres to our privacy standards, grouping the logging logic to be mostly
/// handled by a single class sounds like a good approach to be able to review what's being logged..
///
@available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
public final class VPNLogger {
    public typealias AttemptStep = PacketTunnelProvider.AttemptStep
    public typealias ConnectionAttempt = PacketTunnelProvider.ConnectionAttempt
    public typealias ConnectionTesterStatus = PacketTunnelProvider.ConnectionTesterStatus

    public init() {}

    @available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
    public func logStartingWithoutAuthToken() {
        Logger.networkProtection.error("🔴 Starting tunnel without an auth token")
    }

    @available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
    public func log(_ step: AttemptStep, named name: String) {
        switch step {
        case .begin:
            Logger.networkProtection.log("🔵 \(name, privacy: .public) attempt begins")
        case .failure(let error):
            Logger.networkProtection.error("🔴 \(name, privacy: .public) attempt failed with error: \(error.localizedDescription, privacy: .public)")
        case .success:
            Logger.networkProtection.log("🟢 \(name, privacy: .public) attempt succeeded")
        }
    }

    @available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
    public func log(_ step: ConnectionAttempt) {
        switch step {
        case .connecting:
            Logger.networkProtection.log("🔵 Connection attempt detected")
        case .failure:
            Logger.networkProtection.error("🔴 Connection attempt failed")
        case .success:
            Logger.networkProtection.log("🟢 Connection attempt successful")
        }
    }

    @available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
    public func log(_ status: ConnectionTesterStatus, server: String) {
        switch status {
        case .failed(let duration):
            Logger.networkProtectionConnectionTester.error("🔴 Connection tester (\(duration.rawValue, privacy: .public) - \(server, privacy: .public)) failure")
        case .recovered(let duration, let failureCount):
            Logger.networkProtectionConnectionTester.log("🟢 Connection tester (\(duration.rawValue, privacy: .public) - \(server, privacy: .public)) recovery (after \(String(failureCount), privacy: .public) failures)")
        }
    }

    @available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
    public func log(_ step: FailureRecoveryStep) {
        switch step {
        case .started:
            Logger.networkProtectionTunnelFailureMonitor.log("🔵 Failure Recovery attempt started")
        case .failed(let error):
            Logger.networkProtectionTunnelFailureMonitor.error("🔴 Failure Recovery attempt failed with error: \(error.localizedDescription, privacy: .public)")
        case .completed(let health):
            switch health {
            case .healthy:
                Logger.networkProtectionTunnelFailureMonitor.log("🟢 Failure Recovery attempt completed")
            case .unhealthy:
                Logger.networkProtectionTunnelFailureMonitor.error("🔴 Failure Recovery attempt ended as unhealthy")
            }
        }
    }

    @available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
    public func log(_ step: NetworkProtectionTunnelFailureMonitor.Result) {
        switch step {
        case .failureDetected:
            Logger.networkProtectionTunnelFailureMonitor.error("🔴 Tunnel failure detected")
        case .failureRecovered:
            Logger.networkProtectionTunnelFailureMonitor.log("🟢 Tunnel failure recovered")
        case .networkPathChanged:
            Logger.networkProtectionTunnelFailureMonitor.log("🔵 Tunnel recovery detected path change")
        }
    }

    @available(*, deprecated, message: "This goes against Apple logging guidelines and will be removed, please don't use it anymore")
    public func log(_ result: NetworkProtectionLatencyMonitor.Result) {
        switch result {
        case .error:
            Logger.networkProtectionLatencyMonitor.error("🔴 There was an error logging the latency")
        case .quality(let quality):
            Logger.networkProtectionLatencyMonitor.log("Connection quality is: \(quality.rawValue, privacy: .public)")
        }
    }
}
