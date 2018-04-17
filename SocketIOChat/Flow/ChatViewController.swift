//
//  ChatViewController.swift
//  SocketChat
//
//  Created by Laxman Reddy on 12/04/18.
//  Copyright © 2018 Laxman. All rights reserved.
//

import UIKit
import CoreData

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var tblChat: UITableView!
    
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var attachButton: UIButton!
    
    @IBOutlet weak var lblOtherUserActivityStatus: UILabel!
    
    @IBOutlet weak var tvMessageEditor: UITextView!
    
    @IBOutlet weak var conBottomEditor: NSLayoutConstraint!
    
    @IBOutlet weak var lblNewsBanner: UILabel!
    
    
    
    var nickname: String!
    
    var chatMessages = [[String: AnyObject]]()
    
    var bannerLabelTimer: Timer!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        setInputbar() // setup input view
        
        // observers
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleKeyboardDidShowNotification(notification:)), name:Notification.Name.UIKeyboardDidShow, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleKeyboardDidHideNotification(notification:)), name:Notification.Name.UIKeyboardDidHide, object: nil)

        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleConnectedUserUpdateNotification(notification:)), name:NSNotification.Name(rawValue: "userWasConnectedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleDisconnectedUserUpdateNotification(notification:)), name:NSNotification.Name(rawValue: "userWasDisconnectedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleUserTypingNotification(notification:)), name:NSNotification.Name(rawValue: "userTypingNotification"), object: nil)

        
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(self.dismissKeyboard))
        tapGesture.numberOfTapsRequired = 1
        tblChat.addGestureRecognizer(tapGesture)
    }

    func setInputbar()  {
        
        // send button
        sendButton.isEnabled = false
        
        // textview input setup
        tvMessageEditor.backgroundColor = UIColor.white
        tvMessageEditor.layer.cornerRadius = 10
        tvMessageEditor.layer.borderWidth = 0.5
        //tvMessageEditor.layer.borderColor = UIColor.red as! CGColor
        tvMessageEditor.layer.masksToBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configureTableView()
        configureNewsBannerLabel()
        configureOtherUserActivityLabel()
        
        tvMessageEditor.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SocketManagerIO.sharedInstance.getChatMessage { (messageInfo) in
            DispatchQueue.main.async {
        
                self.insertandFetchTheDataFromDB(dict: messageInfo as! Dictionary<String, String>)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    
    // MARK: IBAction Methods
    
    @IBAction func attachButtonTouchUpInside(_ sender: UIButton) {
        
        let sheet = UIAlertController(title: "Media messages", message: nil, preferredStyle: .actionSheet)
        
        let photoAction = UIAlertAction(title: "Send photo", style: .default) { (action) in
        }
        
        let locationAction = UIAlertAction(title: "Send location", style: .default) { (action) in
        }
        
        let videoAction = UIAlertAction(title: "Send video", style: .default) { (action) in
        }
        
        let audioAction = UIAlertAction(title: "Send audio", style: .default) { (action) in
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        sheet.addAction(photoAction)
        sheet.addAction(locationAction)
        sheet.addAction(videoAction)
        sheet.addAction(audioAction)
        sheet.addAction(cancelAction)
        
        self.present(sheet, animated: true, completion: nil)
    }
    @IBAction func sendButtonTouchUpInSide(_ sender: Any) {
        
        if tvMessageEditor.text.count > 0 {
            
            SocketManagerIO.sharedInstance.sendMessage(message: tvMessageEditor.text!, withNickname: nickname)
            tvMessageEditor.text = ""
            sendButton.isEnabled = false
            //tvMessageEditor.resignFirstResponder()
        }
    }

    // MARK: Coredata insert and Fetch
    
    
    // MARK: - Coredata Insert and Fetch
    
    func insertandFetchTheDataFromDB(dict:Dictionary<String,String>){
        // saving data into DB
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let chatEntity = NSEntityDescription.entity(forEntityName: "ChatMessage", in: context)
        
        let chatInfo = NSManagedObject(entity: chatEntity!, insertInto: context)
        
        chatInfo.setValue(dict["nickname"], forKey: "nickname")
        chatInfo.setValue(dict["date"], forKey: "date")
        chatInfo.setValue(dict["message"], forKey: "message")

        do {
            print(chatInfo)
            try context.save()  // save the data to DB
            
        } catch {
            
            print("Failed saving")
        }
        
        // Fetching data from DB
        let request = NSFetchRequest<NSDictionary>(entityName: "ChatMessage")
        request.resultType = .dictionaryResultType
        request.fetchLimit = 10
        
        let sort = NSSortDescriptor(key: "date", ascending: true)
        request.returnsObjectsAsFaults = false
        request.sortDescriptors = [sort]
        
        do {
            //let dataArray = try context.fetch(request)
            chatMessages = try context.fetch(request) as! [[String : AnyObject]]
            print(chatMessages)
            //chatMessages = Array((dataArray as NSArray).reverseObjectEnumerator()) as! [[String : AnyObject]]
        } catch {
            
            print("Failed")
        }
        
        if chatMessages.count > 1{
            
            DispatchQueue.main.async(execute: {() -> Void in
                
                self.tblChat.reloadData()
                self.scrollToBottom()

            })

        }
    }
    
    // MARK: Custom Methods
    
    func configureTableView() {
        tblChat.delegate = self
        tblChat.dataSource = self
        tblChat.register(UINib(nibName: "ChatCell", bundle: nil), forCellReuseIdentifier: "idCellChat")
        tblChat.estimatedRowHeight = 90.0
        tblChat.rowHeight = UITableViewAutomaticDimension
        tblChat.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    
    func configureNewsBannerLabel() {
        lblNewsBanner.layer.cornerRadius = 15.0
        lblNewsBanner.clipsToBounds = true
        lblNewsBanner.alpha = 0.0
    }
    
    
    func configureOtherUserActivityLabel() {
        lblOtherUserActivityStatus.isHidden = true
        lblOtherUserActivityStatus.text = ""
    }
    
    
    @objc func handleKeyboardDidShowNotification(notification: Notification) {
        if let userInfo = notification.userInfo {
            if let keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                conBottomEditor.constant = keyboardFrame.size.height
                //view.layoutIfNeeded()
            }
        }
    }
    
    
    @objc func handleKeyboardDidHideNotification(notification: Notification) {
        conBottomEditor.constant = 0
        //view.layoutIfNeeded()
    }
    
    
    func scrollToBottom() {
        let delay = 0.1 * Double(NSEC_PER_SEC)
        
        DispatchQueue.main.async {
            if self.chatMessages.count > 0 {
                let lastRowIndexPath = IndexPath(row: self.chatMessages.count-1, section: 0)
                self.tblChat.scrollToRow(at: lastRowIndexPath as IndexPath, at: UITableViewScrollPosition.bottom, animated: true)
            }

        }
        
//        dispatch_after(DispatchTime.now(dispatch_time_t(DISPATCH_TIME_NOW), Int64(delay)), dispatch_get_main_queue()) { () -> Void in
//            if self.chatMessages.count > 0 {
//                let lastRowIndexPath = NSIndexPath(forRow: self.chatMessages.count - 1, inSection: 0)
//                self.tblChat.scrollToRow(at: lastRowIndexPath as IndexPath, at: UITableViewScrollPosition.bottom, animated: true)
//            }
//        }
    }
    
    // MARK: Notification handlers
    
    func showBannerLabelAnimated() {
        UIView.animate(withDuration: 0.75, animations: { () -> Void in
            self.lblNewsBanner.alpha = 1.0
            
            }) { (finished) -> Void in
                self.bannerLabelTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(self.hideBannerLabel), userInfo: nil, repeats: false)
        }
    }
    
    
    @objc func hideBannerLabel() {
        if bannerLabelTimer != nil {
            bannerLabelTimer.invalidate()
            bannerLabelTimer = nil
        }
        
        UIView.animate(withDuration: 0.75, animations: { () -> Void in
            self.lblNewsBanner.alpha = 0.0
            
            }) { (finished) -> Void in
        }
    }

    
    
    @objc func dismissKeyboard() {
        //if tvMessageEditor.isFirstResponder {
            tvMessageEditor.resignFirstResponder()
            
            SocketManagerIO.sharedInstance.sendStopTypingMessage(nickname: nickname)
       // }
    }
    
    
    @objc func handleConnectedUserUpdateNotification(notification: Notification) {
        let connectedUserInfo = notification.object as! [String: AnyObject]
        let connectedUserNickname = connectedUserInfo["nickname"] as? String
        lblNewsBanner.text = "User \(connectedUserNickname!.uppercased()) was just connected."
        showBannerLabelAnimated()
    }
    
    
    @objc func handleDisconnectedUserUpdateNotification(notification: Notification) {
        let disconnectedUserNickname = notification.object as! String
        lblNewsBanner.text = "User \(disconnectedUserNickname.uppercased()) has left."
        showBannerLabelAnimated()
    }
    
    
    @objc func handleUserTypingNotification(notification: Notification) {
        if let typingUsersDictionary = notification.object as? [String: AnyObject] {
            var names = ""
            var totalTypingUsers = 0
            for (typingUser, _) in typingUsersDictionary {
                if typingUser != nickname {
                    names = (names == "") ? typingUser : "\(names), \(typingUser)"
                    totalTypingUsers += 1
                }
            }
            
            if totalTypingUsers > 0 {
                let verb = (totalTypingUsers == 1) ? "is" : "are"
                
                lblOtherUserActivityStatus.text = "\(names) \(verb) now typing a message..."
                lblOtherUserActivityStatus.isHidden = false
            }
            else {
                lblOtherUserActivityStatus.isHidden = true
            }
        }
        
    }
    
    
    // MARK: UITableView Delegate and Datasource Methods
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatMessages.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = STBubbleTableViewCell(style: .subtitle, reuseIdentifier: nil)
            //tableView.dequeueReusableCell(withIdentifier:STBubbleTableViewCell.ide, for: indexPath as IndexPath) as! STBubbleTableViewCell
        cell.dataSource = self as STBubbleTableViewCellDataSource
        cell.delegate = self as STBubbleTableViewCellDelegate
        cell.backgroundColor = UIColor.clear
        
        let currentChatMessage = chatMessages[indexPath.row]
        let senderNickname = currentChatMessage["nickname"] as! String
        let message = currentChatMessage["message"] as! String
       // let messageDate = currentChatMessage["date"] as! String
        
        if senderNickname == nickname{
            cell.textLabel?.text = message
            cell.authorType = AuthorType.STBubbleTableViewCellAuthorTypeSelf
            cell.bubbleColor = BubbleColor.STBubbleTableViewCellBubbleColorGreen
        }
        else{
            cell.textLabel?.text = message
            cell.authorType = AuthorType.STBubbleTableViewCellAuthorTypeOther
            cell.bubbleColor = BubbleColor.STBubbleTableViewCellBubbleColorGray

        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let currentChatMessage = chatMessages[indexPath.row]
        let message = currentChatMessage["message"] as! String
        
        let cellSize = CGSize(width: self.tblChat.frame.size.width-self.minInset(for: nil, at: indexPath)-30, height: CGFloat.greatestFiniteMagnitude)
        
        let estimatedFrame = NSString(string: message).boundingRect(with: cellSize, options: NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin), attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)], context: nil)

        return estimatedFrame.height + 20
    }
    
    // MARK: UITextViewDelegate Methods
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        
        SocketManagerIO.sharedInstance.sendStartTypingMessage(nickname: nickname!)
        
        return true
    }

    func textViewDidChange(_ textView: UITextView) { //Handle the text changes here
        if textView.text.count == 0{
            sendButton.isEnabled = false
        }
        else{
            sendButton.isEnabled = true
        }
    }
    
    // MARK: UIGestureRecognizerDelegate Methods
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}

extension ChatViewController:STBubbleTableViewCellDataSource{
    func minInset(for cell: STBubbleTableViewCell!, at indexPath: IndexPath!) -> CGFloat {
        return 50.0
    }
}
extension ChatViewController:STBubbleTableViewCellDelegate{
    
}
