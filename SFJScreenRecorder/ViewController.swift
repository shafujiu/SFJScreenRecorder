//
//  ViewController.swift
//  SFJScreenRecoder
//
//  Created by Shafujiu on 2020/11/23.
//
// 差一个 合并；异常情况处理；横竖屏
import UIKit
import AVKit
@available(iOS 11.0, *)
class ViewController: UIViewController {

    @IBOutlet weak var animateV: UIView!
    @IBOutlet weak var tableView: UITableView!
    
    var items: [URL] = []
    var playerVC: AVPlayerViewController?
    let screenRecorder = SFJScreenRecorderCoordinator()
    
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
    }

    @IBAction func startBtnClick(_ sender: Any) {
        screenRecorder.startRecording()
    }
    
    @IBAction func stopBtnClick(_ sender: Any) {
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

