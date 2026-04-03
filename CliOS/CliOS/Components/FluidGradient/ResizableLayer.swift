// ResizableLayer.swift
// Vendored from https://github.com/Cindori/FluidGradient (MIT License)
// Copyright (c) 2022 João Gabriel Pozzobon dos Santos

import QuartzCore

/// A CALayer that resizes its sublayers to match its own bounds
public class ResizableLayer: CALayer {
    override init() {
        super.init()
        sublayers = []
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSublayers() {
        super.layoutSublayers()
        sublayers?.forEach { layer in
            layer.frame = self.frame
        }
    }
}
