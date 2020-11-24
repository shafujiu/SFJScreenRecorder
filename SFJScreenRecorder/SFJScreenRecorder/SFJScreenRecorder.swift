//
//  SFJScreenRecoder.swift
//  SFJScreenRecoder
//
//  Created by Shafujiu on 2020/11/23.
//

import UIKit
import ReplayKit
import AVKit
@available(iOS 11.0, *)
class SFJScreenRecorder: NSObject {
    typealias SFJScreenRecorderDidStopRecorderBlock = (_ previewVC: RPPreviewViewController)->()
    // 为什么不用懒加载？
    private var assetWriter: AVAssetWriter!
    private var videoInput: AVAssetWriterInput!
    private var audioInput: AVAssetWriterInput!
    var didStopRecorderBlock: SFJScreenRecorderDidStopRecorderBlock?
    
    
    private func captureHandleAction(bufferType: RPSampleBufferType, buffer: CMSampleBuffer, error: Error?) {
        switch self.assetWriter.status {
        case .unknown:
            // 启动
            self.assetWriterStart(buffer: buffer)
        case .writing:
            print("assetWriterWriting")
            self.assetWriterWriting(bufferType: bufferType, buffer: buffer)
        case .failed:
            print("self.assetWriter.status failed", error)
            return
        default:
            print("self.assetWriter.status", self.assetWriter.status)
            break
        }
    }
    
    private func assetWriterStart(buffer: CMSampleBuffer) {
        if self.assetWriter?.startWriting() ?? false != true {
            print("startWriting failed")
            return
        }
        self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
    }
    
//    @available(iOS 10.0, *)
    private func assetWriterWriting(bufferType: RPSampleBufferType, buffer: CMSampleBuffer) {
        
        switch bufferType {
        
        case .video:
            if videoInput.isReadyForMoreMediaData {
                videoInput.append(buffer)
            }
        case .audioApp:
            break
        case .audioMic:
            if audioInput.isReadyForMoreMediaData {
                audioInput.append(buffer)
            }
        @unknown default:
            break
        }
    }
    
    /// 静音处理
    private func muteAudioInBuffer(_ sampleBuffer: CMSampleBuffer) {
        let numSamples: CMItemCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let size = CMSampleBufferGetSampleSize(sampleBuffer, at: .zero)
        guard let bock = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(bock)
        
        print("numSamples = \(numSamples), size = \(size), length = \(length)")
        
        let channelIndex: CMItemCount = 0
        let audioBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)

        let audioBlockBufferOffset = (channelIndex * numSamples * MemoryLayout.size(ofValue: Int.self))
    

        var lengthAtOffset: Int = 0
        var totalLength: Int = 0

        var dataPointerOut:UnsafeMutablePointer<Int8>?

        CMBlockBufferGetDataPointer(audioBlockBuffer!,
                                    atOffset: audioBlockBufferOffset,
                                    lengthAtOffsetOut: &lengthAtOffset,
                                    totalLengthOut: &totalLength ,
                                    dataPointerOut: &dataPointerOut)

        for i in 0..<length {
            dataPointerOut?.advanced(by: i).pointee = 0
        }
    }
//    @available(iOS 11.0, *)
    private func initAssetWriter(withFileName fileName: String) {
        let fileURL = URL(fileURLWithPath: SFJScreenRecorderFileUtil.filePath(fileName))
        assetWriter = try! AVAssetWriter(outputURL: fileURL, fileType: .mp4)
        
        let videoOutputSettings: [String : Any] = [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : UIScreen.main.bounds.size.width,
            AVVideoHeightKey : UIScreen.main.bounds.size.height
        ];
        
        videoInput  = AVAssetWriterInput (mediaType: .video, outputSettings: videoOutputSettings)
        // 实时数据
        videoInput.expectsMediaDataInRealTime = true
        assetWriter.add(videoInput)
        // FIXME: - 音频参数配置 调整
        let audioSettings = [AVEncoderBitRatePerChannelKey:28000,
                             AVFormatIDKey:kAudioFormatMPEG4AAC,
                             AVNumberOfChannelsKey:1,
                             AVSampleRateKey:22050]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = false
        assetWriter.add(audioInput)
    }
    
    func muted(_ muted: Bool) {
        
    }
}
// public api
@available(iOS 11.0, *)
extension SFJScreenRecorder: RPScreenRecorderDelegate {
    
    func startRecording(withFileName fileName: String, recordingHandler:@escaping (Error?)-> Void) {
    
//        stopRecording { (err) in
//            print("stopRecording", err)
//        }
        do {
            
            let fileURL = URL(fileURLWithPath: SFJScreenRecorderFileUtil.filePath(fileName))
            assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            
            let videoOutputSettings: [String : Any] = [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : UIScreen.main.bounds.size.width,
                AVVideoHeightKey : UIScreen.main.bounds.size.height
            ];
            videoInput = AVAssetWriterInput (mediaType: .video, outputSettings: videoOutputSettings)
            // 实时数据
            videoInput.expectsMediaDataInRealTime = true
            assetWriter.add(videoInput)
            // FIXME: - 音频参数配置 调整
            let audioSettings = [AVEncoderBitRatePerChannelKey:28000,
                                 AVFormatIDKey:kAudioFormatMPEG4AAC,
                                 AVNumberOfChannelsKey:1,
                                 AVSampleRateKey:22050]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = false
            assetWriter.add(audioInput)
            
            RPScreenRecorder.shared().isMicrophoneEnabled = true
            RPScreenRecorder.shared().delegate = self
            RPScreenRecorder.shared().startCapture { (buffer, bufferType, error) in
                recordingHandler(error)
                
                self.captureHandleAction(bufferType: bufferType, buffer: buffer, error: error)
            } completionHandler: { (error) in
                recordingHandler(error)
            }
        } catch {
            recordingHandler(error)
        }
    }
    
    func stopRecording(handler: @escaping (Error?) -> Void){
        RPScreenRecorder.shared().stopCapture
        {    (error) in
            handler(error)
            self.assetWriter?.finishWriting {
                print(SFJScreenRecorderFileUtil.fetchAllReplays())
            }
        }
    }
    
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?) {
        guard let preVC = previewViewController else {
            return
        }
        didStopRecorderBlock?(preVC)
    }
    
}
