//
//  SFJScreenRecoder.swift
//  SFJScreenRecoder
//
//  Created by Shafujiu on 2020/11/23.
//

// TODO: - 参数配置的封装

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
    
    /// 控制暂停
    private var isPaused: Bool = false {
        didSet {
            if isPaused {continueLocked = false}
        }
    }
    /// 暂停记录标记   开关打开的时候 记录下一次继续录制的偏移
    private var continueLocked: Bool = true
    
    /// 记录 继续录制的偏移
    private var continueOffsetTime: CMTime = .zero
    
    /// 记录上一次buffer的时间
    private var previousTime:CMTime = .indefinite
    
}

// MARK: - public api
@available(iOS 11.0, *)
extension SFJScreenRecorder {
    
    func muted(_ muted: Bool) {
        isMuted = muted
    }
    
    func setPaused(_ paused: Bool) {
        self.isPaused = paused
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
    ///   - sampleBuffer: buffer description
    private func assetWriterWritingHandleAction(bufferType: RPSampleBufferType, sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer)  else {return}
        
        // 暂停处理逻辑
        if isPaused { return }
        
        var buffer = sampleBuffer
        var currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(buffer)
        
        if !continueLocked {
            continueLocked = true
            let current = continueOffsetTime.value > 0 ? CMTimeSubtract(currentSampleTime, continueOffsetTime) : currentSampleTime
            let offset = CMTimeSubtract(current, previousTime)
            continueOffsetTime = continueOffsetTime == .zero ? offset : CMTimeAdd(continueOffsetTime, offset)
        }
        
        if continueOffsetTime.value > 0, let bu = adjustTime(buffer, continueOffsetTime) {
            buffer = bu
        }
        currentSampleTime = CMSampleBufferGetPresentationTimeStamp(buffer)
        previousTime = currentSampleTime
        
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
    /// buffer 拼接偏移
    private func adjustTime(_ sampleBuffer: CMSampleBuffer, _ offset:CMTime) -> CMSampleBuffer? {
        var count:CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var pInfo = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: &pInfo, entriesNeededOut: &count)
        
        pInfo.decodeTimeStamp = CMTimeSubtract(pInfo.decodeTimeStamp, offset)
        pInfo.presentationTimeStamp = CMTimeSubtract(pInfo.presentationTimeStamp, offset)
        
        var sout:CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sampleBuffer, sampleTimingEntryCount: count, sampleTimingArray: &pInfo, sampleBufferOut: &sout)
        return sout
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
            self.assetWriterWritingHandleAction(bufferType: bufferType, sampleBuffer: buffer)
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


