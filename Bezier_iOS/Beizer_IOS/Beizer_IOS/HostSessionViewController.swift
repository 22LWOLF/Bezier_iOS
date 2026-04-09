//
//  HostSessionViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit
import FirebaseFirestore
import CoreImage

class HostSessionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var attendeeCountLabel: UILabel!
    @IBOutlet weak var attendeeTableView: UITableView!

    var sessionId: String = ""
    var participants: [ParticipantInfo] = []
    var listener: ListenerRegistration?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        attendeeTableView.delegate = self
        attendeeTableView.dataSource = self
        
        // Create session in Firebase
        createSession()
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
        
        // Load profile photo
        if !participant.profilePhotoURL.isEmpty {
            FirebaseManager.shared.downloadProfilePhoto(url: participant.profilePhotoURL) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let image):
                        // Make circular image
                        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
                        imageView.image = image
                        imageView.contentMode = .scaleAspectFill
                        imageView.layer.cornerRadius = 20
                        imageView.clipsToBounds = true
                        cell.imageView?.image = imageView.image
                        cell.imageView?.layer.cornerRadius = 20
                        cell.imageView?.clipsToBounds = true
                        cell.setNeedsLayout()
                        
                    case .failure:
                        cell.imageView?.image = UIImage(systemName: "person.circle.fill")
                    }
                }
            }
        } else {
            cell.imageView?.image = UIImage(systemName: "person.circle.fill")
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

