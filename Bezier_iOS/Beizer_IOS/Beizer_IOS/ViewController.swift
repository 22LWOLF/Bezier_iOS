//
//  ViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit
import AVFoundation
import FirebaseCore
import FirebaseAuth
      
class ViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    
    
    
    
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
        installGlobalRipple()
    }
    
    override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            heroEntrance(emailTextField, delay: 0.04, translateY: 18)
            heroEntrance(passwordTextField, delay: 0.16, translateY: 18)
            glowPulse(on: emailTextField, color: .systemBlue)
            glowPulse(on: passwordTextField, color: .systemIndigo)
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
    
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        // Get the username and password
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        // Basic validation
                if email.isEmpty || password.isEmpty {
                    shakeView(sender)
                    presentAuthAlert(title: "Missing Info", message: "Please enter both email and password")
                    return
            }
         
        
        

        animatePlayfulTap(sender)
        let localPoint = sender.superview?.convert(sender.center, to: view) ?? view.center
        ripple(at: localPoint, in: view, color: .systemBlue)
        glowPulse(on: sender, color: .systemBlue)
        
        // Use FirebaseManager to login
                sender.isEnabled = false
                let originalTitle = sender.title(for: .normal)
                sender.setTitle("Logging in...", for: .normal)
                
                FirebaseManager.shared.login(email: email, password: password) { result in
                    DispatchQueue.main.async {
                        sender.isEnabled = true
                        sender.setTitle(originalTitle, for: .normal)
                        
                        switch result {
                        case .success(let userID):
                            print("Logged in successfully! User ID: \(userID)")
                            self.animateSoftPulse(self.view)
                            self.sparkleBurst(at: CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY), in: self.view)
                            self.performSegue(withIdentifier: "goToHome", sender: self)
                            
                        case .failure(let error):
                            print("Login failed: \(error.localizedDescription)")
                            self.presentAuthAlert(title: "Login Failed", message: error.localizedDescription)
                            self.shakeView(sender)
                        }
                    }
                }
            }

    @IBAction func registerButtonTapped(_ sender: UIButton) {
        animatePlayfulTap(sender)
        let localPoint = sender.superview?.convert(sender.center, to: view) ?? view.center
        ripple(at: localPoint, in: view, color: .systemPurple)
        glowPulse(on: sender, color: .systemPurple)
        let email = emailTextField.text ?? ""
           let password = passwordTextField.text ?? ""
           
           guard !email.isEmpty, !password.isEmpty else {
               presentAuthAlert(title: "Missing Info", message: "Please enter both email and password to register.")
               return
           }
           
           // Show popup to get first and last name
           showNameInputPopup(email: email, password: password)
       }

       func showNameInputPopup(email: String, password: String) {
           let alert = UIAlertController(title: "Complete Registration", message: "Please enter your name", preferredStyle: .alert)
           
           // Add text fields for first and last name
           alert.addTextField { textField in
               textField.placeholder = "First Name"
               textField.autocapitalizationType = .words
           }
           
           alert.addTextField { textField in
               textField.placeholder = "Last Name"
               textField.autocapitalizationType = .words
           }
           
           // Cancel button
           alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
           
           // Register button
           alert.addAction(UIAlertAction(title: "Register", style: .default) { _ in
               let firstName = alert.textFields?[0].text ?? ""
               let lastName = alert.textFields?[1].text ?? ""
               
               guard !firstName.isEmpty, !lastName.isEmpty else {
                   self.presentAuthAlert(title: "Missing Name", message: "Please enter both first and last name.")
                   self.showNameInputPopup(email: email, password: password) // Show popup again
                   return
               }
               
               // Now register with all info
               self.performRegistration(email: email, password: password, firstName: firstName, lastName: lastName)
           })
           
           present(alert, animated: true)
       }

       func performRegistration(email: String, password: String, firstName: String, lastName: String) {
           FirebaseManager.shared.register(email: email, password: password, firstName: firstName, lastName: lastName) { result in
               DispatchQueue.main.async {
                   switch result {
                   case .success(let userID):
                       print("Registered successfully! User ID: \(userID)")
                       self.presentAuthAlert(title: "Success", message: "Account created! Now add a profile photo.")
                       
                       // Show photo picker after registration
                       DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                           self.showPhotoPickerAfterRegistration()
                       }
                       
                   case .failure(let error):
                       print("Registration failed: \(error.localizedDescription)")
                       self.presentAuthAlert(title: "Registration Failed", message: error.localizedDescription)
                   }
               }
           }
       }

       func showPhotoPickerAfterRegistration() {
           let alert = UIAlertController(title: "Profile Photo", message: "Would you like to add a profile photo?", preferredStyle: .alert)
           
           alert.addAction(UIAlertAction(title: "Add Photo", style: .default) { _ in
               self.openPhotoPicker()
           })
           
           alert.addAction(UIAlertAction(title: "Skip for Now", style: .cancel) { _ in
               self.performSegue(withIdentifier: "goToHome", sender: self)
           })
           
           present(alert, animated: true)
       }

       func openPhotoPicker() {
           let picker = UIImagePickerController()
           picker.delegate = self
           picker.sourceType = .photoLibrary
           picker.allowsEditing = true
           present(picker, animated: true)
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
    
    private func presentAuthAlert(title: String, message: String) {
           let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
           alert.addAction(UIAlertAction(title: "OK", style: .default))
           self.present(alert, animated: true)
       }
    
    private func installGlobalRipple() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        ripple(at: point, in: view, color: .systemTeal)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }

    private var shouldReduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    private func heroEntrance(_ target: UIView, delay: TimeInterval, translateY: CGFloat) {
        target.alpha = 0
        target.transform = CGAffineTransform(translationX: 0, y: translateY).scaledBy(x: 0.94, y: 0.94)
        UIView.animate(withDuration: shouldReduceMotion ? 0.2 : 0.55, delay: delay, usingSpringWithDamping: shouldReduceMotion ? 1.0 : 0.66, initialSpringVelocity: 0.3, options: [.curveEaseOut], animations: {
            target.alpha = 1
            target.transform = .identity
        })
    }

    private func animatePlayfulTap(_ target: UIView) {
        guard !shouldReduceMotion else { return }
        UIView.animate(withDuration: 0.09, animations: {
            target.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.24, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 4.0, options: [.curveEaseOut], animations: {
                target.transform = .identity
            })
        }
    }

    private func animateSoftPulse(_ target: UIView) {
        guard !shouldReduceMotion else { return }
        UIView.animate(withDuration: 0.16, animations: {
            target.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        }) { _ in
            UIView.animate(withDuration: 0.16) {
                target.transform = .identity
            }
        }
    }

    private func glowPulse(on target: UIView, color: UIColor) {
        target.layer.shadowColor = color.cgColor
        target.layer.shadowOffset = .zero
        target.layer.shadowRadius = 4
        target.layer.shadowOpacity = 0.2
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.1
        pulse.toValue = 0.9
        pulse.duration = shouldReduceMotion ? 0.16 : 0.24
        pulse.autoreverses = true
        target.layer.add(pulse, forKey: "vcGlowPulse")
    }

    private func ripple(at point: CGPoint, in container: UIView, color: UIColor) {
        let diameter = max(container.bounds.width, container.bounds.height) * 0.32
        let path = UIBezierPath(ovalIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter))
        let ring = CAShapeLayer()
        ring.path = path.cgPath
        ring.fillColor = color.withAlphaComponent(0.14).cgColor
        ring.strokeColor = color.withAlphaComponent(0.45).cgColor
        ring.lineWidth = 1.8
        container.layer.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.15
        scale.toValue = shouldReduceMotion ? 1.0 : 1.4
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.95
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = shouldReduceMotion ? 0.25 : 0.62
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        ring.add(group, forKey: "vcRipple")

        DispatchQueue.main.asyncAfter(deadline: .now() + group.duration) {
            ring.removeFromSuperlayer()
        }
    }

    private func sparkleBurst(at point: CGPoint, in container: UIView) {
        guard !shouldReduceMotion else { return }
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        let colors: [UIColor] = [.systemPink, .systemYellow, .systemTeal, .systemPurple]
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 85
            cell.lifetime = 0.95
            cell.velocity = 130
            cell.velocityRange = 45
            cell.emissionRange = .pi * 2
            cell.scale = 0.04
            cell.alphaSpeed = -1.1
            cell.contents = UIImage(systemName: "sparkle")?.withTintColor(color, renderingMode: .alwaysOriginal).cgImage
            return cell
        }
        container.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { emitter.removeFromSuperlayer() }
    }
}

// .collection() .doc() stuff to access certain areas within the docs.
