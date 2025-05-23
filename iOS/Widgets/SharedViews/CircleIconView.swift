//
//  CircleIconView.swift
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

import SwiftUI

struct CircleIconView: View {
    let image: Image

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23)
                .fill(Color(designSystemColor: .container))
            image
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .makeAccentable()
        }
        .frame(width: 46, height: 46)
    }
}
