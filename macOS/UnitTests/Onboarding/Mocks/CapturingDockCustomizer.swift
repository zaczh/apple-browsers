//
//  CapturingDockCustomizer.swift
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

import Combine
import Foundation
@testable import DuckDuckGo_Privacy_Browser

class CapturingDockCustomizer: DockCustomization {
    private var featureShownSubject = CurrentValueSubject<Bool, Never>(false)

    var shouldShowNotificationPublisher: AnyPublisher<Bool, Never> {
        featureShownSubject.eraseToAnyPublisher()
    }

    var shouldShowNotification: Bool {
        get { featureShownSubject.value }
        set { featureShownSubject.send(newValue) }
    }

    var isAddedToDock = false

    func addToDock() -> Bool {
        isAddedToDock = true
        return true
    }

    func didCloseMoreOptionsMenu() {
        // No-op
    }

    func resetData() {
        // No-op
    }
}
