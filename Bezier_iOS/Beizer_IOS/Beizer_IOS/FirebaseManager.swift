//
//  FirebaseManager.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 3/17/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

class FirebaseManager {
    
    static let shared = FirebaseManager()
    
    let auth = Auth.auth()
    let db = Firestore.firestore()
    
    private init() {}

    /// Firestore `users` documents are keyed by normalized email (not Auth UID).
    private func normalizedEmailForUserDocument(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func currentUserFirestoreDocumentId() -> String? {
        guard let email = auth.currentUser?.email else { return nil }
        return normalizedEmailForUserDocument(email)
    }

    /// Firestore field for profile image URL (`profilePictureURL` is still read for older documents).
    private static let userPhotoURLKey = "photoURL"

    /// Legacy accounts store `users/{uid}`; newer accounts use `users/{normalizedEmail}`.
    private func photoURLString(from snapshot: DocumentSnapshot?) -> String? {
        guard let data = snapshot?.data() else { return nil }
        if let url = data[Self.userPhotoURLKey] as? String {
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private func normalizePhotoURLField(in merged: inout [String: Any]) {
        let photo = (merged[Self.userPhotoURLKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if photo.isEmpty { merged.removeValue(forKey: Self.userPhotoURLKey) }
    }

    /// Older user docs may still use `participantemail` / `participantDisplayName` / `firstName`+`lastName`.
    private func resolvedEmailFromUserData(_ userData: [String: Any]) -> String? {
        if let e = userData["email"] as? String, !e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return e
        }
        if let e = userData["participantemail"] as? String, !e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return e
        }
        return nil
    }

    private func resolvedDisplayNameFromUserData(_ userData: [String: Any]) -> String? {
        if let s = userData["displayName"] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        if let s = userData["participantDisplayName"] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        let first = userData["firstName"] as? String ?? ""
        let last = userData["lastName"] as? String ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }

    /// Loads current-user Firestore data, merging email-keyed and UID-keyed docs so legacy profiles still resolve.
    private func fetchMergedCurrentUserFirestoreData(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let uid = getCurrentUserID() else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }

        let emailRef = currentUserFirestoreDocumentId().map { db.collection("users").document($0) }
        let uidRef = db.collection("users").document(uid)

        func loadEmailThenUid(completion: @escaping ([String: Any]?, [String: Any]?) -> Void) {
            guard let emailRef = emailRef else {
                uidRef.getDocument { snap, _ in
                    let u = (snap?.exists == true) ? snap?.data() : nil
                    completion(nil, u)
                }
                return
            }
            emailRef.getDocument { emailSnap, _ in
                let emailData = (emailSnap?.exists == true) ? emailSnap?.data() : nil
                uidRef.getDocument { uidSnap, _ in
                    let uidData = (uidSnap?.exists == true) ? uidSnap?.data() : nil
                    completion(emailData, uidData)
                }
            }
        }

        loadEmailThenUid { emailData, uidData in
            guard emailData != nil || uidData != nil else {
                completion(.failure(NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "User data not found"])))
                return
            }
            var merged = emailData ?? [:]
            if merged.isEmpty, let u = uidData {
                merged = u
                self.normalizePhotoURLField(in: &merged)
                self.normalizeUidField(in: &merged)
                completion(.success(merged))
                return
            }
            if let u = uidData {
                for (key, value) in u {
                    if key == Self.userPhotoURLKey {
                        let mergedPhoto = (merged[Self.userPhotoURLKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if mergedPhoto.isEmpty {
                            merged[Self.userPhotoURLKey] = value
                        }
                    } else if merged[key] == nil {
                        merged[key] = value
                    }
                }
            }
            self.normalizePhotoURLField(in: &merged)
            self.normalizeUidField(in: &merged)
            completion(.success(merged))
        }
    }

    private func normalizeUidField(in merged: inout [String: Any]) {
        if merged["uid"] == nil, let legacy = merged["participantId"] as? String, !legacy.isEmpty {
            merged["uid"] = legacy
        }
    }

    /// Updates fields on `users/{normalizedEmail}` when present, otherwise legacy `users/{uid}`.
    private func updateFieldsOnCurrentUserDocument(_ fields: [String: Any], completion: @escaping (Error?) -> Void) {
        guard let uid = getCurrentUserID() else {
            completion(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        let uidRef = db.collection("users").document(uid)

        guard let emailId = currentUserFirestoreDocumentId() else {
            uidRef.updateData(fields, completion: completion)
            return
        }
        let emailRef = db.collection("users").document(emailId)
        emailRef.getDocument { snap, _ in
            if snap?.exists == true {
                emailRef.updateData(fields, completion: completion)
            } else {
                uidRef.getDocument { uidSnap, _ in
                    if uidSnap?.exists == true {
                        uidRef.updateData(fields, completion: completion)
                    } else {
                        emailRef.setData(fields, merge: true, completion: completion)
                    }
                }
            }
        }
    }

    private func touchLastLoginForCurrentUser(completion: ((Error?) -> Void)? = nil) {
        updateFieldsOnCurrentUserDocument(["lastLoginAt": Timestamp(date: Date())]) { error in
            if let error = error {
                print("lastLoginAt update failed: \(error.localizedDescription)")
            }
            completion?(error)
        }
    }

    private func updateProfilePictureURLForCurrentUser(_ downloadURL: String, completion: @escaping (Error?) -> Void) {
        updateFieldsOnCurrentUserDocument([Self.userPhotoURLKey: downloadURL], completion: completion)
    }

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

            self.touchLastLoginForCurrentUser { _ in
                completion(.success(userID))
            }
        }
    }
    
    // MARK: - Kick and Ban Management

    func kickParticipant(sessionId: String, participantId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("Kicking participant: \(participantId) from session: \(sessionId)")
        
        // Remove from participants subcollection
        db.collection("attendance_sessions").document(sessionId)
            .collection("participants").document(participantId).delete { error in
                
                if let error = error {
                    print("Failed to kick participant: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Decrement attendee count
                self.db.collection("attendance_sessions").document(sessionId)
                    .updateData([
                        "attendeeCount": FieldValue.increment(Int64(-1))
                    ]) { error in
                        if let error = error {
                            print("Failed to decrement count: \(error)")
                        }
                        
                        print("Participant kicked successfully")
                        completion(.success(true))
                    }
            }
    }

    func banParticipant(sessionId: String, participantId: String, participantEmail: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("Banning participant: \(participantId) from session: \(sessionId)")
        
        // Add to banned list
        let banData: [String: Any] = [
            "participantId": participantId,
            "participantEmail": participantEmail,
            "bannedAt": Int(Date().timeIntervalSince1970 * 1000),
            "sessionId": sessionId
        ]
        
        db.collection("attendance_sessions").document(sessionId)
            .collection("banned").document(participantId).setData(banData) { error in
                
                if let error = error {
                    print("Failed to ban participant: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Also kick them from the session
                self.kickParticipant(sessionId: sessionId, participantId: participantId) { result in
                    switch result {
                    case .success:
                        print("Participant banned and kicked")
                        completion(.success(true))
                    case .failure(let error):
                        print("Banned but failed to kick: \(error)")
                        completion(.success(true)) // Still consider it success since they're banned
                    }
                }
            }
    }

    func checkIfBanned(sessionId: String, participantId: String, completion: @escaping (Bool) -> Void) {
        db.collection("attendance_sessions").document(sessionId)
            .collection("banned").document(participantId).getDocument { snapshot, error in
                
                if let error = error {
                    print("Error checking ban status: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                let isBanned = snapshot?.exists ?? false
                if isBanned {
                    print("User is banned from this session")
                }
                completion(isBanned)
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
            
            let emailDocId = self.normalizedEmailForUserDocument(email)
            let now = Timestamp(date: Date())
            let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)

            // `users/{normalizedEmail}` — schema matches Firestore console: timestamps, displayName, email, photoURL, uid.
            let userData: [String: Any] = [
                "createdAt": now,
                "displayName": displayName,
                "email": email,
                "lastLoginAt": now,
                Self.userPhotoURLKey: "",
                "uid": userID
            ]

            self.db.collection("users").document(emailDocId).setData(userData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    print("User document created for \(emailDocId)")
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
    
    // MARK: - Profile Photo Management

    func uploadProfilePicture(image: UIImage, originalFileName: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userID = getCurrentUserID() else {
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(.failure(NSError(domain: "Image", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])))
            return
        }
        
        // Create storage path:
        // profile_pictures/{uid}/{timestamp}_{filename}
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let safeName = sanitizeFileName(originalFileName ?? "profile.jpg")
        let objectName = "\(timestamp)_\(safeName)"

        // Create storage reference
        let storageRef = Storage.storage().reference()
        let profilePictureRef = storageRef.child("profile_pictures/\(userID)/\(objectName)")
        
        // Upload
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        profilePictureRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Get download URL
            profilePictureRef.downloadURL { url, error in
                if let error = error {
                    print("Failed to get download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url?.absoluteString else {
                    completion(.failure(NSError(domain: "Storage", code: -1, userInfo: [NSLocalizedDescriptionKey: "No download URL"])))
                    return
                }
                
                self.updateProfilePictureURLForCurrentUser(downloadURL) { error in
                    if let error = error {
                        print("Failed to update user document: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("Profile photo uploaded and URL saved: \(downloadURL)")
                        completion(.success(downloadURL))
                    }
                }
            }
        }
    }

    /// Replace the existing profile picture by deleting the old storage object (if any) and uploading the new one.
    func replaceProfilePicture(image: UIImage, originalFileName: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        // First attempt to get existing URL
        getProfilePictureURL { result in
            switch result {
            case .success(let existingURL):
                self.deleteStorageObjectIfOwnedByApp(urlString: existingURL) { _ in
                    // Proceed to upload new regardless of delete result
                    self.uploadProfilePicture(image: image, originalFileName: originalFileName, completion: completion)
                }
            case .failure:
                // No existing URL; just upload new
                self.uploadProfilePicture(image: image, originalFileName: originalFileName, completion: completion)
            }
        }
    }

    private func deleteStorageObjectIfOwnedByApp(urlString: String, completion: @escaping (Error?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        // Expecting Firebase Storage download URL; extract path after "/o/" and decode
        let absolute = url.absoluteString
        guard let range = absolute.range(of: "/o/") else { completion(nil); return }
        let afterO = absolute[range.upperBound...]
        let pathEncoded = afterO.split(separator: "?").first.map(String.init) ?? ""
        let path = pathEncoded.removingPercentEncoding ?? pathEncoded
        let ref = Storage.storage().reference(withPath: path)
        ref.delete { error in
            if let error = error {
                print("Delete old profile photo failed: \(error.localizedDescription)")
            }
            completion(error)
        }
    }

    private func sanitizeFileName(_ fileName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let filtered = fileName.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let result = String(filtered)
        return result.isEmpty ? "profile.jpg" : result
    }

    func downloadProfilePicture(url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let imageURL = URL(string: url) else {
            completion(.failure(NSError(domain: "URL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "Image", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])))
                return
            }
            
            completion(.success(image))
        }.resume()
    }

    func getProfilePictureURL(for userID: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        func finish(from snapshot: DocumentSnapshot?) {
            if let url = photoURLString(from: snapshot) {
                completion(.success(url))
                return
            }
            completion(.failure(NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profile photo URL not found"])))
        }

        if let uid = userID {
            db.collection("users").whereField("uid", isEqualTo: uid).limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let doc = snapshot?.documents.first {
                    finish(from: doc)
                    return
                }
                self.db.collection("users").whereField("participantId", isEqualTo: uid).limit(to: 1).getDocuments { snapshot2, error2 in
                    if let error2 = error2 {
                        completion(.failure(error2))
                        return
                    }
                    if let doc = snapshot2?.documents.first {
                        finish(from: doc)
                        return
                    }
                    self.db.collection("users").document(uid).getDocument { snap, err in
                        if let err = err {
                            completion(.failure(err))
                            return
                        }
                        finish(from: snap)
                    }
                }
            }
            return
        }

        fetchMergedCurrentUserFirestoreData { result in
            switch result {
            case .success(let data):
                if let raw = data[Self.userPhotoURLKey] as? String {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        completion(.success(trimmed))
                        return
                    }
                }
                completion(.failure(NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profile photo URL not found"])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func downloadProfilePicture(for userID: String? = nil, completion: @escaping (Result<UIImage, Error>) -> Void) {
        getProfilePictureURL(for: userID) { result in
            switch result {
            case .success(let url):
                self.downloadProfilePicture(url: url, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Get User Info
    
    func getUserInfo(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        fetchMergedCurrentUserFirestoreData(completion: completion)
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
                print("Failed to create session: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Session created with sessionId: \(sessionID)")
                completion(.success(sessionID))
            }
        }
    }
    
    func joinSession(sessionID: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userID = getCurrentUserID() else {
            print("No user ID - user not logged in")
            completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        print("Attempting to join session: \(sessionID)")
        print("Current user ID: \(userID)")
        
        // First, get user info
        getUserInfo { userResult in
            switch userResult {
            case .success(let userData):
                print("Got user data from Firestore:")
                print("   Raw data: \(userData)")
                
                let email = self.resolvedEmailFromUserData(userData) ?? self.getCurrentUserEmail()
                let displayName = self.resolvedDisplayNameFromUserData(userData) ?? email ?? "Unknown"

                print("   email: \(email ?? "NIL")")
                print("   displayName: \(displayName)")
                
                // Get the session document directly using sessionID
                self.db.collection("attendance_sessions").document(sessionID).getDocument { snapshot, error in
                    if let error = error {
                        print("Error getting session: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let sessionData = snapshot?.data(),
                          let isActive = sessionData["active"] as? Bool,
                          isActive else {
                        print("Session not found or inactive")
                        completion(.failure(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session not found or inactive"])))
                        return
                    }
                    
                    print("Session found and active")
                    
                    self.checkIfBanned(sessionId: sessionID, participantId: userID) { isBanned in
                        if isBanned {
                            print("User is banned from this session")
                            completion(.failure(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "You have been banned from this session"])))
                            return
                        }
                        
                        // Check if user already attended
                        self.db.collection("attendance_sessions").document(sessionID)
                            .collection("participants").document(userID).getDocument { participantDoc, error in
                                if participantDoc?.exists == true {
                                    print("User already checked in")
                                    completion(.failure(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already checked in to this session"])))
                                    return
                                }
                                
                                let finalEmail = email ?? "Unknown"
                                let finalDisplayName = displayName
                                
                                // Add user to participants subcollection
                                let participantData: [String: Any] = [
                                    "participantId": userID,
                                    "participantEmail": finalEmail,
                                    "participantDisplayName": finalDisplayName,
                                    Self.userPhotoURLKey: (userData[Self.userPhotoURLKey] as? String) ?? "",
                                    "checkedInAt": Int(Date().timeIntervalSince1970 * 1000),
                                    "sessionId": sessionID
                                ]
                                
                                print("Participant data to be written:")
                                print("   \(participantData)")
                                
                                self.db.collection("attendance_sessions").document(sessionID)
                                    .collection("participants").document(userID).setData(participantData) { error in
                                        if let error = error {
                                            print("Failed to add participant: \(error.localizedDescription)")
                                            completion(.failure(error))
                                            return
                                        }
                                        
                                        print("Participant document written successfully!")
                                        
                                        // Increment attendee count
                                        self.db.collection("attendance_sessions").document(sessionID)
                                            .updateData([
                                                "attendeeCount": FieldValue.increment(Int64(1))
                                            ]) { error in
                                                if let error = error {
                                                    print("Failed to increment count: \(error)")
                                                } else {
                                                    print("Attendee count incremented")
                                                }
                                                
                                                print("Successfully joined session!")
                                                completion(.success(sessionID))
                                            }
                                    }
                            }
                    }
                }
                
            case .failure(let error):
                print("Failed to get user info: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
  
    func listenToSession(sessionId: String, onUpdate: @escaping ([ParticipantInfo]) -> Void) -> ListenerRegistration {
        
        print("Starting to listen to session: \(sessionId)")
        
        return db.collection("attendance_sessions").document(sessionId)
            .collection("participants")
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    print("Listener error: \(error.localizedDescription)")
                    onUpdate([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No participants yet")
                    onUpdate([])
                    return
                }
                
                print("Participants updated: \(documents.count) total")
                    
                let participants = documents.compactMap { doc -> ParticipantInfo? in
                    let data = doc.data()
                        
                        return ParticipantInfo(
                            participantId: data["participantId"] as? String ?? "",
                            participantEmail: data["participantEmail"] as? String ?? "Unknown",
                            participantDisplayName: data["participantDisplayName"] as? String ?? "Unknown",
                            checkedInAt: data["checkedInAt"] as? Int ?? 0,
                            sessionId: data["sessionId"] as? String ?? ""
                        )
                    }
                
                onUpdate(participants)
            }
    }
    
    func endSession(sessionId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("Ending session: \(sessionId)")
        
        db.collection("attendance_sessions").document(sessionId).updateData([
            "active": false,
            "endedAt": Int(Date().timeIntervalSince1970 * 1000)
        ]) { error in
            if let error = error {
                print("Failed to end session: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Session ended successfully")
                completion(.success(true))
            }
        }
    }
}

