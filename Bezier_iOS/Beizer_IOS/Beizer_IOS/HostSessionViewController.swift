//
//  HostSessionViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit
import FirebaseFirestore
import CoreImage

class HostSessionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var attendeeCountLabel: UILabel!
    @IBOutlet weak var attendeeTableView: UITableView!

    var sessionId: String = ""
    var participants: [ParticipantInfo] = []
    var listener: ListenerRegistration?
    private var previousParticipantCount: Int = 0
    private var didAnimateEntrance = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        attendeeTableView.delegate = self
        attendeeTableView.dataSource = self
        attendeeCountLabel.text = "Attendees: 0"
        qrCodeImageView.alpha = 0
        qrCodeImageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        installGlobalRipple()
        VisualEffects.applyParallax(to: qrCodeImageView, amount: 14)
        
        // Create session in Firebase
        createSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didAnimateEntrance else { return }
        didAnimateEntrance = true
        VisualEffects.heroEntrance(attendeeCountLabel, delay: 0.03, translateY: 12)
        VisualEffects.heroEntrance(attendeeTableView, delay: 0.08, translateY: 20)
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
                    self.animateQRCodeReveal()
                } else {
                    print("Failed to build QR JSON payload, falling back to raw sessionId")
                    self.qrCodeImageView.image = self.generateQRCode(from: sessionId)
                    self.animateQRCodeReveal()
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
            self.animateParticipantListRefresh(from: previousParticipants, to: participants)
        }
    }
    
    func updateParticipantCount() {
        attendeeCountLabel.text = "Attendees: \(participants.count)"
        if participants.count != previousParticipantCount {
            attendeeCountLabel.animateSoftPulse()
            VisualEffects.glowPulse(on: attendeeCountLabel, color: .systemTeal)
            let burstPoint = CGPoint(x: attendeeCountLabel.frame.midX, y: attendeeCountLabel.frame.midY)
            let converted = attendeeCountLabel.superview?.convert(burstPoint, to: view) ?? CGPoint(x: view.bounds.midX, y: attendeeCountLabel.frame.maxY)
            VisualEffects.sparkleBurst(at: converted, in: view, colors: [.systemTeal, .systemYellow, .systemPurple])
            previousParticipantCount = participants.count
        }
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
        sender.animatePlayfulTap()
        let origin = sender.superview?.convert(sender.center, to: view) ?? view.center
        VisualEffects.ripple(at: origin, in: view, color: .systemRed)
        VisualEffects.glowPulse(on: sender, color: .systemRed)
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

    private func animateQRCodeReveal() {
        if VisualEffects.shouldReduceMotion {
            UIView.animate(withDuration: 0.2) {
                self.qrCodeImageView.alpha = 1
                self.qrCodeImageView.transform = .identity
            }
            return
        }

        UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: {
            self.qrCodeImageView.alpha = 1
            self.qrCodeImageView.transform = .identity
            self.qrCodeImageView.transform = self.qrCodeImageView.transform.rotated(by: 0.02)
        }) { _ in
            UIView.animate(withDuration: 0.14) {
                self.qrCodeImageView.transform = .identity
            }
        }
        VisualEffects.glowPulse(on: qrCodeImageView, color: .systemGreen)
    }

    private func animateParticipantListRefresh(from old: [ParticipantInfo], to new: [ParticipantInfo]) {
        let oldIds = Set(old.map { $0.participantId })
        let newIds = Set(new.map { $0.participantId })

        let inserted = newIds.subtracting(oldIds)
        let deleted = oldIds.subtracting(newIds)
        if VisualEffects.shouldReduceMotion {
            attendeeTableView.reloadData()
            return
        }

        let duration: TimeInterval = (inserted.isEmpty && deleted.isEmpty) ? 0.18 : 0.32
        UIView.transition(with: attendeeTableView, duration: duration, options: [.transitionCrossDissolve], animations: {
            self.attendeeTableView.reloadData()
        })
    }

    private func installGlobalRipple() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        VisualEffects.ripple(at: gesture.location(in: view), in: view, color: .systemCyan)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }
}

