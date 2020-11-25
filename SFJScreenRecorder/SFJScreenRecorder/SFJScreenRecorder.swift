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
//    typealias SFJScreenRecorderDidStopRecorderBlock = (_ url: URL)->()
//    typealias SFJScreenRecorderDidMutedChangedBlock = (_ isMuted: Bool)->()
    // 为什么不用懒加载？
    
    /// 用于写入的对象
    private var assetWriter: AVAssetWriter!
    
    /// assetWriter 视频写入对象
    private var videoInput: AVAssetWriterInput!
    
    /// assetWriter 音频写入对象
    private var audioInput: AVAssetWriterInput!
    
    /// 是否静音
    private var isMuted: Bool = false
}

// MARK: - public api
@available(iOS 11.0, *)
extension SFJScreenRecorder {
    
    func muted(_ muted: Bool) {
        isMuted = muted
    }
    
    func startRecording(withFileName fileName: String, recordingHandler:@escaping (Error?)-> Void) {
        do {
            
            try setupAssetWriter(withFileName: fileName)
            // 提前启动
            assetWriter.startWriting()
            
            RPScreenRecorder.shared().isMicrophoneEnabled = true
            RPScreenRecorder.shared().startCapture { (buffer, bufferType, error) in
                recordingHandler(error)
                let time = CMSampleBufferGetPresentationTimeStamp(buffer)
                self.assetWriter.startSession(atSourceTime: time)
                self.recorderCaptureHandleAction(bufferType: bufferType, buffer: buffer, error: error)
            } completionHandler: { (error) in
                recordingHandler(error)
            }
        } catch {
            recordingHandler(error)
        }
    }
    
    func stopRecording(handler: @escaping (Error?, URL?) -> Void){
    
        RPScreenRecorder.shared().stopCapture { (error) in
            self.assetWriter?.finishWriting { [weak self] in
                let paths = SFJScreenRecorderFileUtil.fetchAllReplays()
                print("paths: ", paths)
                handler(error, self?.assetWriter.outputURL)
            }
        }
    }
}

// MARK: - private api
@available(iOS 11.0, *)
extension SFJScreenRecorder {
    
    /// assetWriter 写入
    /// - Parameters:
    ///   - bufferType: bufferType description
    ///   - buffer: buffer description
    private func assetWriterWritingHandleAction(bufferType: RPSampleBufferType, buffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(buffer)  else {return}
        switch bufferType {
        case .video:
            if videoInput.isReadyForMoreMediaData {
                videoInput.append(buffer)
            }
        case .audioApp:
            break
        case .audioMic:
            if audioInput.isReadyForMoreMediaData {
                if isMuted {
                    muteAudioInBuffer(buffer)
                }
                audioInput.append(buffer)
            }
        @unknown default:
            break
        }
    }
    /// 抓取到buffer的回调
    /// - Parameters:
    ///   - bufferType: bufferType description
    ///   - buffer: buffer description
    ///   - error: error description
    private func recorderCaptureHandleAction(bufferType: RPSampleBufferType, buffer: CMSampleBuffer, error: Error?) {
        switch assetWriter.status {
        case .unknown:
            break
        case .writing:
            self.assetWriterWritingHandleAction(bufferType: bufferType, buffer: buffer)
        case .failed:
            return
        default:
            print("self.assetWriter.status", self.assetWriter.status)
            break
        }
    }
    /// 配置AVAssetWriter
    ///  - description 音视频的参数也在这里配置；每次开始都是一个新的 assetWriter
    /// - Parameter fileName: 文件名字
    private func setupAssetWriter(withFileName fileName: String) throws {
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
    }
    
    /// buffer的声音去掉
    /// - description 大致原理就是将buffer 改写重新输出
    /// - Parameter sampleBuffer: 需要处理的buffer
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
}


