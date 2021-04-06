//
//  LogView.swift
//  Get iPlayer Automator 3
//
//  Created by Scott Kovatch on 8/5/20.
//

import SwiftUI

struct LogView: View {
    var controller: LogController
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(controller.log, id: \.self) { line in
                    Text(line)
                        .font(.custom("Monaco", size: 12))
                }
            }
        }
    }
    
    struct LogView_Previews: PreviewProvider {
        static var previews: some View {
            LogView(controller: LogController())
        }
    }
}
