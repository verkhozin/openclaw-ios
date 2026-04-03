// CGPoint+Extensions.swift
// Vendored from https://github.com/Cindori/FluidGradient (MIT License)
// Copyright (c) 2022 João Gabriel Pozzobon dos Santos

import CoreGraphics

extension CGPoint {
    /// Build a point from an origin and a displacement
    func displace(by point: CGPoint = .init(x: 0.0, y: 0.0)) -> CGPoint {
        return CGPoint(x: self.x + point.x,
                       y: self.y + point.y)
    }

    /// Caps the point to the unit space
    func capped() -> CGPoint {
        return CGPoint(x: max(min(x, 1), 0),
                       y: max(min(y, 1), 0))
    }
}
