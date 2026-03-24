import UIKit
import AVFoundation

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        
        // Set up the capture session
        captureSession = AVCaptureSession()
        
        // Get the camera device
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showAlert(message: "Camera not available")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            showAlert(message: "Error accessing camera")
            return
        }
        
        // Add input to session
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            showAlert(message: "Could not add video input")
            return
        }
        
        // Set up output
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showAlert(message: "Could not add metadata output")
            return
        }
        
        // Set up preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Start the session
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    // This function is called when a QR code is detected
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Vibrate the phone
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // Show what was scanned
            qrCodeDetected(code: stringValue)
        }
    }
    
    private func parseSessionId(from code: String) -> String? {
        if let data = code.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = obj as? [String: Any] {
            if let sessionId = dict["sessionId"] as? String, !sessionId.isEmpty {
                return sessionId
            }
        }
        return code
    }
    
    func qrCodeDetected(code: String) {
        print("QR Code detected: \(code)")
        guard let sessionId = parseSessionId(from: code) else {
            let alert = UIAlertController(
                title: "Invalid QR",
                message: "This QR code doesn't contain a valid session ID.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.startRunning()
                }
            })
            self.present(alert, animated: true)
            return
        }
        FirebaseManager.shared.joinSession(sessionID: sessionId) { result in
            switch result {
            case .success(let sessionId):
                print("✅ Joined session: \(sessionId)")
                let alert = UIAlertController(
                    title: "✅ Attendance Marked!",
                    message: "You've successfully checked in.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    self.navigationController?.popViewController(animated: true)
                })
                self.present(alert, animated: true)
            case .failure(let error):
                print("Check-in failed: \(error.localizedDescription)")
                let alert = UIAlertController(
                    title: "❌ Check-in Failed",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.captureSession.startRunning()
                    }
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    self.navigationController?.popViewController(animated: true)
                })
                self.present(alert, animated: true)
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}
