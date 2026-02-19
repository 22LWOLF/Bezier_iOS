//
//  ViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
        // Animated elements
        var topBorder: UIView!
        var bottomBorder: UIView!
        var loadingRing: CAShapeLayer!
        var loginButton: UIButton?
    
    var audioPlayer: AVAudioPlayer!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Style the text fields
                styleTextField(emailTextField)
                styleTextField(passwordTextField)
                
                // Start with elements off-screen and transparent
                emailTextField.alpha = 0
                passwordTextField.alpha = 0
                emailTextField.transform = CGAffineTransform(translationX: -300, y: 0)
                passwordTextField.transform = CGAffineTransform(translationX: -300, y: 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            // Animate elements sliding in
        UIView.animate(withDuration: 0.8, delay: 0.1, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.2, options: .transitionFlipFromTop) {
                self.emailTextField.alpha = 1
                self.emailTextField.transform = .identity
            }
            
        UIView.animate(withDuration: 0.8, delay: 0.3, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.2, options: .curveEaseOut) {
                self.passwordTextField.alpha = 1
                self.passwordTextField.transform = .identity
            }
        }

    
    func styleTextField(_ textField: UITextField) {
            // Add rounded corners
            textField.layer.cornerRadius = 8
            textField.layer.borderWidth = 1
            textField.layer.borderColor = UIColor.systemBlue.cgColor
            
            // Add padding
            let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: textField.frame.height))
            textField.leftView = paddingView
            textField.leftViewMode = .always
        }

    func playSound(named name: String, withExtension ext: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                print("Failed to play sound: \(error)")
            }
        } else {
            print("Sound file not found: \(name).\(ext)")
        }
    }
    
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        // Get the username and password
               let email = emailTextField.text ?? ""
               let password = passwordTextField.text ?? ""
               
               // Basic validation
               if email.isEmpty || password.isEmpty {
                   // Play sound effect when triggering the rotation/scale animation
                   playSound(named: "login", withExtension: "mp3") // Update to your actual filename and extension
                   shakeView(sender)
                   return
               }
        
        // Scale button on tap
                UIView.animate(withDuration: 0.1, animations: {
                    sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                }) { _ in
                    UIView.animate(withDuration: 0.1) {
                        sender.transform = .identity
                    }
                }
                
               
               // For now, just navigate to home screen
               // Later you'll add real authentication here
               performSegue(withIdentifier: "goToHome", sender: self)
    }
    
    
    // Counts from -200 up to 0 and from 200 down to 0 by 1. Returns both sequences.
    func makeSequentialNumbers() -> (upFromNegative: [Int], downFromPositive: [Int]) {
        let upFromNegative = Array(-200...0)
        let downFromPositive = Array(stride(from: 200, through: 0, by: -1))
        return (upFromNegative, downFromPositive)
    }
    
    // If you need a single interleaved sequence like -200, 200, -199, 199, ..., 0, 0
    func makeInterleavedSequentialNumbers() -> [Int] {
        var result: [Int] = []
        var neg = -200
        var pos = 200
        while neg <= 0 && pos >= 0 {
            result.append(neg)
            result.append(pos)
            neg += 1
            pos -= 1
        }
        return result
    }
    
    func shakeView(_ view: UIView) {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 0.6
        rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 1.2, 0.95, 1.0]
        scale.keyTimes = [0.0, 0.5, 0.85, 1.0] as [NSNumber]
        scale.duration = 0.6
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let group = CAAnimationGroup()
        group.animations = [rotation, scale]
        group.duration = 0.6
        group.fillMode = .forwards
        group.isRemovedOnCompletion = true

        view.layer.add(group, forKey: "spinScale")
    }
    

}

