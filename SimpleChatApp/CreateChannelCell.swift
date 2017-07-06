//
//  CreateChannelCell.swift
//  SimpleChatApp
//
//  Created by Sukhrat on 06.07.17.
//  Copyright © 2017 Sukhrat. All rights reserved.
//

import UIKit

class CreateChannelCell: UITableViewCell {

    @IBOutlet weak var channelNameField: UITextField!
    
    @IBOutlet weak var createChannelBtn: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
