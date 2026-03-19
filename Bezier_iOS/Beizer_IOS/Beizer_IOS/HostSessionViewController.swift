//
//  HostSessionViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit
import FirebaseFirestore


class HostSessionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var attendeeCountLabel: UILabel!
    @IBOutlet weak var attendeeTableView: UITableView!

        var sessionId: String = ""
        var hostId: String = ""  // This goes in the QR code
        var attendees: [AttendeeInfo] = []
        var listener: ListenerRegistration?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            attendeeTableView.delegate = self
            attendeeTableView.dataSource = self
            
            // Create session in Firebase
            createSession()
        }
        
        func createSession() {
            // You can customize the session name or ask the user
            let sessionName = "Attendance Session"
            
            FirebaseManager.shared.createSession(sessionName: sessionName) { result in
                switch result {
                case .success(let (sessionId)):
                    self.sessionId = sessionId

                    
                    print("✅ Session created!")
                    print("   sessionId (Firestore doc): \(sessionId)")
                    
                    // Generate QR code with hostId (this is what students scan)
                    let qrImage = self.generateQRCode(from: sessionId)
                    self.qrCodeImageView.image = qrImage
                    
                    // Start listening for attendees
                    self.startListening()
                    
                case .failure(let error):
                    print("❌ Failed to create session: \(error)")
                    self.showAlert(message: "Failed to create session: \(error.localizedDescription)")
                }
            }
        }
        
        func startListening() {
            listener = FirebaseManager.shared.listenToSession(sessionId: sessionId) { attendees in
                print("📢 Attendees updated: \(attendees.count) total")
                self.attendees = attendees
                self.updateAttendeeCount()
                self.attendeeTableView.reloadData()
            }
        }
        
        func updateAttendeeCount() {
            attendeeCountLabel.text = "Attendees: \(attendees.count)"
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
            return attendees.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AttendeeCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "AttendeeCell")
            
            let attendee = attendees[indexPath.row]
            cell.textLabel?.text = attendee.displayName
            cell.detailTextLabel?.text = attendee.email
            
            return cell
        }
        
        // MARK: - Actions
        
        @IBAction func endSessionTapped(_ sender: UIButton) {
            let alert = UIAlertController(
                title: "End Session?",
                message: "Are you sure? \(attendees.count) students checked in.",
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
                    print("✅ Session ended")
                    self.listener?.remove()
                    self.navigationController?.popViewController(animated: true)
                    
                case .failure(let error):
                    print("❌ Failed to end session: \(error)")
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
