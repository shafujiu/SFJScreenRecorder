//
//  WindowUtil.swift
//  BugReporterTest
//
//  Created by Giridhar on 21/06/17.
//  Copyright © 2017 Giridhar. All rights reserved.
//

import UIKit

protocol Overlayable
{
    func show()
    func hide()
}

fileprivate var kWindowHeight: CGFloat = 100
@available(iOS 11.0, *)
class SFJScreenRecorderOverlayWindow: Overlayable
{
    
    typealias SFJScreenRecorderWindowMutedBtnClickBlock = (_ isMuted: Bool) -> ()
    typealias SFJScreenRecorderWindowStopBtnClickBlock = (_ window: SFJScreenRecorderOverlayWindow)->()
    
    
    var onStopClick:SFJScreenRecorderWindowStopBtnClickBlock?
    var onMutedBtnClickBlock: SFJScreenRecorderWindowMutedBtnClickBlock?
//    var recorder: SFJScreenRecorder?
    var currentMuted: Bool {
        mutedBtn.isSelected
    }
    
    
    private lazy var overlayWindow: UIWindow = {
        return UIWindow(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: kWindowHeight))
    }()
    
    private lazy var contentV: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var stopButton: UIButton = {
        let btn = UIButton(type: UIButton.ButtonType.custom)
        btn.backgroundColor = #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1)
        return btn
    }()
    
    private lazy var mutedBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle("关闭麦克风", for: .normal)
        btn.setTitle("开启麦克风", for: .selected)
        btn.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        return btn
    }()
    
    init () {
        self.setupViews()
    }
    
    
    func hide() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3, animations: {
               self.contentV.transform = CGAffineTransform(translationX:0, y: -kWindowHeight)
            }, completion: { (animated) in
                self.overlayWindow.backgroundColor = .clear
                self.overlayWindow.isHidden = true
                self.contentV.isHidden = true
                self.contentV.transform = CGAffineTransform.identity;
            })
            
        }
        
    }
    
    func setupViews () {
        let screenW = UIScreen.main.bounds.width
        overlayWindow.frame = CGRect(x: 0, y: 0, width: screenW, height: kWindowHeight)
        overlayWindow.isUserInteractionEnabled = true
        
        contentV.frame = overlayWindow.bounds
        
        stopButton.setTitle("Stop Recording", for: .normal)
        stopButton.titleLabel?.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        stopButton.addTarget(self, action: #selector(stopRecording), for: .touchUpInside)
        
        mutedBtn.addTarget(self, action: #selector(mutedBtnClick(_:)), for: .touchUpInside)
        mutedBtn.frame = CGRect(x: screenW * 0.5, y: 0, width: screenW * 0.5, height: kWindowHeight)
        stopButton.frame = CGRect(x: 0, y: 0, width: screenW * 0.5, height: kWindowHeight)
        
        contentV.addSubview(mutedBtn)
        contentV.addSubview(stopButton)
        
        overlayWindow.addSubview(contentV)
        overlayWindow.windowLevel = UIWindow.Level(rawValue: CGFloat.greatestFiniteMagnitude)
    }
    
    
    @objc func stopRecording(){
        onStopClick?(self)
        hide()
    }
    
    @objc func mutedBtnClick(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        onMutedBtnClickBlock?(sender.isSelected)
    }
    
    func show()
    {
        DispatchQueue.main.async {
            self.contentV.transform = CGAffineTransform(translationX: 0, y: -kWindowHeight)
            self.overlayWindow.makeKeyAndVisible()
            UIView.animate(withDuration: 0.3, animations: {
                self.contentV.transform = CGAffineTransform.identity
            }, completion: { (animated) in
                
            })
        }
        
    }
}
