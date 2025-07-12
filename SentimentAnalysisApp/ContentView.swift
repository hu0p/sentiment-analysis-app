//
//  ContentView.swift
//  SentimentAnalysisApp
//
//  Created by Logan Houp on 7/10/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("SwiftTerm Integration Test")
                .font(.headline)
                .padding(.top)
            
            Text("Terminal wrapper is being tested...")
                .foregroundColor(.secondary)
                .padding()
            
            // SwiftTermWrapper will be added back once the wrapper compiles successfully
            // SwiftTermWrapper(command: "/bin/bash", args: [])
            //     .frame(minWidth: 600, minHeight: 400)
            //     .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
