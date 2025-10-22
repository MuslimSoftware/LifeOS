
import SwiftUI

struct EditorView: View {
    @Environment(EditorViewModel.self) private var viewModel
    @Environment(\.theme) private var theme
    @State private var viewHeight: CGFloat = 0
    
    var body: some View {
        @Bindable var vm = viewModel
        
        ZStack(alignment: .topLeading) {
            TextEditor(text: $vm.text)
                .background(theme.backgroundColor)
                .font(.custom(vm.settings.selectedFont, size: vm.settings.fontSize))
                .foregroundColor(theme.primaryText)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .lineSpacing(vm.lineHeight)
                .frame(maxWidth: 650)
                .padding(.top, 40)
                .id("\(vm.settings.selectedFont)-\(vm.settings.fontSize)")
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    viewHeight = height
                }
                .contentMargins(.bottom, viewHeight / 4)
            
            if vm.text.isEmpty {
                Text(vm.placeholderText)
                    .font(.custom(vm.settings.selectedFont, size: vm.settings.fontSize))
                    .foregroundColor(theme.placeholderText)
                    .allowsHitTesting(false)
                    .frame(maxWidth: 650, alignment: .leading)
                    .offset(x: 5, y: 0)
                    .padding(.top, 40)
            }
        }
    }
}
