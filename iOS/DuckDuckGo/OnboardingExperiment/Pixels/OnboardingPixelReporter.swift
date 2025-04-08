//
//  OnboardingPixelReporter.swift
//  DuckDuckGo
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
import Core
import BrowserServicesKit
import Onboarding
import PixelKit

// MARK: - Pixel Fire Interface

protocol OnboardingPixelFiring {
    static func fire(pixel: Pixel.Event, withAdditionalParameters params: [String: String], includedParameters: [Pixel.QueryParameters])
}

extension Pixel: OnboardingPixelFiring {
    static func fire(pixel: Event, withAdditionalParameters params: [String: String], includedParameters: [QueryParameters]) {
        self.fire(pixel: pixel, withAdditionalParameters: params, includedParameters: includedParameters, onComplete: { _ in })
    }
}

extension UniquePixel: OnboardingPixelFiring {
    static func fire(pixel: Pixel.Event, withAdditionalParameters params: [String: String], includedParameters: [Pixel.QueryParameters]) {
        self.fire(pixel: pixel, withAdditionalParameters: params, includedParameters: includedParameters, onComplete: { _ in })
    }
}

// MARK: - OnboardingPixelReporter

protocol OnboardingIntroImpressionReporting {
    func measureOnboardingIntroImpression()
}

protocol OnboardingIntroPixelReporting: OnboardingIntroImpressionReporting {
    func measureSkipOnboardingCTAAction()
    func measureConfirmSkipOnboardingCTAAction()
    func measureResumeOnboardingCTAAction()
    func measureBrowserComparisonImpression()
    func measureChooseBrowserCTAAction()
    func measureChooseAppIconImpression()
    func measureChooseCustomAppIconColor()
    func measureAddressBarPositionSelectionImpression()
    func measureChooseBottomAddressBarPosition()
}

protocol OnboardingCustomInteractionPixelReporting {
    func measureCustomSearch()
    func measureCustomSite()
    func measureSecondSiteVisit()
    func measurePrivacyDashboardOpenedForFirstTime()
}

protocol OnboardingDaxDialogsReporting {
    func measureScreenImpression(event: Pixel.Event)
    func measureTrySearchDialogNewTabDismissButtonTapped()
    func measureSearchResultDialogDismissButtonTapped()
    func measureTryVisitSiteDialogNewTabDismissButtonTapped()
    func measureTryVisitSiteDialogDismissButtonTapped()
    func measureTrackersDialogDismissButtonTapped()
    func measureFireDialogDismissButtonTapped()
    func measureEndOfJourneyDialogNewTabDismissButtonTapped()
    func measureEndOfJourneyDialogDismissButtonTapped()
    func measurePrivacyPromoDialogNewTabDismissButtonTapped()
    func measureEndOfJourneyDialogCTAAction()
}

protocol OnboardingAddToDockReporting {
    func measureAddToDockPromoImpression()
    func measureAddToDockPromoShowTutorialCTAAction()
    func measureAddToDockPromoDismissCTAAction()
    func measureAddToDockTutorialDismissCTAAction()
}

protocol OnboardingSetAsDefaultBrowserExperimentReporting {
    func measureDidSetDDGAsDefaultBrowser()
    func measureDidNotSetDDGAsDefaultBrowser()
}

typealias LinearOnboardingPixelReporting = OnboardingIntroPixelReporting & OnboardingAddToDockReporting & OnboardingSetAsDefaultBrowserExperimentReporting
typealias OnboardingPixelReporting = LinearOnboardingPixelReporting & OnboardingSearchSuggestionsPixelReporting & OnboardingSiteSuggestionsPixelReporting & OnboardingCustomInteractionPixelReporting & OnboardingDaxDialogsReporting

// MARK: - Implementation

final class OnboardingPixelReporter {
    private let pixel: OnboardingPixelFiring.Type
    private let uniquePixel: OnboardingPixelFiring.Type
    private let statisticsStore: StatisticsStore
    private let experimentPixel: ExperimentPixelFiring.Type
    private let calendar: Calendar
    private let dateProvider: () -> Date
    private let userDefaults: UserDefaults
    private let siteVisitedUserDefaultsKey = "com.duckduckgo.ios.site-visited"

    private(set) var enqueuedPixels: [EnqueuedPixel] = []

    init(
        pixel: OnboardingPixelFiring.Type = Pixel.self,
        uniquePixel: OnboardingPixelFiring.Type = UniquePixel.self,
        experimentPixel: ExperimentPixelFiring.Type = PixelKit.self,
        statisticsStore: StatisticsStore = StatisticsUserDefaults(),
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init,
        userDefaults: UserDefaults = UserDefaults.app
    ) {
        self.pixel = pixel
        self.uniquePixel = uniquePixel
        self.experimentPixel = experimentPixel
        self.statisticsStore = statisticsStore
        self.calendar = calendar
        self.dateProvider = dateProvider
        self.userDefaults = userDefaults
    }

    private func fire(event: Pixel.Event, unique: Bool, additionalParameters: [String: String] = [:], includedParameters: [Pixel.QueryParameters] = [.appVersion]) {
        
        func enqueue(event: Pixel.Event, unique: Bool, additionalParameters: [String: String], includedParameters: [Pixel.QueryParameters]) {
            enqueuedPixels.append(.init(event: event, unique: unique, additionalParameters: additionalParameters, includedParameters: includedParameters))
        }

        // If the Pixel needs the ATB and ATB is available, fire the Pixel immediately. Otherwise enqueue the pixel and process it once the ATB is available.
        // If the Pixel does not need the ATB there's no need to wait for the ATB to become available.
        if includedParameters.contains(.atb) && statisticsStore.atb == nil {
            enqueue(event: event, unique: unique, additionalParameters: additionalParameters, includedParameters: includedParameters)
        } else {
            performFire(event: event, unique: unique, additionalParameters: additionalParameters, includedParameters: includedParameters)
        }
    }

    private func performFire(event: Pixel.Event, unique: Bool, additionalParameters: [String: String], includedParameters: [Pixel.QueryParameters]) {
        if unique {
            uniquePixel.fire(pixel: event, withAdditionalParameters: additionalParameters, includedParameters: includedParameters)
        } else {
            pixel.fire(pixel: event, withAdditionalParameters: additionalParameters, includedParameters: includedParameters)
        }
    }

}

// MARK: - Fire Enqueued Pixels

extension OnboardingPixelReporter {

    func fireEnqueuedPixelsIfNeeded() {
        while !enqueuedPixels.isEmpty {
            let event = enqueuedPixels.removeFirst()
            performFire(event: event.event, unique: event.unique, additionalParameters: event.additionalParameters, includedParameters: event.includedParameters)
        }
    }
}

// MARK: - OnboardingPixelReporter + Intro

extension OnboardingPixelReporter: OnboardingIntroPixelReporting {

    func measureSkipOnboardingCTAAction() {
        fire(event: .onboardingIntroSkipOnboardingCTAPressed, unique: false)
    }

    func measureConfirmSkipOnboardingCTAAction() {
        fire(event: .onboardingIntroConfirmSkipOnboardingCTAPressed, unique: false)
    }

    func measureResumeOnboardingCTAAction() {
        fire(event: .onboardingIntroResumeOnboardingCTAPressed, unique: false)
    }

    func measureOnboardingIntroImpression() {
        fire(event: .onboardingIntroShownUnique, unique: true)
    }

    func measureBrowserComparisonImpression() {
        fire(event: .onboardingIntroComparisonChartShownUnique, unique: true)
    }

    func measureChooseBrowserCTAAction() {
        fire(event: .onboardingIntroChooseBrowserCTAPressed, unique: false)
    }

    func measureChooseAppIconImpression() {
        fire(event: .onboardingIntroChooseAppIconImpressionUnique, unique: true)
    }

    func measureChooseCustomAppIconColor() {
        fire(event: .onboardingIntroChooseCustomAppIconColorCTAPressed, unique: false)
    }

    func measureAddressBarPositionSelectionImpression() {
        fire(event: .onboardingIntroChooseAddressBarImpressionUnique, unique: true)
    }

    func measureChooseBottomAddressBarPosition() {
        fire(event: .onboardingIntroBottomAddressBarSelected, unique: false)
    }

}

// MARK: - OnboardingPixelReporter + List

extension OnboardingPixelReporter: OnboardingSearchSuggestionsPixelReporting {
    
    func measureSearchSuggestionOptionTapped() {
        // Left empty on purpose. These were temporary pixels in iOS. macOS will still use them.
    }

}

extension OnboardingPixelReporter: OnboardingSiteSuggestionsPixelReporting {
    
    func measureSiteSuggestionOptionTapped() {
        // Left empty on purpose. These were temporary pixels in iOS. macOS will still use them.
    }

}

// MARK: - OnboardingPixelReporter + Custom Interaction

extension OnboardingPixelReporter: OnboardingCustomInteractionPixelReporting {

    func measureCustomSearch() {
        fire(event: .onboardingContextualSearchCustomUnique, unique: true)
    }
    
    func measureCustomSite() {
        fire(event: .onboardingContextualSiteCustomUnique, unique: true)
    }
    
    func measureSecondSiteVisit() {
        if userDefaults.bool(forKey: siteVisitedUserDefaultsKey) {
            fire(event: .onboardingContextualSecondSiteVisitUnique, unique: true)
        } else {
            userDefaults.set(true, forKey: siteVisitedUserDefaultsKey)
        }
    }

    func measurePrivacyDashboardOpenedForFirstTime() {
        let daysSinceInstall = statisticsStore.installDate.flatMap { calendar.numberOfDaysBetween($0, and: dateProvider()) }
        let additionalParameters = [
            PixelParameters.fromOnboarding: "true",
            PixelParameters.daysSinceInstall: String(daysSinceInstall ?? 0)
        ]
        fire(event: .privacyDashboardFirstTimeOpenedUnique, unique: true, additionalParameters: additionalParameters, includedParameters: [.appVersion])
    }

}

// MARK: - OnboardingPixelReporter + Screen Impression

extension OnboardingPixelReporter: OnboardingDaxDialogsReporting {
    
    func measureScreenImpression(event: Pixel.Event) {
        fire(event: event, unique: true)
    }

    func measureTrySearchDialogNewTabDismissButtonTapped() {
        fire(event: .onboardingTrySearchDialogNewTabDismissButtonTapped, unique: false)
    }

    func measureSearchResultDialogDismissButtonTapped() {
        fire(event: .onboardingSearchResultDialogDismissButtonTapped, unique: false)
    }

    func measureTryVisitSiteDialogNewTabDismissButtonTapped() {
        fire(event: .onboardingTryVisitSiteDialogNewTabDismissButtonTapped, unique: false)
    }

    func measureTryVisitSiteDialogDismissButtonTapped() {
        fire(event: .onboardingTryVisitSiteDialogDismissButtonTapped, unique: false)
    }

    func measureTrackersDialogDismissButtonTapped() {
        fire(event: .onboardingTrackersDialogDismissButtonTapped, unique: false)
    }

    func measureFireDialogDismissButtonTapped() {
        fire(event: .onboardingFireDialogDismissButtonTapped, unique: false)
    }

    func measureEndOfJourneyDialogNewTabDismissButtonTapped() {
        fire(event: .onboardingEndOfJourneyDialogNewTabDismissButtonTapped, unique: false)
    }

    func measureEndOfJourneyDialogDismissButtonTapped() {
        fire(event: .onboardingEndOfJourneyDialogDismissButtonTapped, unique: false)
    }

    func measurePrivacyPromoDialogNewTabDismissButtonTapped() {
        fire(event: .onboardingPrivacyPromoDialogDismissButtonTapped, unique: false)
    }

    func measureEndOfJourneyDialogCTAAction() {
        fire(event: .daxDialogsEndOfJourneyDismissed, unique: false)
    }

}

// MARK: - OnboardingPixelReporter + Add To Dock

extension OnboardingPixelReporter: OnboardingAddToDockReporting {
   
    func measureAddToDockPromoImpression() {
        fire(event: .onboardingAddToDockPromoImpressionsUnique, unique: true)
    }
    
    func measureAddToDockPromoShowTutorialCTAAction() {
        fire(event: .onboardingAddToDockPromoShowTutorialCTATapped, unique: false)
    }
    
    func measureAddToDockPromoDismissCTAAction() {
        fire(event: .onboardingAddToDockPromoDismissCTATapped, unique: false)
    }
    
    func measureAddToDockTutorialDismissCTAAction() {
        fire(event: .onboardingAddToDockTutorialDismissCTATapped, unique: false)
    }

}

// MARK: - OnboardingPixelReporter + Set As Default Experiment

extension OnboardingPixelReporter: OnboardingSetAsDefaultBrowserExperimentReporting {

    enum SetAsDefaultExperimentMetrics {
        /// Unique identifier for the subfeature being tested.
        static let subfeatureIdentifier = OnboardingSubfeature.setAsDefaultBrowserExperiment.rawValue

        /// Metric identifiers for various user actions during the experiment.
        static let metricDefaultBrowserSet = "setAsDefaultBrowser"
        static let metricDefaultBrowserNotSet = "rejectSetAsDefaultBrowser"

        /// Conversion window in days for tracking user actions.
        static let conversionWindowDays = 0...0
    }

    func measureDidSetDDGAsDefaultBrowser() {
        experimentPixel.fireExperimentPixel(
            for: SetAsDefaultExperimentMetrics.subfeatureIdentifier,
            metric: SetAsDefaultExperimentMetrics.metricDefaultBrowserSet,
            conversionWindowDays: SetAsDefaultExperimentMetrics.conversionWindowDays,
            value: "1"
        )
    }

    func measureDidNotSetDDGAsDefaultBrowser() {
        experimentPixel.fireExperimentPixel(
            for: SetAsDefaultExperimentMetrics.subfeatureIdentifier,
            metric: SetAsDefaultExperimentMetrics.metricDefaultBrowserNotSet,
            conversionWindowDays: SetAsDefaultExperimentMetrics.conversionWindowDays,
            value: "1"
        )
    }
    
}

struct EnqueuedPixel {
    let event: Pixel.Event
    let unique: Bool
    let additionalParameters: [String: String]
    let includedParameters: [Pixel.QueryParameters]
}

#if canImport(XCTest) || DEBUG
extension OnboardingPixelReporter {

    func fireTestPixelWithATB(event: Pixel.Event) {
        fire(event: event, unique: true, includedParameters: [.appVersion, .atb])
    }

}
#endif
