//
//  SplashView.swift
//  MDM Migrator
//
//  Created by somesh pathak on 31/10/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool
    @State private var size = 0.7
    @State private var opacity = 0.3
    @State private var rotation = 0.0
    @State private var showRings = false
    
    var body: some View {
        ZStack {
            // Background rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                    .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                    .scaleEffect(showRings ? 1 : 0.3)
                    .opacity(showRings ? 0.3 : 0)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .delay(Double(i) * 0.2),
                        value: showRings
                    )
            }
            
            VStack(spacing: 20) {
                ZStack {
                    // Main icon with glow
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(rotation))
                        .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    // Pulse effect
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(showRings ? 1.2 : 0.8)
                        .opacity(showRings ? 0 : 0.5)
                        .animation(.easeInOut(duration: 1.0).repeatForever(), value: showRings)
                }
                
                Text("MDM Migrator")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary.opacity(0.80))
            }
            .scaleEffect(size)
            .opacity(opacity)
        }
        .frame(width: 700, height: 600)
                .background(Color(.windowBackgroundColor))
                .onAppear {
            // Start animations
            withAnimation(.easeInOut(duration: 1.5)) {
                self.size = 1.0
                self.opacity = 1.0
            }
            
            withAnimation(.linear(duration: 2)) {
                self.rotation = 360
            }
            
            showRings = true
            
            // Navigate to main view after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}

#Preview {
    SplashView(isShowing: .constant(true))
}
