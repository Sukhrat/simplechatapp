//
//  ChannelListVC.swift
//  SimpleChatApp
//
//  Created by Sukhrat on 06.07.17.
//  Copyright © 2017 Sukhrat. All rights reserved.
//

import UIKit
import Firebase

enum Section: Int {
    
    case createNewChannelSection = 0
    case currentChannelSection
    
}

class ChannelListVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    //MARK: Properties
    var senderDisplayName: String?
    var newChannelTextiField: UITextField?
    private lazy var channelRef: FIRDatabaseReference = FIRDatabase.database().reference().child("channels")
    private var channelRefHandle: FIRDatabaseHandle?
    
    private var channels: [Channel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        //senderDisplayName = ""
        
        tableView.delegate = self
        tableView.dataSource = self
        
        title = "RW RIC"
        observeChannels()
    }
    
    deinit {
        if let refHandle = channelRefHandle {
            channelRef.removeObserver(withHandle: refHandle)
        }
    }
    
    //MARK: UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let currentSection: Section = Section(rawValue: section) {
            
            switch currentSection {
            case .createNewChannelSection:
                return 1
            case .currentChannelSection:
                return channels.count
            }
            
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue ? "NewChannel": "ExistingChannel"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        if (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue {
            if let createNewChannelCell = cell as? CreateChannelCell {
                newChannelTextiField = createNewChannelCell.channelNameField
            }
        } else if (indexPath as NSIndexPath).section == Section.currentChannelSection.rawValue {
            cell.textLabel?.text = channels[(indexPath as NSIndexPath).row].name
        }
        
        return cell
    }
    
    // MARK: UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == Section.currentChannelSection.rawValue {
            
            let channel = channels[(indexPath as NSIndexPath).row]
            self.performSegue(withIdentifier: "ShowChannel", sender: channel)
        }
    }
    
    // MARK: Firebase related methods
    private func observeChannels() {
        
        channelRefHandle = channelRef.observe(.childAdded, with: { (snapshot) in
            let channelData = snapshot.value as! Dictionary<String, AnyObject>
            let id = snapshot.key
            if let name = channelData["name"] as! String!, name.characters.count > 0 {
                
                self.channels.append(Channel(name: name, id: id))
                self.tableView.reloadData()
                
            } else {
                print("Error! Could not decode channel data")
            }
        })
        
    }
    
    // MARK: Actions
    @IBAction func addChannelBtnPressed(_ sender: Any) {
        
        if let name = newChannelTextiField?.text {
            let newChannelRef = channelRef.childByAutoId()
            let channelItem = ["name": name]
            newChannelRef.setValue(channelItem)
        }
        
    }
    
    //MARK: Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let channel = sender as? Channel {
            let chatVC = segue.destination as! ChannelVC
            
            chatVC.senderDisplayName = senderDisplayName
            chatVC.channel = channel
            chatVC.channelRef = channelRef.child(channel.id)
        }
    }

}
