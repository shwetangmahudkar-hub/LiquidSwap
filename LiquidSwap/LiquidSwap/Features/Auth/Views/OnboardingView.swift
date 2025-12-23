//
//  OnboardingView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @State private var name: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            // Layer 1: Animated Background
            LiquidBackground()
            
            // Layer 2: Content
            VStack(spacing: 40) {
                
                VStack(spacing: 10) {
                    Text("Welcome to Liquid Swap")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("The Zero-Capital Barter Ecosystem")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 60)
                
                // Avatar Picker
                VStack(spacing: 16) {
                    ZStack {
                        if let selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.cyan, lineWidth: 3))
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 150, height: 150)
                                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white.opacity(0.5))
                                )
                        }
                    }
                    .shadow(radius: 10)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text(selectedImage == nil ? "Upload Photo" : "Change Photo")
                            .font(.headline)
                            .foregroundStyle(.cyan)
                    }
                }
                
                // Name Input
                VStack(alignment: .leading) {
                    Text("What should we call you?")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.leading)
                    
                    TextField("", text: $name, prompt: Text("Your Name").foregroundStyle(.white.opacity(0.3)))
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Get Started Button
                Button(action: {
                    UserManager.shared.completeOnboarding(name: name, image: uiImage)
                }) {
                    Text("Enter Ecosystem")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.isEmpty ? Color.gray.opacity(0.5) : Color.cyan)
                        .cornerRadius(30)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                }
                .disabled(name.isEmpty)
                .padding(.bottom, 50)
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImg = UIImage(data: data) {
                    self.uiImage = uiImg
                    self.selectedImage = Image(uiImage: uiImg)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}