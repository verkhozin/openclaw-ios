import SwiftUI

struct ShaderPlaygroundView: View {
    @State private var isVisible = true
    @State private var selectedShader: ShaderType = .sky

    var body: some View {
        ZStack {
            MetalShaderView(fps: 60, shader: selectedShader, isVisible: $isVisible)
                .ignoresSafeArea()
                .id(selectedShader)

            VStack {
                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ShaderType.allCases) { shader in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedShader = shader
                                }
                            } label: {
                                Text(shader.rawValue)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedShader == shader
                                            ? Color.white
                                            : Color.white.opacity(0.15)
                                    )
                                    .foregroundColor(
                                        selectedShader == shader
                                            ? .black
                                            : .white
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, Theme.paddingM)
                }
                .padding(.bottom, Theme.paddingM)
            }
        }
        .navigationTitle("Shader")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}
