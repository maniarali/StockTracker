//
//  ContentView.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("StockTracker")
                    .font(.title2.weight(.semibold))
                Text("Starter project — add live data and domain models here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
