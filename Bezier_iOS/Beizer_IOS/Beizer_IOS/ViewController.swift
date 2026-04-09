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
      
extension UIView {
    static var shouldReduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    func animatePlayfulTap(completion: (() -> Void)? = nil) {
        guard !UIView.shouldReduceMotion else {
            completion?()
            return
        }

        UIView.animate(withDuration: 0.09, delay: 0, options: [.curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.24, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 4.0, options: [.curveEaseInOut], animations: {
                self.transform = .identity
            }) { _ in
                completion?()
            }
        }
    }

    func animateEntrance(delay: TimeInterval = 0, from translationX: CGFloat = -36, translationY: CGFloat = 0) {
        if UIView.shouldReduceMotion {
            alpha = 0
            transform = .identity
            UIView.animate(withDuration: 0.18, delay: delay, options: [.curveEaseOut], animations: {
                self.alpha = 1
            })
            return
        }

        alpha = 0
        transform = CGAffineTransform(translationX: translationX, y: translationY)
        UIView.animate(withDuration: 0.62, delay: delay, usingSpringWithDamping: 0.74, initialSpringVelocity: 0.45, options: [.curveEaseOut], animations: {
            self.alpha = 1
            self.transform = .identity
        })
    }

    func animateSoftPulse() {
        guard !UIView.shouldReduceMotion else { return }
        transform = .identity
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
}


class ViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    
    
    
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            emailTextField.animateEntrance(delay: 0.08, from: -52)
            passwordTextField.animateEntrance(delay: 0.2, from: -52)
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
         
        
        

        sender.animatePlayfulTap()
        
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
                            self.view.animateSoftPulse()
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
        sender.animatePlayfulTap()
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
   }

// .collection() .doc() stuff to access certain areas within the docs.
