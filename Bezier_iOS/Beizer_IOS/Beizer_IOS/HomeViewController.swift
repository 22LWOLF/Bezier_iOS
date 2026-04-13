//
//  HomeViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit

class HomeViewController: UIViewController, UIGestureRecognizerDelegate {
    private var hasAnimatedEntrance = false
    private let profileContainer = UIStackView()
    private let profileImageView = UIImageView()
    private let profileEmailLabel = UILabel()
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
        configureProfileBadgeUI()
        refreshProfileBadge()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfileBadge()
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
        profileImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = .white
        profileImageView.backgroundColor = UIColor.black.withAlphaComponent(0.18)

        profileEmailLabel.translatesAutoresizingMaskIntoConstraints = false
        profileEmailLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        profileEmailLabel.textColor = .white
        profileEmailLabel.numberOfLines = 1
        profileEmailLabel.lineBreakMode = .byTruncatingMiddle
        profileEmailLabel.text = FirebaseManager.shared.getCurrentUserEmail() ?? "Unknown user"

        profileContainer.addArrangedSubview(profileImageView)
        profileContainer.addArrangedSubview(profileEmailLabel)
        view.addSubview(profileContainer)

        NSLayoutConstraint.activate([
            profileImageView.widthAnchor.constraint(equalToConstant: 36),
            profileImageView.heightAnchor.constraint(equalToConstant: 36),
            profileContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            profileContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            profileContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16)
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
                    self.profileImageView.tintColor = .white
                }
            }
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
