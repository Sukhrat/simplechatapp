//
//  SignUpVC.swift
//  SimpleChatApp
//
//  Created by Sukhrat on 05.07.17.
//  Copyright © 2017 Sukhrat. All rights reserved.
//

import UIKit
import Firebase

class SignUpVC: UIViewController {

    @IBOutlet weak var nameField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    
    @IBAction func anonBtnPressed(_ sender: Any) {
        
        FIRAuth.auth()?.signInAnonymously(completion: { (user, error) in
            if let err = error {
                let alertController = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
            } else {
                
                self.performSegue(withIdentifier: "ShowList", sender: self.nameField.text == nil ? "" : self.nameField.text)
                
            }
        })
        
    }
    
    
    
    //MARK: Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        let navVC = segue.destination as! UINavigationController
        let channelVC = navVC.viewControllers.first as! ChannelListVC
        channelVC.senderDisplayName = nameField?.text
        
    }


}

