import UIKit

enum VisualEffects {
    static var shouldReduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    static func ripple(at point: CGPoint, in view: UIView, color: UIColor = .systemTeal, duration: CFTimeInterval = 0.65) {
        let diameter = max(view.bounds.width, view.bounds.height) * 0.34
        let ripplePath = UIBezierPath(ovalIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter))

        let rippleLayer = CAShapeLayer()
        rippleLayer.path = ripplePath.cgPath
        rippleLayer.fillColor = color.withAlphaComponent(0.14).cgColor
        rippleLayer.strokeColor = color.withAlphaComponent(0.5).cgColor
        rippleLayer.lineWidth = 1.8
        view.layer.addSublayer(rippleLayer)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.15
        scale.toValue = shouldReduceMotion ? 1.05 : 1.45

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.95
        fade.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = shouldReduceMotion ? 0.28 : duration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        rippleLayer.add(group, forKey: "ripple")

        DispatchQueue.main.asyncAfter(deadline: .now() + group.duration) {
            rippleLayer.removeFromSuperlayer()
        }
    }

    static func sparkleBurst(at point: CGPoint, in view: UIView, colors: [UIColor] = [.systemPink, .systemYellow, .systemTeal, .systemPurple]) {
        guard !shouldReduceMotion else { return }

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        emitter.emitterSize = CGSize(width: 14, height: 14)

        let particles: [CAEmitterCell] = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 85
            cell.lifetime = 0.95
            cell.lifetimeRange = 0.3
            cell.velocity = 130
            cell.velocityRange = 45
            cell.emissionRange = .pi * 2
            cell.scale = 0.04
            cell.scaleRange = 0.02
            cell.alphaSpeed = -1.1
            cell.contents = UIImage(systemName: "sparkle")?.withTintColor(color, renderingMode: .alwaysOriginal).cgImage
            return cell
        }

        emitter.emitterCells = particles
        view.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            emitter.removeFromSuperlayer()
        }
    }

    static func glowPulse(on view: UIView, color: UIColor = .systemCyan) {
        if shouldReduceMotion {
            UIView.animate(withDuration: 0.16, animations: {
                view.alpha = 0.92
            }) { _ in
                UIView.animate(withDuration: 0.16) {
                    view.alpha = 1
                }
            }
            return
        }

        view.layer.shadowColor = color.cgColor
        view.layer.shadowOffset = .zero
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.18

        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.1
        pulse.toValue = 0.9
        pulse.duration = 0.24
        pulse.autoreverses = true
        view.layer.add(pulse, forKey: "glowPulse")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            view.layer.shadowOpacity = 0.18
        }
    }

    static func applyParallax(to view: UIView, amount: CGFloat = 18) {
        guard !shouldReduceMotion else { return }
        guard view.motionEffects.isEmpty else { return }

        let xTilt = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        xTilt.minimumRelativeValue = -amount
        xTilt.maximumRelativeValue = amount

        let yTilt = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        yTilt.minimumRelativeValue = -amount
        yTilt.maximumRelativeValue = amount

        let group = UIMotionEffectGroup()
        group.motionEffects = [xTilt, yTilt]
        view.addMotionEffect(group)
    }

    static func heroEntrance(_ view: UIView, delay: TimeInterval = 0, translateY: CGFloat = 30) {
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: translateY).scaledBy(x: 0.93, y: 0.93)

        if shouldReduceMotion {
            UIView.animate(withDuration: 0.2, delay: delay, options: [.curveEaseOut], animations: {
                view.alpha = 1
                view.transform = .identity
            })
            return
        }

        UIView.animate(withDuration: 0.55, delay: delay, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.32, options: [.curveEaseOut], animations: {
            view.alpha = 1
            view.transform = .identity
        })
    }
}

extension UIView {
    func animatePlayfulTap(completion: (() -> Void)? = nil) {
        guard !VisualEffects.shouldReduceMotion else {
            completion?()
            return
        }

        UIView.animate(withDuration: 0.09, delay: 0, options: [.curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.26, delay: 0, usingSpringWithDamping: 0.44, initialSpringVelocity: 4.4, options: [.curveEaseInOut], animations: {
                self.transform = .identity
            }) { _ in
                completion?()
            }
        }
    }

    func animateSoftPulse() {
        guard !VisualEffects.shouldReduceMotion else { return }
        transform = .identity
        UIView.animate(withDuration: 0.17, animations: {
            self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        }) { _ in
            UIView.animate(withDuration: 0.17) {
                self.transform = .identity
            }
        }
    }
}
