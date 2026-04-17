//
//  HostSessionViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit
import FirebaseFirestore
import CoreImage

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

class HostSessionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var attendeeCountLabel: UILabel!
    @IBOutlet weak var attendeeTableView: UITableView!

    var sessionId: String = ""
    var participants: [ParticipantInfo] = []
    var listener: ListenerRegistration?
    private var previousParticipantCount: Int = 0
    
    private var bgGradientTop = CAGradientLayer()
    private var bgGradientBottom = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = AppColors.background
        setupAnimatedBackground()
        
        attendeeTableView.separatorColor = AppColors.foreground.withAlphaComponent(0.2)
        attendeeCountLabel.textColor = AppColors.foreground
        
        attendeeTableView.delegate = self
        attendeeTableView.dataSource = self
        attendeeCountLabel.text = "Attendees: 0"
        
        // Create session in Firebase
        createSession()
    }
    
    private func setupAnimatedBackground() {
        bgGradientTop.removeFromSuperlayer()
        bgGradientBottom.removeFromSuperlayer()
        bgGradientTop.frame = view.bounds
        bgGradientBottom.frame = view.bounds
        
        bgGradientTop.colors = [AppColors.primary.withAlphaComponent(0.5).cgColor, AppColors.accent.withAlphaComponent(0.5).cgColor]
        bgGradientTop.startPoint = CGPoint(x: 0.0, y: 1.0)
        bgGradientTop.endPoint = CGPoint(x: 1.0, y: 0.0)
        
        bgGradientBottom.colors = [AppColors.secondary.withAlphaComponent(0.3).cgColor, AppColors.primary.withAlphaComponent(0.2).cgColor]
        bgGradientBottom.startPoint = CGPoint(x: 0.0, y: 0.0)
        bgGradientBottom.endPoint = CGPoint(x: 1.0, y: 1.0)
        
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath()
        let w = view.bounds.width
        let h = view.bounds.height
        // Bezier ribbon along the very top for distinct orientation
        path.move(to: CGPoint(x: 0, y: h * 0.08))
        path.addCurve(to: CGPoint(x: w * 0.28, y: h * 0.02), controlPoint1: CGPoint(x: w * 0.10, y: h * 0.20), controlPoint2: CGPoint(x: w * 0.18, y: h * -0.06))
        path.addCurve(to: CGPoint(x: w * 0.68, y: h * 0.10), controlPoint1: CGPoint(x: w * 0.42, y: h * 0.10), controlPoint2: CGPoint(x: w * 0.56, y: h * 0.22))
        path.addCurve(to: CGPoint(x: w, y: h * 0.04), controlPoint1: CGPoint(x: w * 0.80, y: h * 0.00), controlPoint2: CGPoint(x: w * 0.92, y: h * -0.04))
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
        topStart.fromValue = CGPoint(x: 0.0, y: 1.0)
        topStart.toValue = CGPoint(x: 0.1, y: 0.8)
        topStart.duration = 6.0
        topStart.autoreverses = true
        topStart.repeatCount = .infinity
        topStart.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let topEnd = CABasicAnimation(keyPath: "endPoint")
        topEnd.fromValue = CGPoint(x: 1.0, y: 0.0)
        topEnd.toValue = CGPoint(x: 0.9, y: 0.2)
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
        colorCycle.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        
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
            // Bezier ribbon along the very top for distinct orientation
            path.move(to: CGPoint(x: 0, y: h * 0.08))
            path.addCurve(to: CGPoint(x: w * 0.28, y: h * 0.02), controlPoint1: CGPoint(x: w * 0.10, y: h * 0.20), controlPoint2: CGPoint(x: w * 0.18, y: h * -0.06))
            path.addCurve(to: CGPoint(x: w * 0.68, y: h * 0.10), controlPoint1: CGPoint(x: w * 0.42, y: h * 0.10), controlPoint2: CGPoint(x: w * 0.56, y: h * 0.22))
            path.addCurve(to: CGPoint(x: w, y: h * 0.04), controlPoint1: CGPoint(x: w * 0.80, y: h * 0.00), controlPoint2: CGPoint(x: w * 0.92, y: h * -0.04))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.close()
            maskLayer.path = path.cgPath
        }
    }

    func createSession() {
        let sessionName = "Attendance Session"
        
        // Debug: Check if user is logged in
        if let userID = FirebaseManager.shared.getCurrentUserID() {
            print("Current user ID: \(userID)")
        } else {
            print("No user logged in!")
            showAlert(message: "Please log in first")
            return
        }
        
        FirebaseManager.shared.createSession(sessionName: sessionName) { result in
            switch result {
            case .success(let sessionId):
                self.sessionId = sessionId

                print("Session created!")
                print("   sessionId: \(sessionId)")
                
                // Create QR code payload with JSON
                if let jsonString = self.makeQRPayloadJSON(sessionId: sessionId, sessionName: sessionName),
                   let qrImage = self.generateQRCode(from: jsonString) {
                    print("QR payload: \(jsonString)")
                    self.qrCodeImageView.image = qrImage
                } else {
                    print("Failed to build QR JSON payload, falling back to raw sessionId")
                    self.qrCodeImageView.image = self.generateQRCode(from: sessionId)
                }
                
                // Start listening for participants
                self.startListening()
                
            case .failure(let error):
                print("Failed to create session: \(error)")
                self.showAlert(message: "Failed to create session: \(error.localizedDescription)")
            }
        }
    }
    
    private func makeQRPayloadJSON(sessionId: String, sessionName: String?) -> String? {
        let payload: [String: Any] = [
            "type": "attendance_session",
            "version": 1,
            "sessionId": sessionId,
            "sessionName": sessionName ?? ""
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    func startListening() {
        listener = FirebaseManager.shared.listenToSession(sessionId: sessionId) { participants in
            print("Participants updated: \(participants.count) total")
            let previousParticipants = self.participants
            
            // Debug: Print each participant
            for participant in participants {
                print("   - \(participant.participantDisplayName) (\(participant.participantEmail))")
            }
            
            self.participants = participants
            self.updateParticipantCount()
            self.attendeeTableView.reloadData()
        }
    }
    
    func updateParticipantCount() {
        attendeeCountLabel.text = "Attendees: \(participants.count)"
        previousParticipantCount = participants.count
    }
    
    func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                let context = CIContext()
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Table View

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return participants.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AttendeeCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "AttendeeCell")
        
        let participant = participants[indexPath.row]
        
        cell.textLabel?.text = participant.participantDisplayName
        cell.detailTextLabel?.text = participant.participantEmail
        
        // Load profile photo (placeholder until model provides a URL)
        cell.imageView?.image = UIImage(systemName: "person.circle.fill")
        cell.imageView?.contentMode = .scaleAspectFill
        cell.imageView?.clipsToBounds = true
        // Make circular appearance if imageView has a frame
        if let imageView = cell.imageView {
            let side: CGFloat = 40
            imageView.frame = CGRect(x: 0, y: 0, width: side, height: side)
            imageView.layer.cornerRadius = side / 2
        }
        
        return cell
    }

    // Swipe to kick/ban
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let participant = participants[indexPath.row]
        
        // Kick action
        let kickAction = UIContextualAction(style: .destructive, title: "Kick") { _, _, completion in
            self.kickParticipant(participant: participant)
            completion(true)
        }
        kickAction.backgroundColor = UIColor.systemOrange
        
        // Ban action
        let banAction = UIContextualAction(style: .destructive, title: "Ban") { _, _, completion in
            self.banParticipant(participant: participant)
            completion(true)
        }
        banAction.backgroundColor = UIColor.systemRed
        
        return UISwipeActionsConfiguration(actions: [banAction, kickAction])
    }

    // MARK: - Kick and Ban Actions

    func kickParticipant(participant: ParticipantInfo) {
        let alert = UIAlertController(
            title: "Kick Participant?",
            message: "Remove \(participant.participantDisplayName) from this session?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Kick", style: .destructive) { _ in
            FirebaseManager.shared.kickParticipant(sessionId: self.sessionId, participantId: participant.participantId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Participant kicked")
                    case .failure(let error):
                        self.showAlert(message: "Failed to kick: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }

    func banParticipant(participant: ParticipantInfo) {
        let alert = UIAlertController(
            title: "Ban Participant?",
            message: "Ban \(participant.participantDisplayName) from this session? They won't be able to rejoin.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Ban", style: .destructive) { _ in
            FirebaseManager.shared.banParticipant(
                sessionId: self.sessionId,
                participantId: participant.participantId,
                participantEmail: participant.participantEmail
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Participant banned")
                    case .failure(let error):
                        self.showAlert(message: "Failed to ban: \(error.localizedDescription)")
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @IBAction func endSessionTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "End Session?",
            message: "Are you sure? \(participants.count) students checked in.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "End Session", style: .destructive) { _ in
            self.endSession()
        })
        present(alert, animated: true)
    }
    
    func endSession() {
        FirebaseManager.shared.endSession(sessionId: sessionId) { result in
            switch result {
            case .success:
                print("Session ended")
                self.listener?.remove()
                self.navigationController?.popViewController(animated: true)
                
            case .failure(let error):
                print("Failed to end session: \(error)")
                self.showAlert(message: "Failed to end session")
            }
        }
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
    }
}

