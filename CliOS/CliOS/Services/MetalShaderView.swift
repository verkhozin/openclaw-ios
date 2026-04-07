import SwiftUI
import MetalKit

// Must match ShaderTypes.h layout exactly
struct ShaderUniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var tintColor: SIMD3<Float>
}

struct MetalShaderView: UIViewRepresentable {
    var fps: Int = 30
    var shader: ShaderType = .sky
    var tintColor: SIMD3<Float> = SIMD3<Float>(1.0, 0.3, 0.0)
    var timeScale: Float = 1.0
    @Binding var isVisible: Bool

    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = fps
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = !isVisible
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.coordinator.tintColor = tintColor
        context.coordinator.timeScale = timeScale
        context.coordinator.setupMetal(device: mtkView.device!, fragmentName: shader.fragmentFunction)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.isPaused = !isVisible
        uiView.preferredFramesPerSecond = fps
        context.coordinator.tintColor = tintColor
        context.coordinator.timeScale = timeScale
    }

    // MARK: - Renderer

    class Renderer: NSObject, MTKViewDelegate {
        private var device: MTLDevice!
        private var commandQueue: MTLCommandQueue!
        private var pipelineState: MTLRenderPipelineState!
        private var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        private var uniformBuffer: MTLBuffer!
        var tintColor: SIMD3<Float> = SIMD3<Float>(1.0, 0.3, 0.0)
        var timeScale: Float = 1.0

        func setupMetal(device: MTLDevice, fragmentName: String) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()

            guard let library = device.makeDefaultLibrary() else {
                print("Metal: failed to load default library")
                return
            }

            do {
                let vertexFunction = library.makeFunction(name: "shaderVertex")
                let fragmentFunction = library.makeFunction(name: fragmentName)

                let desc = MTLRenderPipelineDescriptor()
                desc.vertexFunction = vertexFunction
                desc.fragmentFunction = fragmentFunction
                desc.colorAttachments[0].pixelFormat = .bgra8Unorm

                pipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                print("Metal pipeline failed: \(error)")
            }

            uniformBuffer = device.makeBuffer(
                length: MemoryLayout<ShaderUniforms>.size,
                options: .storageModeShared
            )
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let pipelineState,
                  let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            else { return }

            let elapsed = Float(CFAbsoluteTimeGetCurrent() - startTime) * timeScale
            var uniforms = ShaderUniforms(
                time: elapsed,
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                tintColor: tintColor
            )
            memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<ShaderUniforms>.size)

            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
