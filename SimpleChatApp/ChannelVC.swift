//
//  ChannelVC.swift
//  SimpleChatApp
//
//  Created by Sukhrat on 06.07.17.
//  Copyright © 2017 Sukhrat. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import Photos

final class ChannelVC: JSQMessagesViewController {
    
    //MARK: Properties
    var channelRef: FIRDatabaseReference?
    var channel: Channel? {
        didSet {
            title = channel?.name
        }
    }
    var messages = [JSQMessage]()
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var ingoingBubbleImageView: JSQMessagesBubbleImage = self.setupIngoingBubble()
    
    private lazy var messageRef: FIRDatabaseReference = self.channelRef!.child("messages")
    private var newMessageRefHandle: FIRDatabaseHandle?
    
    private lazy var userIsTypingRef: FIRDatabaseReference = self.channelRef!.child("typingIndicator").child(self.senderId)
    
    private lazy var usersTypeQuery:FIRDatabaseQuery = self.channelRef!.child("typingIndicator").queryOrderedByValue().queryEqual(toValue: true)
    
    private var _isTyping = false
    private var photoMessageMap = [String: JSQPhotoMediaItem]()
    
    var isTyping: Bool {
        
        get {
            return _isTyping
        }
        set {
            _isTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    lazy var storageRef = FIRStorage.storage().reference(forURL: "gs://simplechatapp-e845d.appspot.com")
    
    private let imageURLNotSetKey = "NOTSET"
    private var updatedMessageRefHandle: FIRDatabaseHandle?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.senderId = FIRAuth.auth()?.currentUser?.uid
        
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        observeMessages()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
//        addMessage(withId: "foo", name: "Bolt", text: "I am very fast")
//        
//        addMessage(withId: senderId, name: senderDisplayName, text: "I bet I am faster")
//        addMessage(withId: senderId, name: senderDisplayName, text: "I can run very fast")
        
//        finishReceivingMessage()
        observeTyping()
    }
    
    //MARK: Collection view
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    //MARK: Message bubble colors
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
        
    }
    
    private func setupIngoingBubble() -> JSQMessagesBubbleImage {
        
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    //MARK: Setting the Bubble images
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return ingoingBubbleImageView
        }
    }
    
    //MARK: Removing the avatars
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    //MARK: Creating messages
    private func addMessage(withId id: String, name: String, text: String) {
        
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            
            messages.append(message)
            
        }
    }
    
    //MARK: Message Bubble text
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell  = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.white
        } else {
            cell.textView?.textColor = UIColor.black
        }
        
        return cell
    }
    
    //MARK: Sending messages
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        let itemRef = messageRef.childByAutoId()
        let messageItem = [
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text!
        ]
        
        itemRef.setValue(messageItem)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
        isTyping = false
    }
    
    //MARK: Synchronizing the Data Source
    private func observeMessages() {
        
        messageRef = channelRef!.child("messages")
        
        let messageQuery = messageRef.queryLimited(toLast: 25)
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) in
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!,let text = messageData["text"], text.characters.count > 0 {
               self.addMessage(withId: id, name: name, text: text)
                
                self.finishReceivingMessage()
            } else if let id = messageData["senderId"] as String!, let photoURL = messageData["photoURL"] as String! {
                if let mediaItem = JSQPhotoMediaItem(maskAsOutgoing: id == self.senderId) {
                    self.addPhotoMessage(withId: id, key: snapshot.key, mediaItem: mediaItem)
                    
                    if photoURL.hasPrefix("gs://") {
                        self.fetchImageAtUrl(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: nil)                    }
                }
                
            }
            else {
                
                print("Could not decode any message data")
            }
        })
        
        updatedMessageRefHandle = messageRef.observe(.childChanged, with: { (snapshot) in
            let key = snapshot.key
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let photoUrl = messageData["photoURL"] as String! {
                if let mediaItem = self.photoMessageMap[key] { // 3
                    self.fetchImageAtUrl(photoUrl, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: key)
                }
            }
        })
    }
    
    //MARK: Observe if the user is typing
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        isTyping = textView.text != ""
    }
    
    private func observeTyping() {
        
        let typingIndicatorRef = channelRef!.child("typingIndicator")
        userIsTypingRef = typingIndicatorRef.child(senderId)
        userIsTypingRef.onDisconnectRemoveValue()
        
        usersTypeQuery.observe(.value) { (data: FIRDataSnapshot) in
            if data.childrenCount == 1 && self.isTyping {
                return
            }
            
            self.showTypingIndicator = data.childrenCount > 0
            self.scrollToBottom(animated: true)
        }
    }
    
    //MARK: Handling images
    func sendPhotoMessage() -> String? {
        
        let itemRef = messageRef.childByAutoId()
        
        let messageItem = [
            "photoURL": imageURLNotSetKey,
            "senderId": senderId!
        ]
        
        itemRef.setValue(messageItem)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
        return itemRef.key
    }
    
    func setImageURL(_ url: String, forPhotoMessageWithKey key: String) {
        let itemRef = messageRef.child(key)
        itemRef.updateChildValues(["photoURL": url])
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        let picker = UIImagePickerController()
        picker.delegate = self as! UIImagePickerControllerDelegate & UINavigationControllerDelegate
        
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            
            picker.sourceType = UIImagePickerControllerSourceType.camera
        } else {
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        }
        
        present(picker, animated: true, completion: nil)
    }
    
    private func addPhotoMessage(withId id: String, key: String, mediaItem: JSQPhotoMediaItem) {
        
        if let message = JSQMessage(senderId: id, displayName: "", media: mediaItem) {
            
            messages.append(message)
            
            if (mediaItem.image == nil) {
                photoMessageMap[key] = mediaItem
            }
            
            collectionView.reloadData()
        }
    }
    
    private func fetchImageAtUrl(_ photoUrl: String, forMediaItem mediaItem: JSQPhotoMediaItem, clearsPhotoMessageMapOnSuccessForKey key: String?) {
        
        let storageRef = FIRStorage.storage().reference(forURL: photoUrl)
        storageRef.data(withMaxSize: INT64_MAX) { (data, error) in
            if let error = error {
                let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                alertController.addAction(defaultAction)
                
                self.present(alertController, animated: true, completion: nil)
                return
            }
            
            storageRef.metadata(completion: { (metadata, metaError) in
                if let error = metaError {
                    
                    let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    let defaultAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                    alertController.addAction(defaultAction)
                    
                    self.present(alertController, animated: true, completion: nil)
                    return
                    
                }
                
                if metadata?.contentType == "image/gif" {
                  //  mediaItem.image = UIImage.gif(data!)
                    print(" gif image")
                } else {
                    mediaItem.image = UIImage.init(data:data!)
                }
                self.collectionView.reloadData()
                
                guard key != nil else {
                    return
                }
                self.photoMessageMap.removeValue(forKey: key!)
            })
        }
        
    }
    deinit {
        if let refHandle = newMessageRefHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
        
        if let refHandle = updatedMessageRefHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
    }
}

extension ChannelVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        if let photoRefURL = info[UIImagePickerControllerReferenceURL] as? URL {
            
            let assets = PHAsset.fetchAssets(withALAssetURLs: [photoRefURL], options: nil)
            let asset = assets.firstObject
            
            if let key = sendPhotoMessage() {
                asset?.requestContentEditingInput(with: nil, completionHandler: { (contentEditingInput, info) in
                    let imageFileURL = contentEditingInput?.fullSizeImageURL
                    let path = "\(FIRAuth.auth()?.currentUser?.uid)/\(Int(Date.timeIntervalSinceReferenceDate * 1000))/\(photoRefURL.lastPathComponent)"
                    
                    self.storageRef.child(path).putFile(imageFileURL!, metadata: nil, completion: { (metadata, error) in
                        if let error = error {
                            
                            let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                            let defaultAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                            alertController.addAction(defaultAction)
                            
                            self.present(alertController, animated: true, completion: nil)
                            return
                            
                        }
                        self.setImageURL(self.storageRef.child((metadata?.path)!).description, forPhotoMessageWithKey: key)
                        
                    })
                })
            } else {
                //TODO: handle picking a photo from the camera
                let image = info[UIImagePickerControllerOriginalImage] as! UIImage
                
                if let key = sendPhotoMessage() {
                    let imageData = UIImageJPEGRepresentation(image, 1.0)
                    let imagePath = FIRAuth.auth()!.currentUser!.uid + "/\(Int(Date.timeIntervalSinceReferenceDate * 1000)).jpg"
                    
                    let metadata = FIRStorageMetadata()
                    metadata.contentType = "image/jpeg"
                    
                    
                    let urlString = String(describing: imageData!)
                    storageRef.child(imagePath).putFile(URL(string: urlString)!, metadata: metadata, completion: { (metadata, error) in
                        if let error = error {
                            let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                            let defaultAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
                            alertController.addAction(defaultAction)
                        }
                        self.setImageURL(self.storageRef.child((metadata?.path)!).description, forPhotoMessageWithKey: key)
                    })
                }
            }
            
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
}
