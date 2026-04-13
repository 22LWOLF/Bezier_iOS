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
    private let backgroundGradientLayer = CAGradientLayer()
    private let backgroundOverscan: CGFloat = 140
    private weak var activeLoginButton: UIButton?
    private let cosmicContainer = CALayer()
    private var cosmicIsRunning = false
    private var cosmicOrigin = CGPoint.zero
    private var cosmicStartTime: CFTimeInterval = 0
    private var cosmicChargeProgress: CGFloat = 0
    private var cosmicDisplayLink: CADisplayLink?
    private var cosmicWobblePhase: CGFloat = 0
    private var cosmicCoreLayer: CAShapeLayer?
    private var isHotGradientTheme = false
    private let fixedButtonBackgroundColor = UIColor(red: 0.07, green: 0.10, blue: 0.18, alpha: 0.9)
    private let fixedButtonTextColor = UIColor.white
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
        setupBackgroundGradient()
        // Style the text fields
                styleTextField(emailTextField)
                styleTextField(passwordTextField)
        setupCosmicContainer()
        installGlobalRipple()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds.insetBy(dx: -backgroundOverscan, dy: -backgroundOverscan)
        cosmicContainer.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetLoginButtonState()
        updateTextFieldTheme()
        applyFixedButtonTheme(in: view)
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
            textField.backgroundColor = .clear
            textField.borderStyle = .none
            
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
        activeLoginButton = sender
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

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.performSegue(withIdentifier: "goToHome", sender: self)
        }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let selectedImage =
            (info[.editedImage] as? UIImage) ??
            (info[.originalImage] as? UIImage)
        let selectedFileName = (info[.imageURL] as? URL)?.lastPathComponent

        picker.dismiss(animated: true) {
            guard let image = selectedImage else {
                self.presentAuthAlert(title: "Photo Error", message: "Could not read selected image.")
                self.performSegue(withIdentifier: "goToHome", sender: self)
                return
            }

            FirebaseManager.shared.uploadProfilePicture(image: image, originalFileName: selectedFileName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.presentAuthAlert(title: "Profile Updated", message: "Your profile photo was uploaded.")
                    case .failure(let error):
                        self.presentAuthAlert(title: "Upload Failed", message: error.localizedDescription)
                    }

                    // Continue into app regardless of upload result.
                    self.performSegue(withIdentifier: "goToHome", sender: self)
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

    private func resetLoginButtonState() {
        activeLoginButton?.isEnabled = true
        activeLoginButton?.setTitle("Login", for: .normal)
        activeLoginButton?.setTitle("Login", for: .disabled)
        activeLoginButton?.setTitle("Login", for: .highlighted)

        // Safety reset in case a different UIButton instance is active after navigation.
        forceResetLoggingButtons(in: view)
    }

    private func forceResetLoggingButtons(in root: UIView) {
        if let button = root as? UIButton {
            let states: [UIControl.State] = [.normal, .disabled, .highlighted, .selected]
            let isLoggingTitle = states.contains { (button.title(for: $0) ?? "").contains("Logging in") }
            if isLoggingTitle {
                button.isEnabled = true
                button.setTitle("Login", for: .normal)
                button.setTitle("Login", for: .disabled)
                button.setTitle("Login", for: .highlighted)
                button.setTitle("Login", for: .selected)
            }
        }

        root.subviews.forEach { child in
            forceResetLoggingButtons(in: child)
        }
    }
    
    private func installGlobalRipple() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCosmicLongPress(_:)))
        longPress.minimumPressDuration = 0.55
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
        view.addGestureRecognizer(longPress)
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        ripple(at: point, in: view, color: .systemTeal)
        waterSurfaceRipple(at: point)
    }

    @objc private func handleCosmicLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: view)
        switch gesture.state {
        case .began:
            startCosmicCharge(at: point)
        case .changed:
            updateCosmicCharge(at: point)
        case .ended, .cancelled, .failed:
            releaseCosmicBurst(at: point)
        default:
            break
        }
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
        let ring = CAShapeLayer()
        ring.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        ring.position = point
        ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
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

    private func setupBackgroundGradient() {
        isHotGradientTheme = false
        backgroundGradientLayer.colors = [
            UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1).cgColor,
            UIColor(red: 0.20, green: 0.16, blue: 0.36, alpha: 1).cgColor,
            UIColor(red: 0.08, green: 0.22, blue: 0.34, alpha: 1).cgColor
        ]
        backgroundGradientLayer.startPoint = CGPoint(x: 0.1, y: 0.1)
        backgroundGradientLayer.endPoint = CGPoint(x: 0.9, y: 0.9)
        backgroundGradientLayer.locations = [-0.2, 0.35, 1.15]
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        updateTextFieldTheme()
        animateGradientFlow()
    }

    private func animateGradientFlow() {
        guard !shouldReduceMotion else { return }
        backgroundGradientLayer.removeAnimation(forKey: "bgStartShift")
        backgroundGradientLayer.removeAnimation(forKey: "bgEndShift")
        backgroundGradientLayer.removeAnimation(forKey: "bgLocations")
        backgroundGradientLayer.removeAnimation(forKey: "bgColorCycle")
        backgroundGradientLayer.removeAnimation(forKey: "bgDrift")

        let startShift = CABasicAnimation(keyPath: "startPoint")
        startShift.fromValue = CGPoint(x: 0.1, y: 0.1)
        startShift.toValue = CGPoint(x: 1.0, y: 0.0)
        startShift.duration = 5.5
        startShift.autoreverses = true
        startShift.repeatCount = .infinity
        startShift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let endShift = CABasicAnimation(keyPath: "endPoint")
        endShift.fromValue = CGPoint(x: 0.9, y: 0.9)
        endShift.toValue = CGPoint(x: 0.0, y: 1.0)
        endShift.duration = 5.5
        endShift.autoreverses = true
        endShift.repeatCount = .infinity
        endShift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let locationsSlide = CAKeyframeAnimation(keyPath: "locations")
        locationsSlide.values = [
            [-0.35, 0.2, 0.9],
            [-0.2, 0.45, 1.2],
            [0.0, 0.65, 1.35],
            [-0.35, 0.2, 0.9]
        ]
        locationsSlide.keyTimes = [0, 0.34, 0.68, 1]
        locationsSlide.duration = 7.0
        locationsSlide.repeatCount = .infinity
        locationsSlide.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let colorCycle = CAKeyframeAnimation(keyPath: "colors")
        if isHotGradientTheme {
            colorCycle.values = [
                [
                    UIColor(red: 0.42, green: 0.08, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.82, green: 0.24, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.98, green: 0.72, blue: 0.08, alpha: 1).cgColor
                ],
                [
                    UIColor(red: 0.60, green: 0.12, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.95, green: 0.38, blue: 0.04, alpha: 1).cgColor,
                    UIColor(red: 1.00, green: 0.82, blue: 0.16, alpha: 1).cgColor
                ],
                [
                    UIColor(red: 0.35, green: 0.06, blue: 0.01, alpha: 1).cgColor,
                    UIColor(red: 0.78, green: 0.18, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.98, green: 0.66, blue: 0.04, alpha: 1).cgColor
                ],
                [
                    UIColor(red: 0.42, green: 0.08, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.82, green: 0.24, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.98, green: 0.72, blue: 0.08, alpha: 1).cgColor
                ]
            ]
        } else {
            colorCycle.values = [
                [
                    UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1).cgColor,
                    UIColor(red: 0.20, green: 0.16, blue: 0.36, alpha: 1).cgColor,
                    UIColor(red: 0.08, green: 0.22, blue: 0.34, alpha: 1).cgColor
                ],
                [
                    UIColor(red: 0.06, green: 0.20, blue: 0.30, alpha: 1).cgColor,
                    UIColor(red: 0.22, green: 0.10, blue: 0.34, alpha: 1).cgColor,
                    UIColor(red: 0.14, green: 0.16, blue: 0.44, alpha: 1).cgColor
                ],
                [
                    UIColor(red: 0.12, green: 0.10, blue: 0.30, alpha: 1).cgColor,
                    UIColor(red: 0.08, green: 0.26, blue: 0.40, alpha: 1).cgColor,
                    UIColor(red: 0.26, green: 0.12, blue: 0.42, alpha: 1).cgColor
                ],
                [
                    UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1).cgColor,
                    UIColor(red: 0.20, green: 0.16, blue: 0.36, alpha: 1).cgColor,
                    UIColor(red: 0.08, green: 0.22, blue: 0.34, alpha: 1).cgColor
                ]
            ]
        }
        colorCycle.keyTimes = [0, 0.33, 0.66, 1]
        colorCycle.duration = 10.0
        colorCycle.repeatCount = .infinity
        colorCycle.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let drift = CAKeyframeAnimation(keyPath: "transform.translation")
        drift.values = [
            NSValue(cgSize: .zero),
            NSValue(cgSize: CGSize(width: 28, height: -18)),
            NSValue(cgSize: CGSize(width: -20, height: 22)),
            NSValue(cgSize: .zero)
        ]
        drift.keyTimes = [0, 0.34, 0.67, 1]
        drift.duration = 9.5
        drift.repeatCount = .infinity
        drift.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        backgroundGradientLayer.add(startShift, forKey: "bgStartShift")
        backgroundGradientLayer.add(endShift, forKey: "bgEndShift")
        backgroundGradientLayer.add(locationsSlide, forKey: "bgLocations")
        backgroundGradientLayer.add(colorCycle, forKey: "bgColorCycle")
        backgroundGradientLayer.add(drift, forKey: "bgDrift")
    }

    private func applyHotGradientTheme() {
        isHotGradientTheme = true
        backgroundGradientLayer.colors = [
            UIColor(red: 0.42, green: 0.08, blue: 0.02, alpha: 1).cgColor,
            UIColor(red: 0.82, green: 0.24, blue: 0.02, alpha: 1).cgColor,
            UIColor(red: 0.98, green: 0.72, blue: 0.08, alpha: 1).cgColor
        ]
        updateTextFieldTheme()
        animateGradientFlow()
    }

    private func applyCoolGradientTheme() {
        isHotGradientTheme = false
        backgroundGradientLayer.colors = [
            UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1).cgColor,
            UIColor(red: 0.20, green: 0.16, blue: 0.36, alpha: 1).cgColor,
            UIColor(red: 0.08, green: 0.22, blue: 0.34, alpha: 1).cgColor
        ]
        updateTextFieldTheme()
        animateGradientFlow()
    }

    private func updateTextFieldTheme() {
        let textColor: UIColor = isHotGradientTheme ? .black : .white
        let placeholderColor: UIColor = isHotGradientTheme
            ? UIColor.black.withAlphaComponent(0.6)
            : UIColor.white.withAlphaComponent(0.72)
        let borderColor: UIColor = isHotGradientTheme
            ? UIColor.black.withAlphaComponent(0.75)
            : UIColor.white.withAlphaComponent(0.75)

        [emailTextField, passwordTextField].forEach { field in
            guard let field else { return }
            field.textColor = textColor
            field.layer.borderColor = borderColor.cgColor
            if let placeholder = field.placeholder {
                field.attributedPlaceholder = NSAttributedString(
                    string: placeholder,
                    attributes: [.foregroundColor: placeholderColor]
                )
            }
        }

        // Keep on-screen labels/button titles aligned with active theme.
        let themedLabelColor: UIColor = textColor
        applyThemeColorRecursively(in: view, color: themedLabelColor)
        applyFixedButtonTheme(in: view)
    }

    private func applyThemeColorRecursively(in root: UIView, color: UIColor) {
        if let label = root as? UILabel {
            label.textColor = color
        }

        root.subviews.forEach { child in
            // Keep text fields on their own themed logic.
            if !(child is UITextField) {
                applyThemeColorRecursively(in: child, color: color)
            }
        }
    }

    private func applyFixedButtonTheme(in root: UIView) {
        if let button = root as? UIButton {
            button.backgroundColor = fixedButtonBackgroundColor
            button.setTitleColor(fixedButtonTextColor, for: .normal)
            button.setTitleColor(fixedButtonTextColor.withAlphaComponent(0.75), for: .highlighted)
            button.setTitleColor(fixedButtonTextColor.withAlphaComponent(0.75), for: .disabled)
            button.setTitleColor(fixedButtonTextColor, for: .selected)
            button.tintColor = fixedButtonTextColor
            button.layer.cornerRadius = 10
        }
        root.subviews.forEach { child in
            applyFixedButtonTheme(in: child)
        }
    }

    private func setupCosmicContainer() {
        cosmicContainer.frame = view.bounds
        cosmicContainer.zPosition = 999
        view.layer.addSublayer(cosmicContainer)
    }

    private func startCosmicCharge(at point: CGPoint) {
        guard !cosmicIsRunning else { return }
        cosmicIsRunning = true
        cosmicOrigin = point
        cosmicStartTime = CACurrentMediaTime()
        cosmicChargeProgress = 0
        cosmicWobblePhase = 0
        cosmicContainer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let core = CAShapeLayer()
        core.bounds = CGRect(x: 0, y: 0, width: 120, height: 120)
        core.position = point
        core.path = UIBezierPath(ovalIn: core.bounds).cgPath
        core.fillColor = UIColor.systemCyan.withAlphaComponent(0.35).cgColor
        core.shadowColor = UIColor.systemPurple.cgColor
        core.shadowRadius = 30
        core.shadowOpacity = 0.8
        core.shadowOffset = .zero
        cosmicContainer.addSublayer(core)
        cosmicCoreLayer = core

        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [0.12, 1.0, 0.86, 1.08, 1.0]
        pulse.keyTimes = [0, 0.22, 0.48, 0.75, 1]
        pulse.duration = 1.15
        pulse.repeatCount = .infinity
        pulse.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
        core.add(pulse, forKey: "cosmicCorePulse")

        let glowCycle = CAKeyframeAnimation(keyPath: "fillColor")
        glowCycle.values = [
            UIColor.systemCyan.withAlphaComponent(0.34).cgColor,
            UIColor.systemPink.withAlphaComponent(0.36).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.34).cgColor,
            UIColor.systemTeal.withAlphaComponent(0.36).cgColor,
            UIColor.systemCyan.withAlphaComponent(0.34).cgColor
        ]
        glowCycle.duration = 1.7
        glowCycle.repeatCount = .infinity
        core.add(glowCycle, forKey: "cosmicFillCycle")

        for index in 0..<4 {
            let ring = CAShapeLayer()
            let size = CGFloat(180 + (index * 70))
            ring.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            ring.position = point
            ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
            ring.fillColor = UIColor.clear.cgColor
            ring.strokeColor = UIColor.white.withAlphaComponent(0.24 - CGFloat(index) * 0.03).cgColor
            ring.lineWidth = 2.0 - CGFloat(index) * 0.2
            cosmicContainer.addSublayer(ring)

            let group = CAAnimationGroup()
            let expand = CABasicAnimation(keyPath: "transform.scale")
            expand.fromValue = 0.45
            expand.toValue = 1.18 + CGFloat(index) * 0.05
            expand.duration = 1.0 + Double(index) * 0.04

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.6
            fade.toValue = 0.2
            fade.duration = 1.0 + Double(index) * 0.04

            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * (index % 2 == 0 ? 1.3 : -1.3)
            spin.duration = 1.0 + Double(index) * 0.04

            group.animations = [expand, fade, spin]
            group.duration = 1.1 + Double(index) * 0.06
            group.repeatCount = .infinity
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            ring.add(group, forKey: "cosmicRing\(index)")
        }
        startCosmicHoldWobble()
    }

    private func updateCosmicCharge(at point: CGPoint) {
        guard cosmicIsRunning else { return }
        cosmicOrigin = point
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cosmicContainer.sublayers?.forEach { layer in
            if let shape = layer as? CAShapeLayer {
                shape.position = point
            }
        }
        CATransaction.commit()
        refreshCosmicChargeState()
    }

    private func releaseCosmicBurst(at point: CGPoint) {
        guard cosmicIsRunning else { return }
        cosmicContainer.sublayers?.forEach { $0.removeAllAnimations() }
        stopCosmicHoldWobble()
        let reachedOverload = cosmicChargeProgress >= 1.0

        let deathEmitter = CAEmitterLayer()
        deathEmitter.emitterPosition = point
        deathEmitter.emitterShape = .circle
        deathEmitter.emitterSize = CGSize(width: 14, height: 14)
        deathEmitter.renderMode = .additive
        let symbols = ["sparkle", "circle.fill", "triangle.fill", "seal.fill", "star.fill"]
        deathEmitter.emitterCells = symbols.enumerated().map { idx, symbol in
            let cell = CAEmitterCell()
            cell.birthRate = 220 / Float(idx + 1)
            cell.lifetime = 2.2
            cell.lifetimeRange = 0.9
            cell.velocity = 240 + CGFloat(idx * 35)
            cell.velocityRange = 120
            cell.emissionRange = .pi * 2
            cell.spin = 5
            cell.spinRange = 8
            cell.scale = 0.07
            cell.scaleRange = 0.05
            cell.alphaSpeed = -0.6
            let palette: [UIColor] = [.white, .systemYellow, .systemPink, .systemTeal, .systemPurple]
            let color = palette[idx % palette.count]
            cell.contents = UIImage(systemName: symbol)?.withTintColor(color, renderingMode: .alwaysOriginal).cgImage
            return cell
        }
        cosmicContainer.addSublayer(deathEmitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { deathEmitter.birthRate = 0 }
        if reachedOverload {
            if isHotGradientTheme {
                applyCoolGradientTheme()
            } else {
                applyHotGradientTheme()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            self.cosmicContainer.sublayers?.forEach { $0.removeFromSuperlayer() }
            self.cosmicIsRunning = false
            self.cosmicCoreLayer = nil
            self.cosmicChargeProgress = 0
        }
    }

    private func startCosmicHoldWobble() {
        guard !shouldReduceMotion else { return }
        cosmicDisplayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(handleCosmicTick(_:)))
        link.add(to: .main, forMode: .common)
        cosmicDisplayLink = link
    }

    private func stopCosmicHoldWobble() {
        cosmicDisplayLink?.invalidate()
        cosmicDisplayLink = nil
        UIView.animate(withDuration: 0.12) {
            self.view.transform = .identity
        }
    }

    @objc private func handleCosmicTick(_ link: CADisplayLink) {
        guard cosmicIsRunning else { return }
        refreshCosmicChargeState()
        let frequency = 7 + (26 * cosmicChargeProgress)
        let amplitude = 1.5 + (11 * cosmicChargeProgress)
        cosmicWobblePhase += CGFloat(link.duration) * CGFloat.pi * frequency

        let tx = sin(cosmicWobblePhase) * amplitude
        let ty = cos(cosmicWobblePhase * 1.33) * amplitude * 0.72
        let rot = sin(cosmicWobblePhase * 0.82) * (0.015 + 0.035 * cosmicChargeProgress)
        view.transform = CGAffineTransform(translationX: tx, y: ty).rotated(by: rot)
    }

    private func refreshCosmicChargeState() {
        let elapsed = CACurrentMediaTime() - cosmicStartTime
        cosmicChargeProgress = min(max(CGFloat(elapsed / 2.8), 0), 1)

        guard let core = cosmicCoreLayer else { return }
        let maxDiameter = max(view.bounds.width, view.bounds.height) * 1.55
        let diameter = 120 + (maxDiameter - 120) * cosmicChargeProgress
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        core.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        core.path = UIBezierPath(ovalIn: core.bounds).cgPath
        core.shadowRadius = 30 + 70 * cosmicChargeProgress
        core.shadowOpacity = Float(0.45 + 0.4 * cosmicChargeProgress)
        CATransaction.commit()
    }

    private func waterSurfaceRipple(at point: CGPoint, intensity: CGFloat = 1.0, flow: CGPoint = .zero) {
        guard !shouldReduceMotion else { return }
        let localPoint = view.layer.convert(point, to: backgroundGradientLayer)

        let maxRadius = max(view.bounds.width, view.bounds.height) * (0.42 * intensity)
        let ringCount = intensity >= 0.8 ? 3 : 2
        let speed = hypot(flow.x, flow.y)
        let clampedSpeed = min(max(speed / 1700, 0), 1)
        let majorScale = 1 + (0.7 * clampedSpeed)
        let minorScale = max(0.58, 1 - (0.34 * clampedSpeed))
        let motionAngle = atan2(flow.y, flow.x)
        let perpendicularAngle = motionAngle + (.pi / 2)
        let driftDistance = maxRadius * 0.08 * clampedSpeed
        let driftVector = CGPoint(x: cos(motionAngle) * driftDistance, y: sin(motionAngle) * driftDistance)
        let wakePoint = CGPoint(x: localPoint.x - driftVector.x, y: localPoint.y - driftVector.y)

        let craterLayer = CAShapeLayer()
        let craterSize = maxRadius * 0.18
        craterLayer.bounds = CGRect(x: 0, y: 0, width: craterSize, height: craterSize)
        craterLayer.position = wakePoint
        craterLayer.path = UIBezierPath(ovalIn: craterLayer.bounds).cgPath
        craterLayer.fillColor = UIColor.black.withAlphaComponent(0.24 * intensity).cgColor
        craterLayer.strokeColor = UIColor.black.withAlphaComponent(0.35 * intensity).cgColor
        craterLayer.lineWidth = 0.8
        backgroundGradientLayer.addSublayer(craterLayer)

        let craterScale = CAKeyframeAnimation(keyPath: "transform.scale")
        craterScale.values = [0.18, 1.05, 0.78, 1.12, 1.0]
        craterScale.keyTimes = [0.0, 0.24, 0.52, 0.78, 1.0]
        let craterFade = CAKeyframeAnimation(keyPath: "opacity")
        craterFade.values = [0.85, 0.6, 0.45, 0.2, 0]
        craterFade.keyTimes = [0.0, 0.25, 0.55, 0.82, 1.0]
        let craterGroup = CAAnimationGroup()
        craterGroup.animations = [craterScale, craterFade]
        craterGroup.duration = 0.72
        craterGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        craterGroup.fillMode = .forwards
        craterGroup.isRemovedOnCompletion = false
        craterLayer.add(craterGroup, forKey: "waterCrater")
        if clampedSpeed > 0.02 {
            craterLayer.setAffineTransform(CGAffineTransform(rotationAngle: perpendicularAngle).scaledBy(x: minorScale, y: majorScale))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + craterGroup.duration + 0.08) { craterLayer.removeFromSuperlayer() }

        let innerRing = CAShapeLayer()
        let innerSize = maxRadius * 0.12
        innerRing.bounds = CGRect(x: 0, y: 0, width: innerSize, height: innerSize)
        innerRing.position = wakePoint
        innerRing.path = UIBezierPath(ovalIn: innerRing.bounds).cgPath
        innerRing.fillColor = UIColor.clear.cgColor
        innerRing.strokeColor = UIColor.white.withAlphaComponent(0.45 * intensity).cgColor
        innerRing.lineWidth = 1.0
        innerRing.opacity = 0
        if clampedSpeed > 0.02 {
            innerRing.setAffineTransform(CGAffineTransform(rotationAngle: perpendicularAngle).scaledBy(x: minorScale, y: majorScale))
        }
        backgroundGradientLayer.addSublayer(innerRing)

        let innerScale = CABasicAnimation(keyPath: "transform.scale")
        innerScale.fromValue = 0.25
        innerScale.toValue = 2.2
        let innerOpacity = CAKeyframeAnimation(keyPath: "opacity")
        innerOpacity.values = [0, 0.7, 0]
        innerOpacity.keyTimes = [0, 0.2, 1]
        let innerGroup = CAAnimationGroup()
        innerGroup.animations = [innerScale, innerOpacity]
        innerGroup.duration = 0.42
        innerGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        innerGroup.fillMode = .forwards
        innerGroup.isRemovedOnCompletion = false
        innerRing.add(innerGroup, forKey: "innerWaterRing")
        DispatchQueue.main.asyncAfter(deadline: .now() + innerGroup.duration + 0.08) { innerRing.removeFromSuperlayer() }

        for index in 0..<ringCount {
            let delay = Double(index) * 0.11
            let ringLayer = CAShapeLayer()
            ringLayer.bounds = CGRect(x: 0, y: 0, width: maxRadius, height: maxRadius)
            ringLayer.position = wakePoint
            ringLayer.path = UIBezierPath(ovalIn: ringLayer.bounds).cgPath
            ringLayer.fillColor = UIColor.clear.cgColor
            ringLayer.strokeColor = UIColor(red: 0.12, green: 0.18, blue: 0.28, alpha: 1).withAlphaComponent((0.42 - CGFloat(index) * 0.1) * intensity).cgColor
            ringLayer.lineWidth = 1.2
            ringLayer.opacity = 0
            ringLayer.shadowColor = UIColor.black.withAlphaComponent(0.35).cgColor
            ringLayer.shadowOpacity = 0.5
            ringLayer.shadowRadius = 2.4
            ringLayer.shadowOffset = .zero
            if clampedSpeed > 0.02 {
                let progressiveMajor = majorScale + (CGFloat(index) * 0.06)
                let progressiveMinor = max(0.52, minorScale - (CGFloat(index) * 0.02))
                ringLayer.setAffineTransform(CGAffineTransform(rotationAngle: perpendicularAngle).scaledBy(x: progressiveMinor, y: progressiveMajor))
            }
            backgroundGradientLayer.addSublayer(ringLayer)

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.02
            scale.toValue = 1.0

            let fadeInOut = CAKeyframeAnimation(keyPath: "opacity")
            fadeInOut.values = [0, 0.65, 0.22, 0]
            fadeInOut.keyTimes = [0, 0.18, 0.6, 1]

            let group = CAAnimationGroup()
            group.animations = [scale, fadeInOut]
            group.duration = 1.1
            group.beginTime = CACurrentMediaTime() + delay
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            ringLayer.add(group, forKey: "waterRing")

            DispatchQueue.main.asyncAfter(deadline: .now() + group.duration + delay + 0.1) { ringLayer.removeFromSuperlayer() }
        }

        let shimmer = CABasicAnimation(keyPath: "opacity")
        shimmer.fromValue = 1
        shimmer.toValue = 0.91
        shimmer.duration = 0.16
        shimmer.autoreverses = true
        shimmer.repeatCount = 1
        backgroundGradientLayer.add(shimmer, forKey: "surfaceShimmer")

        let highlightLayer = CAGradientLayer()
        let highlightSize = maxRadius * 0.42
        highlightLayer.bounds = CGRect(x: 0, y: 0, width: highlightSize, height: highlightSize)
        highlightLayer.position = wakePoint
        highlightLayer.type = .radial
        highlightLayer.colors = [
            UIColor.white.withAlphaComponent(0.22 * intensity).cgColor,
            UIColor.white.withAlphaComponent(0.08 * intensity).cgColor,
            UIColor.clear.cgColor
        ]
        highlightLayer.locations = [0.0, 0.4, 1.0]
        if clampedSpeed > 0.02 {
            highlightLayer.setAffineTransform(CGAffineTransform(rotationAngle: perpendicularAngle).scaledBy(x: minorScale, y: majorScale))
        }
        backgroundGradientLayer.addSublayer(highlightLayer)

        let hScale = CABasicAnimation(keyPath: "transform.scale")
        hScale.fromValue = 0.3
        hScale.toValue = 1.35
        let hFade = CABasicAnimation(keyPath: "opacity")
        hFade.fromValue = 0.7
        hFade.toValue = 0
        let hGroup = CAAnimationGroup()
        hGroup.animations = [hScale, hFade]
        hGroup.duration = 0.58
        hGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        hGroup.fillMode = .forwards
        hGroup.isRemovedOnCompletion = false
        highlightLayer.add(hGroup, forKey: "waterHighlight")
        DispatchQueue.main.asyncAfter(deadline: .now() + hGroup.duration + 0.08) { highlightLayer.removeFromSuperlayer() }
    }
}

// .collection() .doc() stuff to access certain areas within the docs.
