//
//  ToolbarStateHandling.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import UIKit
import BrowserServicesKit
import SwiftUICore

enum ToolbarContentState: Equatable {
    case newTab
    case pageLoaded(currentTab: Navigatable)

    static func == (lhs: ToolbarContentState, rhs: ToolbarContentState) -> Bool {
        switch (lhs, rhs) {
        case (.newTab, .newTab):
            return true
        case (.pageLoaded(let lhsTab), .pageLoaded(let rhsTab)):
            return lhsTab.canGoBack == rhsTab.canGoBack && lhsTab.canGoForward == rhsTab.canGoForward
        default:
            return false
        }
    }
}

protocol ToolbarStateHandling {
    func updateToolbarWithState(_ state: ToolbarContentState)
}

final class ToolbarHandler: ToolbarStateHandling {
    weak var toolbar: UIToolbar?
    private let featureFlagger: FeatureFlagger
    let isExperimentalThemingEnabled = ExperimentalThemingManager().isExperimentalThemingEnabled

    lazy var backButton = {
        let imageName = isExperimentalThemingEnabled ? "Arrow-Left-New-24" : "BrowsePrevious"
        return createBarButtonItem(title: UserText.keyCommandBrowserBack, imageName: imageName)
    }()

    let fireButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "Fire-New-24"), for: .normal)
        button.tintColor = .label

        button.frame = CGRect(x: 0, y: 0, width: 84, height: 44)
        button.backgroundColor = UIColor(Color.shade(0.09))
        button.layer.cornerRadius = 14

        button.imageView?.contentMode = .scaleAspectFit
        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center

        return button
    }()

    lazy var fireBarButtonItem = {
        if isExperimentalThemingEnabled {
            let barButtonItem = UIBarButtonItem(customView: fireButton)
            barButtonItem.title = UserText.actionForgetAll
            return barButtonItem
        } else {
            return createBarButtonItem(title: UserText.actionForgetAll, imageName: "Fire")
        }
    }()

    lazy var forwardButton = {
        let imageName = isExperimentalThemingEnabled ? "Arrow-Right-New-24" : "BrowseNext"
        return createBarButtonItem(title: UserText.keyCommandBrowserForward, imageName: imageName)
    }()

    lazy var tabSwitcherButton = {
        let imageName = isExperimentalThemingEnabled ? "Tab-New-24" : "Add-24"
        return createBarButtonItem(title: UserText.tabSwitcherAccessibilityLabel, imageName: imageName)
    }()

    lazy var bookmarkButton = {
        let imageName = isExperimentalThemingEnabled ? "Bookmarks-Stacked-24" : "Book-24"
        return createBarButtonItem(title: UserText.actionOpenBookmarks, imageName: imageName)
    }()

    lazy var passwordsButton = {
        let imageName = isExperimentalThemingEnabled ? "Key-New-24" : "Key-24"
        return createBarButtonItem(title: UserText.actionOpenPasswords, imageName: imageName)
    }()

    lazy var browserMenuButton = {
        let imageName = isExperimentalThemingEnabled ? "Menu-Hamburger-New-24" : "Menu-Horizontal-24"
        return createBarButtonItem(title: UserText.menuButtonHint, imageName: imageName)
    }()

    private var state: ToolbarContentState?

    init(toolbar: UIToolbar, featureFlagger: FeatureFlagger) {
        self.toolbar = toolbar
        self.featureFlagger = featureFlagger
    }

    // MARK: - Public Methods

    func updateToolbarWithState(_ state: ToolbarContentState) {
        guard let toolbar = toolbar else { return }

        updateNavigationButtonsWithState(state)

        /// Avoid unnecessary updates if the state hasn't changed
        guard self.state != state else { return }
        self.state = state

        let buttons: [UIBarButtonItem] = {
            switch state {
            case .pageLoaded:
                return createPageLoadedButtons()
            case .newTab:
                return createNewTabButtons()
            }
        }()

        toolbar.setItems(buttons, animated: false)
    }

    // MARK: - Private Methods

    private func updateNavigationButtonsWithState(_ state: ToolbarContentState) {
        let currentTab: Navigatable? = {
            if case let .pageLoaded(tab) = state {
                return tab
            }
            return nil
        }()

        backButton.isEnabled = currentTab?.canGoBack ?? false
        forwardButton.isEnabled = currentTab?.canGoForward ?? false
    }

    private func createBarButtonItem(title: String, imageName: String) -> UIBarButtonItem {
        return UIBarButtonItem(title: title, image: UIImage(named: imageName), primaryAction: nil)
    }

    private func createPageLoadedButtons() -> [UIBarButtonItem] {
        return [
            backButton,
            .flexibleSpace(),
            forwardButton,
            .flexibleSpace(),
            fireBarButtonItem,
            .flexibleSpace(),
            tabSwitcherButton,
            .flexibleSpace(),
            browserMenuButton
        ]
    }

    private func createNewTabButtons() -> [UIBarButtonItem] {
        if ExperimentalThemingManager().isExperimentalThemingEnabled {
            return [
                passwordsButton,
                .flexibleSpace(),
                bookmarkButton,
                .flexibleSpace(),
                fireBarButtonItem,
                .flexibleSpace(),
                tabSwitcherButton,
                .flexibleSpace(),
                browserMenuButton
            ]
        } else {
            return [
                bookmarkButton,
                .flexibleSpace(),
                passwordsButton,
                .flexibleSpace(),
                fireBarButtonItem,
                .flexibleSpace(),
                tabSwitcherButton,
                .flexibleSpace(),
                browserMenuButton
            ]
        }
    }
}
