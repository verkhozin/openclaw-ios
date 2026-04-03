// BlobLayer.swift
// Vendored from https://github.com/Cindori/FluidGradient (MIT License)
// Copyright (c) 2022 João Gabriel Pozzobon dos Santos

import SwiftUI
import UIKit

/// A CAGradientLayer that draws a single radial blob
public class BlobLayer: CAGradientLayer {
    init(color: Color) {
        super.init()

        self.type = .radial
        set(color: color)

        let position = newPosition()
        self.startPoint = position

        let radius = newRadius()
        self.endPoint = position.displace(by: radius)
    }

    func newPosition() -> CGPoint {
        return CGPoint(x: CGFloat.random(in: 0.0...1.0),
                       y: CGFloat.random(in: 0.0...1.0)).capped()
    }

    func newRadius() -> CGPoint {
        let size = CGFloat.random(in: 0.15...0.75)
        let viewRatio = frame.width / frame.height
        let safeRatio = max(viewRatio.isNaN ? 1 : viewRatio, 1)
        let ratio = safeRatio * CGFloat.random(in: 0.25...1.75)
        return CGPoint(x: size, y: size * ratio)
    }

    func animate(speed: CGFloat) {
        guard speed > 0 else { return }

        self.removeAllAnimations()
        let currentLayer = self.presentation() ?? self

        let animation = CASpringAnimation()
        animation.mass = 10 / speed
        animation.damping = 50
        animation.duration = 1 / speed
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards

        let position = newPosition()
        let radius = newRadius()

        let start = animation.copy() as! CASpringAnimation
        start.keyPath = "startPoint"
        start.fromValue = currentLayer.startPoint
        start.toValue = position

        let end = animation.copy() as! CASpringAnimation
        end.keyPath = "endPoint"
        end.fromValue = currentLayer.endPoint
        end.toValue = position.displace(by: radius)

        self.startPoint = position
        self.endPoint = position.displace(by: radius)

        let value = Float.random(in: 0.5...1)
        let opacity = animation.copy() as! CASpringAnimation
        opacity.fromValue = self.opacity
        opacity.toValue = value

        self.opacity = value

        self.add(opacity, forKey: "opacity")
        self.add(start, forKey: "startPoint")
        self.add(end, forKey: "endPoint")
    }

    func set(color: Color) {
        self.colors = [UIColor(color).cgColor,
                       UIColor(color).cgColor,
                       UIColor(color.opacity(0.0)).cgColor]
        self.locations = [0.0, 0.9, 1.0]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override init(layer: Any) {
        super.init(layer: layer)
    }
}
