//
//  HomeViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit

private struct AppColors {
    static let background = UIColor(hex: "#F2EDE6")
    static let foreground = UIColor(hex: "#101118")
    static let primary = UIColor(hex: "#213BDB")
    static let secondary = UIColor(hex: "#F92495")
    static let accent = UIColor(hex: "#ECA82F")
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

class HomeViewController: UIViewController {
    private var hasAnimatedEntrance = false
    private let profileContainer = UIStackView()
    private let profileImageView = UIImageView()
    private let profileEmailLabel = UILabel()
    
    private var bgGradientTop = CAGradientLayer()
    private var bgGradientBottom = CAGradientLayer()

    @IBAction func joinSessionTapped(_ sender: UIButton) {
        let _ = sender // keep parameter used
        self.performSegue(withIdentifier: "goToScanner", sender: self)
    }
    
    @IBAction func hostSessionTapped(_ sender: UIButton) {
        let _ = sender
        self.performSegue(withIdentifier: "goToHost", sender: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupAnimatedBackground()
        configureProfileBadgeUI()
        refreshProfileBadge()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfileBadge()
    }
    
    private func configureProfileBadgeUI() {
        profileContainer.axis = .horizontal
        profileContainer.alignment = .center
        profileContainer.spacing = 8
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.isUserInteractionEnabled = false

        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 18
        profileImageView.layer.borderWidth = 1
        profileImageView.layer.borderColor = UIColor.clear.cgColor
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = AppColors.foreground
        profileImageView.backgroundColor = .clear

        profileEmailLabel.translatesAutoresizingMaskIntoConstraints = false
        profileEmailLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        profileEmailLabel.textColor = AppColors.foreground
        profileEmailLabel.numberOfLines = 1
        profileEmailLabel.lineBreakMode = .byTruncatingMiddle
        profileEmailLabel.text = FirebaseManager.shared.getCurrentUserEmail() ?? "Unknown user"

        profileContainer.addArrangedSubview(profileImageView)
        profileContainer.addArrangedSubview(profileEmailLabel)
        view.addSubview(profileContainer)

        NSLayoutConstraint.activate([
            profileImageView.widthAnchor.constraint(equalToConstant: 36),
            profileImageView.heightAnchor.constraint(equalToConstant: 36),
            profileContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            profileContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            profileContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
    }

    private func refreshProfileBadge() {
        profileEmailLabel.text = FirebaseManager.shared.getCurrentUserEmail() ?? "Unknown user"

        FirebaseManager.shared.downloadProfilePicture { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let image):
                    self.profileImageView.image = image
                case .failure:
                    self.profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
                    self.profileImageView.tintColor = AppColors.foreground
                }
            }
        }
    }
    
    private func setupAnimatedBackground() {
        bgGradientTop.removeFromSuperlayer()
        bgGradientBottom.removeFromSuperlayer()
        bgGradientTop.frame = view.bounds
        bgGradientBottom.frame = view.bounds
        bgGradientTop.colors = [AppColors.primary.withAlphaComponent(0.5).cgColor, AppColors.accent.withAlphaComponent(0.5).cgColor]
        bgGradientTop.startPoint = CGPoint(x: 0.2, y: 0.0)
        bgGradientTop.endPoint = CGPoint(x: 0.8, y: 1.0)
        bgGradientBottom.colors = [AppColors.secondary.withAlphaComponent(0.3).cgColor, AppColors.primary.withAlphaComponent(0.2).cgColor]
        bgGradientBottom.startPoint = CGPoint(x: 1.0, y: 0.2)
        bgGradientBottom.endPoint = CGPoint(x: 0.0, y: 0.8)
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath()
        let w = view.bounds.width
        let h = view.bounds.height
        // Bezier ribbon near bottom for distinct look
        path.move(to: CGPoint(x: 0, y: h * 0.72))
        path.addCurve(to: CGPoint(x: w * 0.26, y: h * 0.86), controlPoint1: CGPoint(x: w * 0.12, y: h * 0.58), controlPoint2: CGPoint(x: w * 0.18, y: h * 1.02))
        path.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.78), controlPoint1: CGPoint(x: w * 0.38, y: h * 0.70), controlPoint2: CGPoint(x: w * 0.50, y: h * 0.66))
        path.addCurve(to: CGPoint(x: w, y: h * 0.88), controlPoint1: CGPoint(x: w * 0.74, y: h * 0.92), controlPoint2: CGPoint(x: w * 0.90, y: h * 1.02))
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
        let topStart = CABasicAnimation(keyPath: "startPoint")
        topStart.fromValue = CGPoint(x: 0.2, y: 0.0)
        topStart.toValue = CGPoint(x: 0.0, y: 0.2)
        topStart.duration = 6.0
        topStart.autoreverses = true
        topStart.repeatCount = .infinity
        topStart.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        let topEnd = CABasicAnimation(keyPath: "endPoint")
        topEnd.fromValue = CGPoint(x: 0.8, y: 1.0)
        topEnd.toValue = CGPoint(x: 1.0, y: 0.8)
        topEnd.duration = 6.0
        topEnd.autoreverses = true
        topEnd.repeatCount = .infinity
        topEnd.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bgGradientTop.add(topStart, forKey: "topStart")
        bgGradientTop.add(topEnd, forKey: "topEnd")
        let colorCycle = CAKeyframeAnimation(keyPath: "colors")
        colorCycle.values = [
            [AppColors.secondary.withAlphaComponent(0.3).cgColor, AppColors.primary.withAlphaComponent(0.2).cgColor],
            [AppColors.accent.withAlphaComponent(0.3).cgColor, AppColors.primary.withAlphaComponent(0.2).cgColor],
            [AppColors.secondary.withAlphaComponent(0.3).cgColor, AppColors.accent.withAlphaComponent(0.2).cgColor]
        ]
        colorCycle.keyTimes = [0, 0.5, 1]
        colorCycle.duration = 10.0
        colorCycle.autoreverses = true
        colorCycle.repeatCount = .infinity
        colorCycle.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut)]
        bgGradientBottom.add(colorCycle, forKey: "bottomColors")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bgGradientTop.frame = view.bounds
        bgGradientBottom.frame = view.bounds
        if let maskLayer = bgGradientBottom.mask as? CAShapeLayer {
            let path = UIBezierPath()
            let w = view.bounds.width
            let h = view.bounds.height
            // Bezier ribbon near bottom for distinct look (match setupAnimatedBackground)
            path.move(to: CGPoint(x: 0, y: h * 0.72))
            path.addCurve(to: CGPoint(x: w * 0.26, y: h * 0.86), controlPoint1: CGPoint(x: w * 0.12, y: h * 0.58), controlPoint2: CGPoint(x: w * 0.18, y: h * 1.02))
            path.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.78), controlPoint1: CGPoint(x: w * 0.38, y: h * 0.70), controlPoint2: CGPoint(x: w * 0.50, y: h * 0.66))
            path.addCurve(to: CGPoint(x: w, y: h * 0.88), controlPoint1: CGPoint(x: w * 0.74, y: h * 0.92), controlPoint2: CGPoint(x: w * 0.90, y: h * 1.02))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.close()
            maskLayer.path = path.cgPath
        }
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
