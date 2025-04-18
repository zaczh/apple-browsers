//
//  DownloadsListViewModel.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import SwiftUI
import Combine
import Common
import Core
import os.log

class DownloadsListViewModel: ObservableObject {

    @Published var sections: [DownloadsListSectionViewModel] = []
    var requestActivityViewHandler: ((_ url: URL, _ sourceRect: CGRect) -> Void)?
    
    private let dataSource: DownloadsListDataSource
    private var subscribers: Set<AnyCancellable> = []
    
    init(dataSource: DownloadsListDataSource) {
        Logger.general.debug("DownloadsListViewModel init")

        self.dataSource = dataSource
        
        dataSource.$model
            .sink { [weak self] in
                Logger.general.debug("DownloadsListViewModel changed - ongoing:\($0.ongoingDownloads.count) complete:\($0.completeDownloads.count)")

                self?.sections = DownloadsListSectioningHelper().makeSections(from: $0.ongoingDownloads + $0.completeDownloads)
            }
            .store(in: &subscribers)
    }
    
    deinit {
        Logger.general.debug("DownloadsListViewModel deinit")
    }
    
    // MARK: - Intents
    
    func cancelDownload(for rowModel: OngoingDownloadRowViewModel) {
        Pixel.fire(pixel: .downloadsListOngoingDownloadCancelled)
        dataSource.cancelDownloadWithIdentifier(rowModel.id)
    }
    
    func deleteDownload(at offsets: IndexSet, in sectionIndex: Int) {
        Pixel.fire(pixel: .downloadsListCompleteDownloadDeleted)
        guard let rowIndex = offsets.first else { return }
        
        let item = sections[sectionIndex].rows[rowIndex]
    
        dataSource.deleteDownloadWithIdentifier(item.id) { result in
            switch result {
            case .success(let undoHandler):
                let message = UserText.messageDownloadDeleted(for: item.filename)
                presentDeleteConfirmation(message: message,
                                          undoHandler: undoHandler)
            case .failure(let error):
                Logger.general.error("Error deleting a download: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func deleteAllDownloads() {
        Pixel.fire(pixel: .downloadsListAllCompleteDownloadsDeleted)
        dataSource.deleteAllDownloads { result in
            switch result {
            case .success(let undoHandler):
                presentDeleteConfirmation(message: UserText.messageAllFilesDeleted,
                                          undoHandler: undoHandler)
            case .failure(let error):
                Logger.general.error("Error deleting all downloads: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func presentDeleteConfirmation(message: String, undoHandler: @escaping DeleteUndoHandler) {
        DispatchQueue.main.async {
            ActionMessageView.present(message: message,
                                      actionTitle: UserText.actionGenericUndo,
                                      onAction: undoHandler)
        }
    }
    
    func showActivityView(for rowModel: CompleteDownloadRowViewModel, from sourceRect: CGRect) {
        guard let handler = self.requestActivityViewHandler else { return }
        Pixel.fire(pixel: .downloadsListSharePressed)
        handler(rowModel.fileURL, sourceRect)
    }
}
