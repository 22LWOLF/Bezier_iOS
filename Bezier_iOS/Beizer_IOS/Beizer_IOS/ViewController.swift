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
            

        // Scale button on tap
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
        
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
                            print("✅ Logged in successfully! User ID: \(userID)")
                            self.performSegue(withIdentifier: "goToHome", sender: self)
                            
                        case .failure(let error):
                            print("❌ Login failed: \(error.localizedDescription)")
                            self.presentAuthAlert(title: "Login Failed", message: error.localizedDescription)
                            self.shakeView(sender)
                        }
                    }
                }
            }

    @IBAction func registerButtonTapped(_ sender: UIButton) {
        let email = emailTextField.text ?? ""
               let password = passwordTextField.text ?? ""
               
               // For now, we'll use placeholder names - you can add name fields later
               let firstName = "New"
               let lastName = "User"
               
               guard !email.isEmpty, !password.isEmpty else {
                   presentAuthAlert(title: "Missing Info", message: "Please enter both email and password to register.")
                   return
               }
               
               sender.isEnabled = false
               let originalTitle = sender.title(for: .normal)
               sender.setTitle("Registering...", for: .normal)
               
               FirebaseManager.shared.register(email: email, password: password, firstName: firstName, lastName: lastName) { result in
                   DispatchQueue.main.async {
                       sender.isEnabled = true
                       sender.setTitle(originalTitle, for: .normal)
                       
                       switch result {
                       case .success(let userID):
                           print("✅ Registered successfully! User ID: \(userID)")
                           self.presentAuthAlert(title: "Success", message: "Account created successfully!")
                           // Automatically go to home after successful registration
                           DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                               self.performSegue(withIdentifier: "goToHome", sender: self)
                           }
                           
                       case .failure(let error):
                           print("❌ Registration failed: \(error.localizedDescription)")
                           self.presentAuthAlert(title: "Registration Failed", message: error.localizedDescription)
                       }
                   }
               }
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
   }

// .collection() .doc() stuff to access certain areas within the docs.
