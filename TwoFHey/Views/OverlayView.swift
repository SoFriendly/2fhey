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
                        Text(line1).font(.system(size: 18)).foregroundColor(.white)
                    }
                    if let line2 = line2 {
                        Text(line2).foregroundColor(.white)
                    }
                }
            }
            .padding(8)
            .background(Color(red: 0.09, green: 0.77, blue: 0.20))
            .cornerRadius(5)
        }
        .padding(8)
        .cornerRadius(5)
     

        //.background(.black.opacity(0.6)) Isn't compatible with macOS 11
        //.border(.black.opacity(0.5), width: 1)
        
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView(line1: "Line 1", line2: "Sub text")
    }
}
