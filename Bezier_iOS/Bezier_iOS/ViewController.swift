//
//  ViewController.swift
//  Bezier_iOS
//
//  Created by Wolf,Luke D on 2/3/26.
//

import UIKit
import SwiftUI

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func loginTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
        
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate {
            sceneDelegate.changeRootViewController(homeVC, animated: true)
            
            NavigationStack {
                NavigationLink("Go to Second View", destination: homeVC)
            }

        }
        
        
        
        
    }
}
