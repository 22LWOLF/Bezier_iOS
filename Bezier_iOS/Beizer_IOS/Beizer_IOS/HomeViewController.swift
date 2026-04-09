//
//  HomeViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit

class HomeViewController: UIViewController, UIGestureRecognizerDelegate {
    private var hasAnimatedEntrance = false
    private var primaryButtons: [UIButton] {
        view.subviews.compactMap { $0 as? UIButton }.sorted { $0.frame.minY < $1.frame.minY }
    }
    
    
    
    @IBAction func joinSessionTapped(_ sender: UIButton) {
        let origin = sender.superview?.convert(sender.center, to: view) ?? view.center
        VisualEffects.ripple(at: origin, in: view, color: .systemMint)
        VisualEffects.glowPulse(on: sender, color: .systemMint)
        sender.animatePlayfulTap { [weak self] in
            self?.performSegue(withIdentifier: "goToScanner", sender: self)
        }
    }
    
    
    @IBAction func hostSessionTapped(_ sender: UIButton) {
        let origin = sender.superview?.convert(sender.center, to: view) ?? view.center
        VisualEffects.ripple(at: origin, in: view, color: .systemOrange)
        VisualEffects.glowPulse(on: sender, color: .systemOrange)
        sender.animatePlayfulTap { [weak self] in
            self?.performSegue(withIdentifier: "goToHost", sender: self)
        }
    }
    
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        installGlobalRipple()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedEntrance else { return }
        hasAnimatedEntrance = true

        for (index, button) in primaryButtons.enumerated() {
            VisualEffects.heroEntrance(button, delay: TimeInterval(index) * 0.12, translateY: 24)
            VisualEffects.applyParallax(to: button, amount: 10)
        }
    }

    private func installGlobalRipple() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        VisualEffects.ripple(at: gesture.location(in: view), in: view, color: .systemIndigo)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
