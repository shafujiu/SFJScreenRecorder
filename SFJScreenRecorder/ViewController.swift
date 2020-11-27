//
//  ViewController.swift
//  SFJScreenRecoder
//
//  Created by Shafujiu on 2020/11/23.
//
// 差一个 合并；异常情况处理（前后台）；横竖屏
import UIKit
import AVKit
@available(iOS 11.0, *)
class ViewController: UIViewController {

    @IBOutlet weak var timeLbl: UILabel!
    @IBOutlet weak var animateV: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    var items: [URL] = []
    var playerVC: AVPlayerViewController?
    let screenRecorder = SFJScreenRecorderCoordinator()
    
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        screenRecorder.complateBlock = { [weak self] (err, url) in
            DispatchQueue.main.async {
                if let url = url {
                    self?.items.append(url)
                    self?.tableView.reloadData()
                }
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {[weak self] (_) in
            self?.timeLbl.text = "\(Date())"
        }
    }

    @IBAction func mergeBtnClick(_ sender: UIButton) {
        activityIndicatorView.isHidden = false
        activityIndicatorView.startAnimating()
        DPVideoMerger().mergeVideos(withFileURLs: items) { (outUrl, error) in
            self.activityIndicatorView.stopAnimating()
            self.view.isUserInteractionEnabled = true
            self.activityIndicatorView.isHidden = true
            if error != nil {
                let errorMessage = "Could not merge videos: \(error?.localizedDescription ?? "error")"
                let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert) 
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (a) in
                }))
                self.present(alert, animated: true) {() -> Void in }
                return
            }
            let objAVPlayerVC = AVPlayerViewController()
            objAVPlayerVC.player = AVPlayer(url: outUrl!)
            self.present(objAVPlayerVC, animated: true, completion: {() -> Void in
                objAVPlayerVC.player?.play()
            })
        }
        
    }
    @IBAction func startBtnClick(_ sender: Any) {
        screenRecorder.startRecording()
    }
    
    @IBAction func clear(_ sender: Any) {
        SFJScreenRecorderFileUtil.deleteScreenRecorderFiles()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "player" {
           playerVC = segue.destination as? AVPlayerViewController
        }
    }
}

@available(iOS 11.0, *)
extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].lastPathComponent
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        playerVC?.player = AVPlayer(url: items[indexPath.row])
        playerVC?.player?.play()
    }
}

