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

private struct AppColors {
    static let background = UIColor(hex: "#F2EDE6")
    static let foreground = UIColor(hex: "#101118")
    static let primary = UIColor(hex: "#213BDB")
    static let secondary = UIColor(hex: "#F92495")
    static let accent = UIColor(hex: "#ECA82F")
    // Optional website suggestions
    static let altBackground = UIColor(hex: "#92028b")
    static let button = UIColor(hex: "#B300AB")
}

private extension UIColor {
    convenience init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

class ViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var logoImageView: UIImageView!
    
    private var bgGradientTop = CAGradientLayer()
    private var bgGradientBottom = CAGradientLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupAnimatedBackground()
        // Style the text fields for a neutral look
        styleTextField(emailTextField)
        styleTextField(passwordTextField)
        
        // Configure logo image if connected
        if let logoImageView = self.logoImageView {
            // Replace "BezierLogo" with your exact asset name (no file extension)
            if let img = UIImage(named: "BezierLogo") {
                logoImageView.image = img
            } else {
                logoImageView.image = UIImage(systemName: "photo")
            }
            logoImageView.contentMode = .scaleAspectFit
            logoImageView.tintColor = nil
            logoImageView.translatesAutoresizingMaskIntoConstraints = false
            // If no constraints exist from storyboard and it's directly under self.view, add safe defaults centered above fields
            if logoImageView.superview === self.view {
                let hasConstraints = !(logoImageView.constraints.isEmpty) || !(logoImageView.superview?.constraints.filter { ($0.firstItem as? UIView) === logoImageView || ($0.secondItem as? UIView) === logoImageView }.isEmpty ?? true)
                if !hasConstraints {
                    NSLayoutConstraint.activate([
                        logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
                        logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                        logoImageView.widthAnchor.constraint(equalToConstant: 160),
                        logoImageView.heightAnchor.constraint(equalToConstant: 72)
                    ])
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure buttons look standard system
        applyFixedButtonTheme(in: view)
        // Reapply button theme to avoid white title sticking
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyFixedButtonTheme(in: view)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bgGradientTop.frame = view.bounds
        bgGradientBottom.frame = view.bounds
        if let maskLayer = bgGradientBottom.mask as? CAShapeLayer {
            let path = UIBezierPath()
            let w = view.bounds.width
            let h = view.bounds.height
            // Bezier ribbon sweeping across upper third
            path.move(to: CGPoint(x: 0, y: h * 0.18))
            path.addCurve(to: CGPoint(x: w * 0.35, y: h * 0.12), controlPoint1: CGPoint(x: w * 0.12, y: h * 0.30), controlPoint2: CGPoint(x: w * 0.22, y: h * 0.02))
            path.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.22), controlPoint1: CGPoint(x: w * 0.48, y: h * 0.22), controlPoint2: CGPoint(x: w * 0.58, y: h * 0.30))
            path.addCurve(to: CGPoint(x: w, y: h * 0.16), controlPoint1: CGPoint(x: w * 0.82, y: h * 0.14), controlPoint2: CGPoint(x: w * 0.92, y: h * 0.04))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.close()
            maskLayer.path = path.cgPath
        }
    }
    
    private func setupAnimatedBackground() {
        // Configure two overlapping gradients to create a wavy blended look
        bgGradientTop.removeFromSuperlayer()
        bgGradientBottom.removeFromSuperlayer()

        bgGradientTop.frame = view.bounds
        bgGradientBottom.frame = view.bounds

        bgGradientTop.colors = [
            AppColors.primary.withAlphaComponent(0.55).cgColor,
            AppColors.accent.withAlphaComponent(0.55).cgColor
        ]
        bgGradientTop.startPoint = CGPoint(x: 0.0, y: 0.0)
        bgGradientTop.endPoint = CGPoint(x: 1.0, y: 1.0)

        bgGradientBottom.colors = [
            AppColors.secondary.withAlphaComponent(0.35).cgColor,
            AppColors.primary.withAlphaComponent(0.25).cgColor
        ]
        bgGradientBottom.startPoint = CGPoint(x: 1.0, y: 0.0)
        bgGradientBottom.endPoint = CGPoint(x: 0.0, y: 1.0)

        // Add subtle curved mask to the bottom gradient for a wavy feel
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath()
        let w = view.bounds.width
        let h = view.bounds.height
        // Bezier ribbon sweeping across upper third
        path.move(to: CGPoint(x: 0, y: h * 0.18))
        path.addCurve(to: CGPoint(x: w * 0.35, y: h * 0.12), controlPoint1: CGPoint(x: w * 0.12, y: h * 0.30), controlPoint2: CGPoint(x: w * 0.22, y: h * 0.02))
        path.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.22), controlPoint1: CGPoint(x: w * 0.48, y: h * 0.22), controlPoint2: CGPoint(x: w * 0.58, y: h * 0.30))
        path.addCurve(to: CGPoint(x: w, y: h * 0.16), controlPoint1: CGPoint(x: w * 0.82, y: h * 0.14), controlPoint2: CGPoint(x: w * 0.92, y: h * 0.04))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.close()
        maskLayer.path = path.cgPath
        bgGradientBottom.mask = maskLayer

        view.layer.insertSublayer(bgGradientTop, at: 0)
        view.layer.insertSublayer(bgGradientBottom, above: bgGradientTop)

        animateBackgroundGradients()
    }
    
    private func animateBackgroundGradients() {
        // Animate top gradient start/end points
        let topStart = CABasicAnimation(keyPath: "startPoint")
        topStart.fromValue = CGPoint(x: 0.0, y: 0.0)
        topStart.toValue = CGPoint(x: 0.2, y: 0.1)
        topStart.duration = 6.0
        topStart.autoreverses = true
        topStart.repeatCount = .infinity
        topStart.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let topEnd = CABasicAnimation(keyPath: "endPoint")
        topEnd.fromValue = CGPoint(x: 1.0, y: 1.0)
        topEnd.toValue = CGPoint(x: 0.8, y: 0.9)
        topEnd.duration = 6.0
        topEnd.autoreverses = true
        topEnd.repeatCount = .infinity
        topEnd.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        bgGradientTop.add(topStart, forKey: "topStart")
        bgGradientTop.add(topEnd, forKey: "topEnd")

        // Animate bottom gradient colors to gently cycle accent/secondary hues
        let colorCycle = CAKeyframeAnimation(keyPath: "colors")
        colorCycle.values = [
            [AppColors.secondary.withAlphaComponent(0.35).cgColor, AppColors.primary.withAlphaComponent(0.25).cgColor],
            [AppColors.accent.withAlphaComponent(0.35).cgColor, AppColors.primary.withAlphaComponent(0.25).cgColor],
            [AppColors.secondary.withAlphaComponent(0.35).cgColor, AppColors.accent.withAlphaComponent(0.25).cgColor]
        ]
        colorCycle.keyTimes = [0, 0.5, 1]
        colorCycle.duration = 10.0
        colorCycle.autoreverses = true
        colorCycle.repeatCount = .infinity
        colorCycle.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut)]
        bgGradientBottom.add(colorCycle, forKey: "bottomColors")
    }
    
    func styleTextField(_ textField: UITextField) {
        // Add rounded corners
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = AppColors.foreground.withAlphaComponent(0.2).cgColor
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.textColor = .label
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder ?? "", attributes: [.foregroundColor: AppColors.foreground.withAlphaComponent(0.5)])
        
        // Add padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
    }
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        if email.isEmpty || password.isEmpty {
            presentAuthAlert(title: "Missing Info", message: "Please enter both email and password")
            return
        }
        sender.isEnabled = false
        let originalTitle = sender.title(for: .normal)
        FirebaseManager.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                sender.isEnabled = true
                sender.setTitle(originalTitle, for: .normal)
                switch result {
                case .success:
                    self.performSegue(withIdentifier: "goToHome", sender: self)
                case .failure(let error):
                    self.presentAuthAlert(title: "Login Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    @IBAction func registerButtonTapped(_ sender: UIButton) {
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        guard !email.isEmpty, !password.isEmpty else {
            presentAuthAlert(title: "Missing Info", message: "Please enter both email and password to register.")
            return
        }
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
    
    private func presentAuthAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    private func applyFixedButtonTheme(in root: UIView) {
        if let button = root as? UIButton {
            button.backgroundColor = UIColor(hex: "#F92495")
            button.setTitleColor(.white, for: .normal)
            button.setTitleColor(UIColor.white.withAlphaComponent(0.85), for: .highlighted)
            button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .disabled)
            button.setTitleColor(.white, for: .selected)
            button.tintColor = .white
            button.layer.cornerRadius = 10
            if var config = button.configuration {
                config.baseBackgroundColor = UIColor(hex: "#F92495")
                config.baseForegroundColor = .white
                button.configuration = config
            }
        }
        root.subviews.forEach { child in
            applyFixedButtonTheme(in: child)
        }
    }
}

