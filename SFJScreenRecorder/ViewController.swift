//
//  ViewController.swift
//  SFJScreenRecoder
//
//  Created by Shafujiu on 2020/11/23.
//

import UIKit

@available(iOS 11.0, *)
class ViewController: UIViewController {

    let screenRecorder = SFJScreenRecorder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        screenRecorder.didStopRecorderBlock = { [weak self] prevc in
            DispatchQueue.main.async {
                self?.present(prevc, animated: true, completion: nil)
            }
        }
        
        
        
        
       
        
        
    }


    @IBAction func startBtnClick(_ sender: Any) {
        screenRecorder.startRecording(withFileName: "视频\(Date().timeIntervalSince1970)") { (err) in
            if let error = err {
                
                print(error)
            } else {
                print("handle writer")
            }
        }
    }
    
    @IBAction func stopBtnClick(_ sender: Any) {
        screenRecorder.stopRecording { (err) in
            print(err)
        }
    }
    @IBAction func clear(_ sender: Any) {
        
        SFJScreenRecorderFileUtil.deleteScreenRecorderFiles()
    }
}

