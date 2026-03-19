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
                "email": email,
                "firstName": firstName,
                "lastName": lastName,
                "displayName": "\(firstName) \(lastName)",
                "createdAt": Int(Date().timeIntervalSince1970 * 1000)
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
    
    func createSession(sessionName: String, completion: @escaping (Result<(sessionId: String, hostId: String), Error>) -> Void) {
        guard let hostUserID = getCurrentUserID() else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        // Generate unique host ID (this is what goes in the QR code)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // milliseconds
        let random = Int.random(in: 10000...99999)
        let hostId = "SESSION-\(timestamp)-\(random)"
        
        // Create session document
        let sessionData: [String: Any] = [
            "active": true,
            "attendeeCount": 0,
            "hostId": hostId,  // This is the QR code content
            "sessionName": sessionName,
            "timestamp": timestamp,
            "createdBy": hostUserID  // Track who created it
        ]
        
        // Add to Firestore - let Firestore auto-generate the sessionId
        let sessionRef = db.collection("attendance_sessions").document()
        
        sessionRef.setData(sessionData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                let sessionId = sessionRef.documentID
                print("✅ Session created with sessionId: \(sessionId), hostId: \(hostId)")
                completion(.success((sessionId: sessionId, hostId: hostId)))
            }
        }
    }
    
    func joinSession(hostId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userID = getCurrentUserID() else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        // First, get user info
        getUserInfo { userResult in
            switch userResult {
            case .success(let userData):
                // Find session by hostId
                self.db.collection("attendance_sessions")
                    .whereField("hostId", isEqualTo: hostId)
                    .whereField("active", isEqualTo: true)
                    .getDocuments { snapshot, error in
                        
                        if let error = error {
                            completion(.failure(error))
                            return
                        }
                        
                        guard let documents = snapshot?.documents, !documents.isEmpty else {
                            completion(.failure(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session not found or inactive"])))
                            return
                        }
                        
                        // Get the first matching session
                        let sessionDoc = documents[0]
                        let sessionId = sessionDoc.documentID
                        
                        // Check if user already attended
                        self.db.collection("attendance_sessions").document(sessionId)
                            .collection("attendees").document(userID).getDocument { attendeeDoc, error in
                                
                                if attendeeDoc?.exists == true {
                                    completion(.failure(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already checked in to this session"])))
                                    return
                                }
                                
                                // Add user to attendees subcollection
                                let attendeeData: [String: Any] = [
                                    "userId": userID,
                                    "email": userData["email"] as? String ?? "Unknown",
                                    "displayName": userData["displayName"] as? String ?? "Unknown",
                                    "firstName": userData["firstName"] as? String ?? "",
                                    "lastName": userData["lastName"] as? String ?? "",
                                    "checkedInAt": Int(Date().timeIntervalSince1970 * 1000)
                                ]
                                
                                self.db.collection("attendance_sessions").document(sessionId)
                                    .collection("attendees").document(userID).setData(attendeeData) { error in
                                        
                                        if let error = error {
                                            completion(.failure(error))
                                            return
                                        }
                                        
                                        // Increment attendee count
                                        self.db.collection("attendance_sessions").document(sessionId)
                                            .updateData([
                                                "attendeeCount": FieldValue.increment(Int64(1))
                                            ]) { error in
                                                if let error = error {
                                                    print("⚠️ Failed to increment count: \(error)")
                                                }
                                                
                                                completion(.success(sessionId))
                                            }
                                    }
                            }
                    }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func listenToSession(sessionId: String, onUpdate: @escaping ([AttendeeInfo]) -> Void) -> ListenerRegistration {
        
        return db.collection("attendance_sessions").document(sessionId)
            .collection("attendees")
            .addSnapshotListener { snapshot, error in
                
                guard let documents = snapshot?.documents else {
                    onUpdate([])
                    return
                }
                
                let attendees = documents.compactMap { doc -> AttendeeInfo? in
                    let data = doc.data()
                    return AttendeeInfo(
                        userId: data["userId"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        displayName: data["displayName"] as? String ?? "Unknown",
                        firstName: data["firstName"] as? String ?? "",
                        lastName: data["lastName"] as? String ?? "",
                        checkedInAt: data["checkedInAt"] as? Int ?? 0
                    )
                }
                
                onUpdate(attendees)
            }
    }
    
    func endSession(sessionId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        db.collection("attendance_sessions").document(sessionId).updateData([
            "active": false,
            "endedAt": Int(Date().timeIntervalSince1970 * 1000)
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }
}

// MARK: - Data Models

struct AttendeeInfo {
    let userId: String
    let email: String
    let displayName: String
    let firstName: String
    let lastName: String
    let checkedInAt: Int
}
