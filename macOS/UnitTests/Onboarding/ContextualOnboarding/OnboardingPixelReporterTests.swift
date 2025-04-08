//
//  OnboardingPixelReporterTests.swift
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

import XCTest
import PixelKit
import Navigation
@testable import DuckDuckGo_Privacy_Browser

final class OnboardingPixelReporterTests: XCTestCase {

    var reporter: OnboardingPixelReporter!
    var onboardingState: MockContextualOnboardingState!
    var eventSent: PixelKitEventV2?
    var frequency: PixelKit.Frequency?
    var userDefaults: UserDefaults?

    override func setUpWithError() throws {
        onboardingState = MockContextualOnboardingState()
        userDefaults = UserDefaults(suiteName: "OnboardingPixelReporterTests") ?? UserDefaults.standard
        reporter = OnboardingPixelReporter(onboardingStateProvider: onboardingState, userDefaults: userDefaults!, fireAction: { [weak self] event, frequency  in
            self?.eventSent = event
            self?.frequency = frequency
        })
    }

    override func tearDownWithError() throws {
        onboardingState = nil
        reporter = nil
        eventSent = nil
        frequency = nil
        userDefaults?.removePersistentDomain(forName: "OnboardingPixelReporterTests")
    }

    func test_WhenMeasureSiteSuggestionOptionTapped_ThenSiteSuggestionOptionTappedEventSent() throws {
        reporter.measureSiteSuggestionOptionTapped()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.siteSuggestionOptionTapped.name)
        XCTAssertEqual(frequency, .uniqueByName)
    }

    func test_WhenMeasureSearchSuggestionOptionTapped_ThenSearchSuggestionOptionTappedEventSent() throws {
        reporter.measureSearchSuggestionOptionTapped()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.searchSuggestionOptionTapped.name)
        XCTAssertEqual(frequency, .uniqueByName)
    }

    func test_WhenMeasureAddressBarTypedIn_ThenDependingOnTheState_CorrectPixelsAreSent() throws {
        for state in ContextualOnboardingState.allCases {
            eventSent = nil
            frequency = nil
            onboardingState.state = state
            reporter.measureAddressBarTypedIn()
            if state == .showTryASearch {
                XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingSearchCustom.name)
                XCTAssertEqual(frequency, .uniqueByName)
            } else if state == .showTryASite {
                XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingVisitSiteCustom.name)
                XCTAssertEqual(frequency, .uniqueByName)
            } else {
                XCTAssertNil(eventSent)
                XCTAssertNil(frequency)
            }
        }
    }

    func test_WhenMeasureFireButtonSkipped_ThenOnboardingFireButtonPromptSkipPressedSent() {
        reporter.measureFireButtonSkipped()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingFireButtonPromptSkipPressed.name)
        XCTAssertEqual(frequency, .uniqueByName)
    }

    func test_WhenMeasureFireButtonTryIt_ThenOnboardingFireButtonTryItPressedSent() {
        reporter.measureFireButtonTryIt()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingFireButtonTryItPressed.name)
        XCTAssertEqual(frequency, .uniqueByName)
    }

    func test_WhenMeasureLastDialogShown_ThenOnboardingFinishedSent() {
        reporter.measureLastDialogShown()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingFinished.name)
        XCTAssertEqual(frequency, .uniqueByName)
    }

    func test_WhenMeasureFireButtonPressed_AndOnboardingNotCompleted_ThenOnboardingFireButtonPressedSent() {
        onboardingState.state = .showFireButton
        reporter.measureFireButtonPressed()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingFireButtonPressed.name)
        XCTAssertEqual(frequency, .uniqueByName)
    }

    func test_WhenMeasureFireButtonPressed_AndOnboardingCompleted_ThenNoPixelSent() {
        onboardingState.state = .onboardingCompleted
        reporter.measureFireButtonPressed()
        XCTAssertNil(eventSent)
        XCTAssertNil(frequency)
    }

    func test_WhenMeasurePrivacyDashboardOpened_AndOnboardingNotCompleted_ThenOnboardingFireButtonPressedSent() {
        onboardingState.state = .showBlockedTrackers
        reporter.measurePrivacyDashboardOpened()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.onboardingPrivacyDashboardOpened.name)
        XCTAssertEqual(frequency, .uniqueByName)
    }

    func test_WhenMeasurePrivacyDashboardOpened_AndOnboardingCompleted_ThenNoPixelSent() {
        onboardingState.state = .onboardingCompleted
        reporter.measurePrivacyDashboardOpened()
        XCTAssertNil(eventSent)
        XCTAssertNil(frequency)
    }

    func test_WhenMeasureSiteVisited_ThenSecondSiteVisitedSentOnlyTheSecondTime() {
        reporter.measureSiteVisited()
        XCTAssertNil(eventSent)
        XCTAssertNil(frequency)

        reporter.measureSiteVisited()
        XCTAssertEqual(eventSent?.name, ContextualOnboardingPixel.secondSiteVisited.name)
        XCTAssertEqual(frequency, .uniqueByName)
        eventSent = nil
        frequency = nil
    }

    // Tab Onboarding Pixel test
    @MainActor
    func test_WhenNavigationDidFinish_ThenReporterMeasureSiteVisitedCalled() {
        let capturingReporter = CapturingOnboardingPixelReporter()
        let tab = Tab(content: .newtab, onboardingPixelReporter: capturingReporter)

        tab.navigationDidFinish(Navigation(identity: .expected, responders: .init(), state: .approved, isCurrent: true))

        XCTAssertTrue(capturingReporter.measureSiteVisitedCalled)
    }

}

class MockContextualOnboardingState: ContextualOnboardingStateUpdater {

    var state: ContextualOnboardingState = .onboardingCompleted

    func updateStateFor(tab: Tab) {
    }

    func gotItPressed() {
    }

    func fireButtonUsed() {
    }

    func turnOffFeature() {}

}
