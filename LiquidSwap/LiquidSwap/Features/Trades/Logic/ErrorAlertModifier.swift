//
//  ErrorAlertModifier.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-24.
//

import SwiftUI

/// A reusable view modifier for displaying error alerts
struct ErrorAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String?
    let onDismiss: (() -> Void)?
    
    init(isPresented: Binding<Bool>, message: String?, onDismiss: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.message = message
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $isPresented) {
                Button("OK") {
                    onDismiss?()
                }
            } message: {
                Text(message ?? "An unexpected error occurred.")
            }
    }
}

// MARK: - Convenience Extension

extension View {
    /// Display an error alert
    /// - Parameters:
    ///   - isPresented: Binding to control alert visibility
    ///   - message: Optional error message to display
    ///   - onDismiss: Optional closure to call when alert is dismissed
    func errorAlert(
        isPresented: Binding<Bool>,
        message: String?,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(
            isPresented: isPresented,
            message: message,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Usage Example

/*
 
 Example usage in your views:
 
 struct TradesView: View {
     @StateObject private var tradeManager = TradeManager.shared
     
     var body: some View {
         List {
             // Your content
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: {
                 tradeManager.clearError()
             }
         )
     }
 }
 
 */
