//
//  HomeViewController.swift
//  Beizer_IOS
//
//  Created by Wolf,Luke D on 2/19/26.
//

import UIKit

class HomeViewController: UIViewController {
    private var hasAnimatedEntrance = false
    private var primaryButtons: [UIButton] {
        view.subviews.compactMap { $0 as? UIButton }.sorted { $0.frame.minY < $1.frame.minY }
    }
    
    
    
    @IBAction func joinSessionTapped(_ sender: UIButton) {
        sender.animatePlayfulTap { [weak self] in
            self?.performSegue(withIdentifier: "goToScanner", sender: self)
        }
    }
    
    
    @IBAction func hostSessionTapped(_ sender: UIButton) {
        sender.animatePlayfulTap { [weak self] in
            self?.performSegue(withIdentifier: "goToHost", sender: self)
        }
    }
    
    
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedEntrance else { return }
        hasAnimatedEntrance = true

        for (index, button) in primaryButtons.enumerated() {
            button.animateEntrance(delay: TimeInterval(index) * 0.12, from: 0, translationY: 24)
        }
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
