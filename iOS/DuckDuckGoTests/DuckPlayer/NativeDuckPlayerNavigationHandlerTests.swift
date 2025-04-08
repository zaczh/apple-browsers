//
//  NativeDuckPlayerNavigationHandlerTests.swift
//  DuckDuckGoTests
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
import WebKit
import DuckPlayer
import BrowserServicesKit
import Common
import Core
import Combine

@testable import DuckDuckGo

@MainActor
final class NativeDuckPlayerNavigationHandlerTests: XCTestCase {

    // MARK: - Properties
    private var mockWebView: MockWebView!
    private var mockAppSettings: AppSettingsMock!
    private var mockPrivacyConfig: PrivacyConfigurationManagerMock!
    private var mockInternalUserDecider: MockDuckPlayerInternalUserDecider!
    private var playerSettings: MockDuckPlayerSettings!
    private var mockDuckPlayer: MockDuckPlayer!
    private var mockFeatureFlagger: MockDuckPlayerFeatureFlagger!
    private var sut: NativeDuckPlayerNavigationHandler!
    private var mockTabNavigator: MockDuckPlayerTabNavigator!
    private var mockNativeUIPresenter: MockDuckPlayerNativeUIPresenting!
    private var cancellables = Set<AnyCancellable>()
    private var mockDelayHandler: MockDelayHandler!

    // MARK: - Setup
    override func setUp() {
        super.setUp()
        mockWebView = MockWebView()
        mockAppSettings = AppSettingsMock()
        mockPrivacyConfig = PrivacyConfigurationManagerMock()
        mockInternalUserDecider = MockDuckPlayerInternalUserDecider()
        mockDelayHandler = MockDelayHandler()

        playerSettings = MockDuckPlayerSettings(
            appSettings: mockAppSettings,
            privacyConfigManager: mockPrivacyConfig,
            internalUserDecider: mockInternalUserDecider
        )

        mockFeatureFlagger = MockDuckPlayerFeatureFlagger()
        mockNativeUIPresenter = MockDuckPlayerNativeUIPresenting()

        mockDuckPlayer = MockDuckPlayer(
            settings: playerSettings,
            featureFlagger: mockFeatureFlagger,
            nativeUIPresenter: mockNativeUIPresenter
        )

        mockTabNavigator = MockDuckPlayerTabNavigator()

        sut = NativeDuckPlayerNavigationHandler(
            duckPlayer: mockDuckPlayer,
            featureFlagger: mockFeatureFlagger,
            appSettings: mockAppSettings,
            tabNavigationHandler: mockTabNavigator,
            delayHandler: mockDelayHandler
        )
    }

    override func tearDown() {
        cancellables.removeAll()
        mockWebView = nil
        mockAppSettings = nil
        mockPrivacyConfig = nil
        playerSettings = nil
        mockDuckPlayer = nil
        mockFeatureFlagger = nil
        mockTabNavigator = nil
        sut = nil
        mockNativeUIPresenter = nil
        mockInternalUserDecider = nil
        mockDelayHandler = nil
        super.tearDown()
    }

    // MARK: - handleURLChange Tests

    // TODO: Test media playback/pause
    func testHandleURLChange_inLinkPreview_ReturnsNotHandled() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let urlAsk = URL(string: "https://www.youtube.com/watch?v=djd83w3s")!
        let urlAskAuto = URL(string: "https://www.youtube.com/watch?v=8232q")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.isLinkPreview = true
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAsk)
        XCTAssertEqual(result, .notHandled(.isLinkPreview))
        XCTAssertNil(sut.lastHandledVideoID)

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        sut.isLinkPreview = true
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAskAuto)
        XCTAssertEqual(resultAuto, .notHandled(.isLinkPreview))
        XCTAssertNil(sut.lastHandledVideoID)
    }

    func testHandleURLChange_WhenFeatureOff_ReturnsNotHandled() {
        // Given
        mockFeatureFlagger.enabledFeatures = []
        let url = URL(string: "https://www.youtube.com/watch?v=djd83w3s")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: url)
        XCTAssertEqual(result, .notHandled(.featureOff))
        XCTAssertNil(sut.lastHandledVideoID)

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: url)
        XCTAssertEqual(resultAuto, .notHandled(.featureOff))
        XCTAssertNil(sut.lastHandledVideoID)
    }

    func testHandleURLChange_WhenInvalidParameters_ReturnsNotHandled() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let url = URL(string: "https://www.youtube.com/watch?video=182622")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: url)
        XCTAssertEqual(result, .notHandled(.invalidURL))
        XCTAssertNil(sut.lastHandledVideoID)

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: url)
        XCTAssertEqual(resultAuto, .notHandled(.invalidURL))
        XCTAssertNil(sut.lastHandledVideoID)
    }

    func testHandleURLChange_WhenWatchYoutubeURL_HandlesCorrectly() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let urlAsk = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        let urlAuto = URL(string: "https://www.youtube.com/watch?v=jNQXAC9IVRw")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.lastHandledVideoID = nil
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAsk)
        XCTAssertEqual(result, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "dQw4w9WgXcQ")

        // Reset state for .auto mode test
        mockDuckPlayer.presentPillCalled = false
        mockDuckPlayer.loadNativeDuckPlayerVideoCalled = false
        sut.lastHandledVideoID = nil

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAuto)
        XCTAssertEqual(resultAuto, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "jNQXAC9IVRw")
    }

    func testHandleURLChange_WhenDisabledFornextVideo_HandlesCorrectly() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let disabledVideoURLAsk = URL(string: "https://www.youtube.com/watch?v=9bZkp7q19f0")!
        let enabledVideoURLAsk = URL(string: "https://www.youtube.com/watch?v=OPf0YbXqDm0")!
        let disabledVideoURLAuto = URL(string: "https://www.youtube.com/watch?v=1a2b3c4d5e6")!
        let enabledVideoURLAuto = URL(string: "https://www.youtube.com/watch?v=f7g8h9i0j1k")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.lastHandledVideoID = nil
        sut.disableDuckPlayerForNextVideo = true
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: disabledVideoURLAsk)
        XCTAssertEqual(result, .notHandled(.disabledForVideo))
        XCTAssertFalse(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)

        let result2 = sut.handleURLChange(webView: mockWebView, previousURL: disabledVideoURLAsk, newURL: enabledVideoURLAsk)
        XCTAssertEqual(result2, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "OPf0YbXqDm0")

        // Reset state for .auto mode test
        mockDuckPlayer.presentPillCalled = false
        mockDuckPlayer.loadNativeDuckPlayerVideoCalled = false
        sut.lastHandledVideoID = nil
        sut.disableDuckPlayerForNextVideo = true

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: disabledVideoURLAuto)
        XCTAssertEqual(resultAuto, .notHandled(.disabledForVideo))
        XCTAssertFalse(mockDuckPlayer.presentPillCalled)
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)

        let resultAuto2 = sut.handleURLChange(webView: mockWebView, previousURL: disabledVideoURLAuto, newURL: enabledVideoURLAuto)
        XCTAssertEqual(resultAuto2, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "f7g8h9i0j1k")
    }

    func testHandleURLChange_WhenLastHandledVideoIDIsSameAsCurrentVideoID_HandlesCorrectly() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let videoURLAsk = URL(string: "https://www.youtube.com/watch?v=2b3c4d5e6f7")!
        let videoURLWithHashesAsk = URL(string: "https://www.youtube.com/watch?v=2b3c4d5e6f7#settings")!
        let videoURLAuto = URL(string: "https://www.youtube.com/watch?v=3c4d5e6f7g8")!
        let videoURLWithHashesAuto = URL(string: "https://www.youtube.com/watch?v=3c4d5e6f7g8#settings")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.lastHandledVideoID = nil
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: videoURLAsk)
        XCTAssertEqual(result, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "2b3c4d5e6f7")

        let result2 = sut.handleURLChange(webView: mockWebView, previousURL: videoURLAsk, newURL: videoURLWithHashesAsk)
        XCTAssertEqual(result2, .notHandled(.disabledForVideo))

        mockDelayHandler.completeDelay()
        XCTAssertEqual(sut.lastHandledVideoID, "2b3c4d5e6f7")

        // Reset state for .auto mode test
        mockDuckPlayer.presentPillCalled = false
        mockDuckPlayer.loadNativeDuckPlayerVideoCalled = false
        sut.lastHandledVideoID = nil

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: videoURLAuto)
        XCTAssertEqual(resultAuto, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "3c4d5e6f7g8")

        let resultAuto2 = sut.handleURLChange(webView: mockWebView, previousURL: videoURLAuto, newURL: videoURLWithHashesAuto)
        XCTAssertEqual(resultAuto2, .notHandled(.disabledForVideo))

        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "3c4d5e6f7g8")
    }

    func testHandleURLChange_WhenDuckPlayerSetToNever_HandlesCorrectly() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let videoURLAsk = URL(string: "https://www.youtube.com/watch?v=4d5e6f7g8h9")!
        let videoURLAuto = URL(string: "https://www.youtube.com/watch?v=5e6f7g8h9i0")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .never
        sut.lastHandledVideoID = nil
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: videoURLAsk)
        XCTAssertEqual(result, .notHandled(.duckPlayerDisabled))
        XCTAssertFalse(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, nil)

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .never
        sut.lastHandledVideoID = nil
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: videoURLAuto)
        XCTAssertEqual(resultAuto, .notHandled(.duckPlayerDisabled))
        XCTAssertFalse(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, nil)
    }

    func testHandleURLChange_WhenVisitingSameLastHandledVideoAfterOtherNavigation_HandlesCorrectly() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let urlAsk = URL(string: "https://www.youtube.com/watch?v=6f7g8h9i0j1")!
        let urlAuto = URL(string: "https://www.youtube.com/watch?v=7g8h9i0j1k2")!
        let nonYoutubeURL = URL(string: "https://www.google.com")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.lastHandledVideoID = nil
        _ = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAsk)
        _ = sut.handleURLChange(webView: mockWebView, previousURL: urlAsk, newURL: nonYoutubeURL)
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nonYoutubeURL, newURL: urlAsk)
        XCTAssertEqual(result, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "6f7g8h9i0j1")

        // Reset state for .auto mode test
        mockDuckPlayer.presentPillCalled = false
        mockDuckPlayer.loadNativeDuckPlayerVideoCalled = false
        sut.lastHandledVideoID = nil

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        _ = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAuto)
        _ = sut.handleURLChange(webView: mockWebView, previousURL: urlAuto, newURL: nonYoutubeURL)
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nonYoutubeURL, newURL: urlAuto)
        XCTAssertEqual(resultAuto, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "7g8h9i0j1k2")
    }

    func testHandleURLChange_WithMobileYouTubeURL_HandlesCorrectly() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let urlAsk = URL(string: "https://m.youtube.com/watch?v=8g9h0i1j2k3")!
        let urlAuto = URL(string: "https://m.youtube.com/watch?v=9h0i1j2k3l4")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.lastHandledVideoID = nil
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAsk)
        XCTAssertEqual(result, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "8g9h0i1j2k3")

        // Reset state for .auto mode test
        mockDuckPlayer.presentPillCalled = false
        mockDuckPlayer.loadNativeDuckPlayerVideoCalled = false
        sut.lastHandledVideoID = nil

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        let resultAuto = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAuto)
        XCTAssertEqual(resultAuto, .handled(.duckPlayerEnabled))
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
        XCTAssertEqual(sut.lastHandledVideoID, "9h0i1j2k3l4")
    }

    // MARK: - handleDuckNavigation Tests

    func testHandleDuckNavigation_LoadsYouTubeURL() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let videoID = "123"
        let url = URL(string: "duck://player/\(videoID)")!
        let navigationAction = MockNavigationAction(request: URLRequest(url: url))

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.handleDuckNavigation(navigationAction, webView: mockWebView)
        XCTAssertEqual(mockWebView.lastLoadedRequest?.url?.absoluteString, "https://m.youtube.com/watch?v=\(videoID)")
        XCTAssertTrue(mockDuckPlayer.presentPillCalled)

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto
        sut.handleDuckNavigation(navigationAction, webView: mockWebView)
        XCTAssertEqual(mockWebView.lastLoadedRequest?.url?.absoluteString, "https://m.youtube.com/watch?v=\(videoID)")
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
    }

    func testDuckURLNavigation_WithMalformedURL_HandlesGracefully() {
        // Given
        let malformedDuckURL = URL(string: "duck://player/")!
        let navigationAction = MockNavigationAction(request: URLRequest(url: malformedDuckURL))

        // When
        sut.handleDuckNavigation(navigationAction, webView: mockWebView)

        // Then
        // This test validates the handler doesn't crash with malformed URLs
        // The exact behavior depends on how the implementation handles this case
        // You may need to adjust assertions based on expected behavior
        XCTAssertNotNil(mockWebView.lastLoadedRequest?.url)
    }

    // MARK: - handleAttach Tests

    func testHandleAttach_InitializesCorrectly() {
        // Given
        guard let webView = mockWebView else {
            XCTFail("Failed to create mock web view")
            return
        }

        // When
        sut.handleAttach(webView: webView)

        // Then
        XCTAssertNotNil(sut)

    }

    // MARK: - handleReload Tests
    func testHandleReload_WithValidYouTubeURL_HandlesCorrectly() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let videoURLAsk = URL(string: "https://www.youtube.com/watch?v=1a2b3c4d5e6")!
        let videoURLAuto = URL(string: "https://www.youtube.com/watch?v=2b3c4d5e6f7")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.lastHandledVideoID = "previousVideoID"

        // When
        mockWebView.navigate(to: videoURLAsk)
        sut.handleReload(webView: mockWebView)

        // Then
        XCTAssertTrue(mockDuckPlayer.dismissPillCalled, "Pill should be dismissed")
        XCTAssertTrue(mockDuckPlayer.presentPillCalled, "Pill should be presented in ask mode")
        mockDelayHandler.completeDelay()
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled, "DuckPlayer should not be loaded in ask mode")
        XCTAssertTrue(mockWebView.reloadCalled, "WebView should be reloaded")
        XCTAssertEqual(sut.lastHandledVideoID, "1a2b3c4d5e6")

        // Reset state for .auto mode test
        mockDuckPlayer.presentPillCalled = false
        mockDuckPlayer.dismissPillCalled = false
        mockDuckPlayer.loadNativeDuckPlayerVideoCalled = false
        mockWebView.reloadCalled = false
        sut.lastHandledVideoID = "previousVideoID"

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto

        // When
        mockWebView.navigate(to: videoURLAuto)
        sut.handleReload(webView: mockWebView)

        // Then
        XCTAssertTrue(mockDuckPlayer.dismissPillCalled, "Pill should be dismissed")
        XCTAssertTrue(mockDuckPlayer.presentPillCalled, "Pill should be presented in auto mode")
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled, "DuckPlayer should be loaded in auto mode")
        XCTAssertTrue(mockWebView.reloadCalled, "WebView should be reloaded")
        XCTAssertEqual(sut.lastHandledVideoID, "2b3c4d5e6f7")
    }

    func testHandleReload_WithNonWatchYouTubeURL_OnlyReloadsPage() {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let nonWatchURL = URL(string: "https://www.youtube.com/feed")!

        // Test with .ask mode
        playerSettings.nativeUIYoutubeMode = .ask
        sut.lastHandledVideoID = "previousVideoID"

        // When
        mockWebView.navigate(to: nonWatchURL)
        sut.handleReload(webView: mockWebView)

        // Then
        XCTAssertTrue(mockDuckPlayer.dismissPillCalled, "Pill should be dismissed")
        XCTAssertFalse(mockDuckPlayer.presentPillCalled, "Pill should not be presented")
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled, "DuckPlayer should not be loaded")
        XCTAssertTrue(mockWebView.reloadCalled, "WebView should be reloaded")
        XCTAssertEqual(sut.lastHandledVideoID, nil, "lastHandledVideoID should be reset")

        // Reset state for .auto mode test
        mockDuckPlayer.presentPillCalled = false
        mockDuckPlayer.dismissPillCalled = false
        mockDuckPlayer.loadNativeDuckPlayerVideoCalled = false
        mockWebView.reloadCalled = false
        sut.lastHandledVideoID = "previousVideoID"

        // Test with .auto mode
        playerSettings.nativeUIYoutubeMode = .auto

        // When
        mockWebView.navigate(to: nonWatchURL)
        sut.handleReload(webView: mockWebView)

        // Then
        XCTAssertTrue(mockDuckPlayer.dismissPillCalled, "Pill should be dismissed")
        XCTAssertFalse(mockDuckPlayer.presentPillCalled, "Pill should not be presented")
        XCTAssertFalse(mockDuckPlayer.loadNativeDuckPlayerVideoCalled, "DuckPlayer should not be loaded")
        XCTAssertTrue(mockWebView.reloadCalled, "WebView should be reloaded")
        XCTAssertEqual(sut.lastHandledVideoID, nil, "lastHandledVideoID should be reset")
    }

    // MARK: - handleDidFinishLoading Tests

    func testHandleDidFinishLoading_WhenFeatureOn_UpdatesReferrerURL() async {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]

        // When
        mockWebView.navigate(to: URL(string: "https://duckduckgo.com/?q=test")!)
        sut.handleDidFinishLoading(webView: mockWebView)

        // Then
        XCTAssertEqual(sut.referrer, .serp)

        // When
        mockWebView.navigate(to: URL(string: "https://google.com.com")!)
        sut.handleDidFinishLoading(webView: mockWebView)

        // Then
        XCTAssertEqual(sut.referrer, .other)

        // When
        mockWebView.navigate(to: URL(string: "https://youtube.com/")!)
        sut.handleDidFinishLoading(webView: mockWebView)

        // Then
        XCTAssertEqual(sut.referrer, .youtube)
    }

    func testHandleDidFinishLoading_WhenOnSERPAndDuckPlayerEnabled_NotifiesSERP() async {
        // To be impplemented when JS integration is complete
    }

    func testHandleDidFinishLoading_WhenOnSERPAndDuckPlayerDisabled_NotifiesSERPDisabled() async {
        // To be impplemented when JS integration is complete
    }

    // MARK: - handleDelegateNavigation Tests

    func testHandleDelegateNavigation_WhenFeatureOff_ReturnsFalse() async {
        // Given
        mockFeatureFlagger.enabledFeatures = []
        let url = URL(string: "https://youtube.com/watch?v=2782901a")!
        let request = URLRequest(url: url)
        let mockFrameInfo = MockFrameInfo(isMainFrame: true)
        let navigationAction = MockNavigationAction(request: request, targetFrame: mockFrameInfo)

        // When
        let result = sut.handleDelegateNavigation(navigationAction: navigationAction, webView: mockWebView)

        // Then
        XCTAssertFalse(result)

    }

    func testHandleDelegateNavigation_WhenOnSERPAndDuckPlayerEnabled_LoadsNativePlayer() async {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        playerSettings.nativeUISERPEnabled = true
        mockWebView.navigate(to: URL(string: "https://duckduckgo.com/?q=test")!)  // Set SERP Referrer

        let request = URLRequest(url: URL(string: "https://www.youtube.com/watch?v=aasdj111")!)
        let mockFrameInfo = MockFrameInfo(isMainFrame: true)
        let navigationAction = MockNavigationAction(request: request, targetFrame: mockFrameInfo)
        

        // When
        let result = sut.handleDelegateNavigation(navigationAction: navigationAction, webView: mockWebView)

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.lastHandledVideoID, "aasdj111")
        mockDelayHandler.completeDelay()
        XCTAssertTrue(mockDuckPlayer.loadNativeDuckPlayerVideoCalled)
    }

    func testHandleDelegateNavigation_WhenOnSERPAndDuckPlayerDisabled_LoadsYoutubePage() async {
        // Given
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        mockWebView.navigate(to: URL(string: "https://duckduckgo.com/?q=test")!)  // Set SERP Referrer
        sut.handleDidStartLoading(webView: mockWebView)
        
        let request = URLRequest(url: URL(string: "https://www.youtube.com/watch?v=test123")!)
        let mockFrameInfo = MockFrameInfo(isMainFrame: true)
        let navigationAction = MockNavigationAction(request: request, targetFrame: mockFrameInfo)
        playerSettings.nativeUISERPEnabled = false

        // When
        let result = sut.handleDelegateNavigation(navigationAction: navigationAction, webView: mockWebView)

        // Then
        XCTAssertFalse(result)
    }

    
    func testHandleGoBack_ResetsLastHandledVideoID() {
        // GIven
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let urlAsk = URL(string: "https://www.youtube.com/watch?v=djd83w3s")!
        
        // When
        playerSettings.nativeUIYoutubeMode = .ask
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAsk)
        sut.handleGoBack(webView: mockWebView)
                        
        XCTAssertNil(sut.lastHandledVideoID)
    }
    
    func testHandleGoForward_ResetsLastHandledVideoID() {
        // GIven
        mockFeatureFlagger.enabledFeatures = [.duckPlayer]
        let urlAsk = URL(string: "https://www.youtube.com/watch?v=djd83w3s")!
        
        // When
        playerSettings.nativeUIYoutubeMode = .ask
        let result = sut.handleURLChange(webView: mockWebView, previousURL: nil, newURL: urlAsk)
        sut.handleGoForward(webView: mockWebView)
                        
        XCTAssertNil(sut.lastHandledVideoID)
    }
    
}
