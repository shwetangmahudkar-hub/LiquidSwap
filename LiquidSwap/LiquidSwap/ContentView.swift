import SwiftUI

struct ContentView: View {
    // ✅ Restore your original AuthViewModel
    @StateObject var authVM = AuthViewModel()
    @State private var showSplash = true
    
    // ✨ Access the new ModalManager
    @EnvironmentObject var modalManager: ModalManager
    
    var body: some View {
        ZStack {
            // 1. MAIN CONTENT (Base Layer)
            if !showSplash {
                Group {
                    if authVM.isAuthenticated {
                        if authVM.isOnboarding {
                            OnboardingView(authVM: authVM)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .zIndex(2)
                        } else {
                            MainTabView()
                                .environmentObject(authVM)
                                .transition(.opacity)
                                // ✨ THE DEEP GLASS EFFECT ✨
                                // When a modal is up, we push this view "back"
                                .scaleEffect(modalManager.isPresenting ? 0.92 : 1.0)
                                .blur(radius: modalManager.isPresenting ? 3 : 0)
                                .opacity(modalManager.isPresenting ? 0.8 : 1.0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: modalManager.isPresenting)
                        }
                    } else {
                        AuthView()
                            .environmentObject(authVM)
                    }
                }
            }
            
            // 2. SPLASH SCREEN (Highest Priority on Launch)
            if showSplash {
                SplashScreen(showSplash: $showSplash)
                    .zIndex(3)
            }
            
            // 3. ✨ GLASS MODAL LAYER (Global Overlay)
            // This sits on top of EVERYTHING (except Splash)
            if let activeModal = modalManager.activeModal, modalManager.isPresenting {
                GlassModalContainer(modal: activeModal)
                    .transition(.move(edge: .bottom))
                    .zIndex(4)
            }
        }
        .onAppear {
            // iOS 16.6 compatible initializations
        }
    }
    
    // ✨ The Reusable Glass Container
    private struct GlassModalContainer: View {
        let modal: AppModal
        @EnvironmentObject var modalManager: ModalManager

        var body: some View {
            ZStack(alignment: .bottom) {
                // The "Frosted Glass Pane"
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        modalManager.dismiss()
                    }
                
                // The Modal Content
                VStack {
                    // Handle Bar
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                    
                    // Route to the correct view
                    switch modal {
                    case .addItem:
                        // We will connect this in the next step
                        Text("Add Item Placeholder").foregroundStyle(.white).padding(.top, 50)
                        Spacer()
                    case .settings:
                        Text("Settings Placeholder").foregroundStyle(.white).padding(.top, 50)
                        Spacer()
                    case .editProfile:
                         Text("Edit Profile Placeholder").foregroundStyle(.white).padding(.top, 50)
                         Spacer()
                    case .activityHub:
                         Text("Activity Hub Placeholder").foregroundStyle(.white).padding(.top, 50)
                         Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.92) // 92% Height
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.thinMaterial) // Second layer of glass
                        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.bottom, -30) // Hide bottom corners
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 100 {
                            modalManager.dismiss()
                        }
                    }
            )
        }
    }
}
