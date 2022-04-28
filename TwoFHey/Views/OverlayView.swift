//
//  OverlayView.swift
//  ohtipi
//
//  Created by Drew Pomerleau on 4/25/22.
//

import SwiftUI

struct OverlayView: View {
    var line1: String?
    var line2: String?
    
    var body: some View {
        HStack {
            HStack {
                Image("MessageBubble").foregroundColor(.white)
                VStack(alignment: .leading) {
                    if let line1 = line1 {
                        Text(line1).font(.system(size: 18))
                    }
                    if let line2 = line2 {
                        Text(line2)
                    }
                }
            }
            .padding(8)
            .background(Color(red: 0, green: 98/255, blue: 1))
            .cornerRadius(5)
        }
        .padding(8)
        .background(.black.opacity(0.5))
        .border(.white.opacity(0.13), width: 1)
        .cornerRadius(5)
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView(line1: "Line 1", line2: "Sub text")
    }
}
