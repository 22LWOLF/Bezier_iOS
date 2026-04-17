//
//  HomeViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit

class HomeViewController: UIViewController {
    private var hasAnimatedEntrance = false
    private let profileContainer = UIStackView()
    private let profileImageView = UIImageView()
    private let profileEmailLabel = UILabel()
    
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
        profileImageView.tintColor = .label
        profileImageView.backgroundColor = .clear

        profileEmailLabel.translatesAutoresizingMaskIntoConstraints = false
        profileEmailLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        profileEmailLabel.textColor = .label
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
                    self.profileImageView.tintColor = .label
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

