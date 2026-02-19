//
//  HostSessionViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit

class HostSessionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var attendeeCountLabel: UILabel!
    @IBOutlet weak var attendeeTableView: UITableView!
    
    // Store the session ID and attendee list
    var sessionID: String = ""
    var attendees: [String] = [] // Will hold username/emails
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up table view
        attendeeTableView.delegate = self
        attendeeTableView.dataSource = self
        
        // Generate unique session ID
        sessionID = generateUniqueSessionID()
        
        // Generate QR code with the session ID
        let qrImage = generateQRCode(from: sessionID)
        qrCodeImageView.image = qrImage
        
        // Update attendee count
        updateAttendeeCount()
        
        // For demo add some fake people
        addDemoAttendees()
        
    }
    
    // MARK: - QR Code Generation
    
    func generateUniqueSessionID() -> String {
        // Create a unique ID using timestamp and random number
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 10000...99999)
        let uniqueID = "SESSION-\(timestamp)-\(random)"
        
        print("Generated Session ID: \(uniqueID)")
        return uniqueID
    }
    
    func generateQRCode(from input: String) -> UIImage? {
        guard let data = input.data(using: .ascii) else { return nil }
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            
            // Create higher res QR code
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
    
    // MARK: - Attendee Management
    
    func updateAttendeeCount() {
        attendeeCountLabel.text = "Attendees: \(attendees.count)"
    }
    
    func addAttendee(username: String){
        // Check for duplicates
        if !attendees.contains(username) {
            attendees.append(username)
            updateAttendeeCount()
            attendeeTableView.reloadData()
        }
    }
    
    // MARK: - Testing data (REMOVE LATER)
    
    func addDemoAttendees() {
        // Sim people joining over time
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.addAttendee(username: "john.doe@gmail.com")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.addAttendee(username: "jane.smith@example.com")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.addAttendee(username: "dogboy@catmail.com")
        }
    }
    
    // MARK: - Table View Data Storage
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attendees.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Use a basic cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "AttendeeCell") ?? UITableViewCell(style: .default, reuseIdentifier: "AttendeeCell")
        
        cell.textLabel?.text = attendees[indexPath.row]
        
        return cell
    }
    
    // MARK: - Actions
    
    @IBAction func endSessionTapped(_ sender: UIButton) {
        // Show confirmation alert
        let alert = UIAlertController(title: "End Session?", message: "Are you sure you want to end this session? \(attendees.count) students have checked in.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: "End Session", style: .destructive) { _ in
            // Go back to home screen
            self.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
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
