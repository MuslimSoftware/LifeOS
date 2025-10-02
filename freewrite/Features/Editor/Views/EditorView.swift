
import SwiftUI

struct EditorView: View {
    @Environment(EditorViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewHeight: CGFloat = 0
    
    var body: some View {
        @Bindable var vm = viewModel
        
        ZStack(alignment: .topLeading) {
            TextEditor(text: $vm.text)
                .background(Color(colorScheme == .light ? .white : .black))
                .font(.custom(vm.settings.selectedFont, size: vm.settings.fontSize))
                .foregroundColor(colorScheme == .light ? Color(red: 0.20, green: 0.20, blue: 0.20) : Color(red: 0.9, green: 0.9, blue: 0.9))
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .lineSpacing(vm.lineHeight)
                .frame(maxWidth: 650)
                .padding(.top, 40)
                .id("\(vm.settings.selectedFont)-\(vm.settings.fontSize)-\(colorScheme)")
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    viewHeight = height
                }
                .contentMargins(.bottom, viewHeight / 4)
            
            if vm.text.isEmpty {
                Text(vm.placeholderText)
                    .font(.custom(vm.settings.selectedFont, size: vm.settings.fontSize))
                    .foregroundColor(colorScheme == .light ? .gray.opacity(0.5) : .gray.opacity(0.6))
                    .allowsHitTesting(false)
                    .frame(maxWidth: 650, alignment: .leading)
                    .offset(x: 5, y: 0)
                    .padding(.top, 40)
            }
        }
    }
}
