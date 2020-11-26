//
//  SFJScreenRecoderCoordinator.swift
//  SFJScreenRecoder
//
//  Created by Shafujiu on 2020/11/23.
//

import UIKit

@available(iOS 11.0, *)
/// 对外输出的协调者，协调 Recorder + UI
class SFJScreenRecorderCoordinator {
    
    typealias ScreenRecorderDidComplateRecordBlock = (_ error: Error?,_ outURL: URL?)->()
    
    private var screenRecorder: SFJScreenRecorder?
    private var overlayableWindow: SFJScreenRecorderOverlayWindow?
    
    var complateBlock: ScreenRecorderDidComplateRecordBlock?
    
    
    /// 配置window
    private func setupOverlayableWindow() {
        overlayableWindow = SFJScreenRecorderOverlayWindow()
        
        overlayableWindow?.onStopClick = { [weak self] window in
            self?.screenRecorder?.stopRecording(handler: { (err, url) in
                self?.complateBlock?(err, url)
            })
        }
        
        overlayableWindow?.onMutedBtnClickBlock = { [weak self] isMuted in
            self?.screenRecorder?.muted(isMuted)
        }
        
        overlayableWindow?.onPausedBtnClickBlock = { [weak self] isPaused in
            self?.screenRecorder?.setPaused(isPaused)
        }
    }
}

// MARK: - public api
@available(iOS 11.0, *)
extension SFJScreenRecorderCoordinator {
    /// 开始 每次开始录制都是一个新的 SFJScreenRecorder对象 以及一个新的 Window对象
    func startRecording() {
        screenRecorder = SFJScreenRecorder()
        setupOverlayableWindow()
        overlayableWindow?.show()
        screenRecorder?.startRecording(withFileName: "视频\(Date().timeIntervalSince1970)") { (err) in
            print("数据写入中 err:", err?.localizedDescription ?? "")
        }
    }
}
