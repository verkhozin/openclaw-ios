// FluidGradientView.swift
// Vendored from https://github.com/Cindori/FluidGradient (MIT License)
// Copyright (c) 2021 Oskar Groth, João Gabriel Pozzobon dos Santos

import SwiftUI
import UIKit
import Combine

/// A UIView that presents an animated gradient with CoreAnimation
public class FluidGradientView: UIView {
    var speed: CGFloat

    let baseLayer = ResizableLayer()
    let highlightLayer = ResizableLayer()

    var cancellables = Set<AnyCancellable>()

    weak var delegate: FluidGradientDelegate?

    init(blobs: [Color] = [],
         highlights: [Color] = [],
         speed: CGFloat = 1.0) {
        self.speed = speed
        super.init(frame: .zero)

        if let compositingFilter = CIFilter(name: "CIOverlayBlendMode") {
            highlightLayer.compositingFilter = compositingFilter
        }

        self.layer.addSublayer(baseLayer)
        self.layer.addSublayer(highlightLayer)

        create(blobs, layer: baseLayer)
        create(highlights, layer: highlightLayer)
        DispatchQueue.main.async {
            self.update(speed: speed)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Create blobs and add to specified layer
    public func create(_ colors: [Color], layer: CALayer) {
        let count = layer.sublayers?.count ?? 0
        let removeCount = count - colors.count
        if removeCount > 0 {
            layer.sublayers?.removeLast(removeCount)
        }

        for (index, color) in colors.enumerated() {
            if index < count {
                if let existing = layer.sublayers?[index] as? BlobLayer {
                    existing.set(color: color)
                }
            } else {
                layer.addSublayer(BlobLayer(color: color))
            }
        }
    }

    /// Update sublayers and set speed and blur levels
    public func update(speed: CGFloat) {
        cancellables.removeAll()
        self.speed = speed
        guard speed > 0 else { return }

        let layers = (baseLayer.sublayers ?? []) + (highlightLayer.sublayers ?? [])
        for layer in layers {
            if let layer = layer as? BlobLayer {
                Timer.publish(every: .random(in: 0.8/speed...1.2/speed),
                              on: .main,
                              in: .common)
                    .autoconnect()
                    .sink { _ in
                        layer.animate(speed: speed)
                    }
                    .store(in: &cancellables)
            }
        }
    }

    private func updateBlur() {
        delegate?.updateBlur(min(frame.width, frame.height))
    }

    public override func layoutSubviews() {
        layer.frame = self.bounds
        baseLayer.frame = self.bounds
        highlightLayer.frame = self.bounds
        updateBlur()
    }
}

protocol FluidGradientDelegate: AnyObject {
    func updateBlur(_ value: CGFloat)
}
