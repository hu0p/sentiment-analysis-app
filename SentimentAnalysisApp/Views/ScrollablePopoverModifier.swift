import SwiftUI

/// A custom popover modifier that automatically dismisses popovers when the attached view scrolls out of view
struct ScrollablePopoverModifier<PopoverContent: View>: ViewModifier {
    let isPresented: Binding<Bool>
    let popoverContent: PopoverContent
    @State private var viewFrame: CGRect = .zero
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> PopoverContent) {
        self.isPresented = isPresented
        self.popoverContent = content()
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            viewFrame = geometry.frame(in: .named("scrollView"))
                        }
                        .onChange(of: geometry.frame(in: .named("scrollView"))) { _, newFrame in
                            viewFrame = newFrame
                            checkVisibility()
                        }
                }
            )
            .popover(isPresented: isPresented) {
                popoverContent
            }
    }
    
    private func checkVisibility() {
        // Dismiss popover if view is completely outside the visible area
        let isOutside = viewFrame.maxY < 0 || viewFrame.minY > 400
        
        if isOutside && isPresented.wrappedValue {
            isPresented.wrappedValue = false
        }
    }
}

/// Extension to make the modifier easier to use
extension View {
    /// Applies a popover that automatically dismisses when the view scrolls out of view
    func scrollablePopover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(ScrollablePopoverModifier(isPresented: isPresented, content: content))
    }
} 