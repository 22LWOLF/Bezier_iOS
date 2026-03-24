//
//  FirebaseManager.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 3/17/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class FirebaseManager {
    
    static let shared = FirebaseManager()
    
    let auth = Auth.auth()
    let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Authentication
    
    func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let userID = result?.user.uid else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])))
                return
            }
            
            completion(.success(userID))
        }
    }
    
    func register(email: String, password: String, firstName: String, lastName: String, completion: @escaping (Result<String, Error>) -> Void) {
        auth.createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let userID = result?.user.uid else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])))
                return
            }
            
            // Create user document in Firestore
            let userData: [String: Any] = [
                "participantemail": email,
                "participantDisplayName": "\(firstName) \(lastName)",
                "createdAt": Int(Date().timeIntervalSince1970 * 1000),
                "participantId": userID
            ]
            
            self.db.collection("users").document(userID).setData(userData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(userID))
                }
            }
        }
    }
    
    func getCurrentUserID() -> String? {
        return auth.currentUser?.uid
    }
    
    func getCurrentUserEmail() -> String? {
        return auth.currentUser?.email
    }
    
    // MARK: - Get User Info
    
    func getUserInfo(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let userID = getCurrentUserID() else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        db.collection("users").document(userID).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(.failure(NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "User data not found"])))
                return
            }
            
            completion(.success(data))
        }
    }
    
    // MARK: - Session Management
    
    func createSession(sessionName: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let hostUserID = getCurrentUserID() else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        // Generate unique session ID (this goes in the QR code)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // milliseconds
        let random = Int.random(in: 10000...99999)
        let sessionID = "SESSION-\(timestamp)-\(random)"
        
        // Create session document with sessionID as the document ID
        let sessionData: [String: Any] = [
            "active": true,
            "attendeeCount": 0,
            "sessionId": sessionID,  // Store it in the data too for easy access
            "sessionName": sessionName,
            "timestamp": timestamp,
            "createdBy": hostUserID
        ]
        
        // Use sessionID as the document ID
        db.collection("attendance_sessions").document(sessionID).setData(sessionData) { error in
            if let error = error {
                print("❌ Failed to create session: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Session created with sessionId: \(sessionID)")
                completion(.success(sessionID))
            }
        }
    }
    
    func joinSession(sessionID: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userID = getCurrentUserID() else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        print("🔍 Attempting to join session: \(sessionID)")
        
        // First, get user info
        getUserInfo { userResult in
            switch userResult {
            case .success(let userData):
                // Get the session document directly using sessionID
                self.db.collection("attendance_sessions").document(sessionID).getDocument { snapshot, error in
                    
                    if let error = error {
                        print("❌ Error getting session: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let sessionData = snapshot?.data(),
                          let isActive = sessionData["active"] as? Bool,
                          isActive else {
                        print("❌ Session not found or inactive")
                        completion(.failure(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session not found or inactive"])))
                        return
                    }
                    
                    print("✅ Session found and active")
                    
                    // Check if user already attended
                    self.db.collection("attendance_sessions").document(sessionID)
                        .collection("participants").document(userID).getDocument { participantDoc, error in
                            
                            if participantDoc?.exists == true {
                                print("⚠️ User already checked in")
                                completion(.failure(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already checked in to this session"])))
                                return
                            }
                            
                            // Add user to participants subcollection
                            let participantData: [String: Any] = [
                                "participantId": userID,
                                "participantEmail": userData["participantEmail"] as? String ?? "Unknown",
                                // change to be dictonary
                                "participantDisplayName": userData["participantDisplayName"] as? String ?? "Unknown",
                                "checkedInAt": Int(Date().timeIntervalSince1970 * 1000),
                                "sessionId": sessionID
                            ]
                            
                            print("📝 Adding participant to session")
                            
                            self.db.collection("attendance_sessions").document(sessionID)
                                .collection("participants").document(userID).setData(participantData) { error in
                                    
                                    if let error = error {
                                        print("❌ Failed to add participant: \(error.localizedDescription)")
                                        completion(.failure(error))
                                        return
                                    }
                                    
                                    // Increment attendee count
                                    self.db.collection("attendance_sessions").document(sessionID)
                                        .updateData([
                                            "attendeeCount": FieldValue.increment(Int64(1))
                                        ]) { error in
                                            if let error = error {
                                                print("⚠️ Failed to increment count: \(error)")
                                            }
                                            
                                            print("✅ Successfully joined session!")
                                            completion(.success(sessionID))
                                        }
                                }
                        }
                }
                
            case .failure(let error):
                print("❌ Failed to get user info: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func listenToSession(sessionId: String, onUpdate: @escaping ([ParticipantInfo]) -> Void) -> ListenerRegistration {
        
        print("👂 Starting to listen to session: \(sessionId)")
        
        return db.collection("attendance_sessions").document(sessionId)
            .collection("participants")
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    print("❌ Listener error: \(error.localizedDescription)")
                    onUpdate([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 No participants yet")
                    onUpdate([])
                    return
                }
                
                print("📢 Participants updated: \(documents.count) total")
                
                let participants = documents.compactMap { doc -> ParticipantInfo? in
                    let data = doc.data()
                    return ParticipantInfo(
                        userId: data["userId"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        displayName: data["displayName"] as? String ?? "Unknown",
                        firstName: data["firstName"] as? String ?? "",
                        lastName: data["lastName"] as? String ?? "",
                        checkedInAt: data["checkedInAt"] as? Int ?? 0
                    )
                }
                
                onUpdate(participants)
            }
    }
    
    func endSession(sessionId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("🛑 Ending session: \(sessionId)")
        
        db.collection("attendance_sessions").document(sessionId).updateData([
            "active": false,
            "endedAt": Int(Date().timeIntervalSince1970 * 1000)
        ]) { error in
            if let error = error {
                print("❌ Failed to end session: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Session ended successfully")
                completion(.success(true))
            }
        }
    }
}

// MARK: - Data Models

struct ParticipantInfo {
    let userId: String
    let email: String
    let displayName: String
    let firstName: String
    let lastName: String
    let checkedInAt: Int
}
