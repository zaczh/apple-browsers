//
//  TipKitAppEventHandling.swift
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
import BrowserServicesKit
import os.log
import TipKit

protocol TipKitAppEventHandling {
    func appDidFinishLaunching()
}

struct TipKitAppEventHandler: TipKitAppEventHandling {

    private let controller: TipKitController
    private let featureFlagger: FeatureFlagger
    private let logger: Logger

    init(controller: TipKitController = .make(),
         featureFlagger: FeatureFlagger,
         logger: Logger = .tipKit) {

        self.controller = controller
        self.featureFlagger = featureFlagger
        self.logger = logger
    }

    func appDidFinishLaunching() {
        if #available(macOS 14.0, *) {
            controller.configureTipKit([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        } else {
            logger.log("TipKit initialization skipped: macOS 14.0 or later is required.")
        }
    }
}
