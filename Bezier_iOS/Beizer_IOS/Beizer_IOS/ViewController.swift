//
//  ViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit

class ViewController: UIViewController {
    
    
    
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


    
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        // Get the username and password
               let email = emailTextField.text ?? ""
               let password = passwordTextField.text ?? ""
               
               // Basic validation
               if email.isEmpty || password.isEmpty {
                   print("Please enter both email and password")
                   return
               }
               
               // For now, just navigate to home screen
               // Later you'll add real authentication here
               performSegue(withIdentifier: "goToHome", sender: self)
    }
    

}

