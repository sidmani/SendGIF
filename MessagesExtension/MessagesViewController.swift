//
//  MessagesViewController.swift
//  MessagesExtension
//
//  Created by Sid Mani on 8/1/16.
//
//

import UIKit
import Messages
import AVFoundation
import ImageIO
import MobileCoreServices

class MessagesViewController: MSMessagesAppViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var videoCaptureOutput = AVCaptureVideoDataOutput()
    var currentFrames:[CGImage] = []
    var isRecording = false
    var ciContext = CIContext()
    var maxFrames:Int = 150 //30 * num of seconds
    @IBOutlet weak var recordButton: RecordButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession.sessionPreset = AVCaptureSessionPreset352x288
        if let captureDevice = cameraWithPosition(.back) {
            do {
                try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
            } catch {
                fatalError()
            }
        }
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)!
        self.view.layer.addSublayer(videoPreviewLayer!)
        self.view.bringSubview(toFront: recordButton)
        self.view.viewWithTag(5)!.tintColor = UIColor.white
        self.view.bringSubview(toFront: self.view.viewWithTag(5)!)
        videoPreviewLayer!.frame = self.view.layer.frame
        videoPreviewLayer!.bounds = self.view.layer.bounds
        videoPreviewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        videoCaptureOutput.alwaysDiscardsLateVideoFrames = true
        let cameraQueue = DispatchQueue(label: "cameraQueue")
        videoCaptureOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        captureSession.addOutput(videoCaptureOutput)
        captureSession.startRunning()
        
        if let videoConnection = self.videoCaptureOutput.connection(withMediaType: AVMediaTypeVideo), (videoConnection.isVideoOrientationSupported) {
            videoConnection.videoOrientation = self.videoPreviewLayer!.connection.videoOrientation
        }
        recordButton.addTarget(self, action: #selector(recordButtonDown), for: .touchDown)
        recordButton.addTarget(self, action: #selector(recordButtonUp), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(recordButtonUp), for: .touchUpOutside)
    }

    @IBAction func switchCamera(_ sender: AnyObject) {
        guard let input = captureSession.inputs[0] as? AVCaptureInput else { return }
        captureSession.beginConfiguration()
        captureSession.removeInput(input)
        if (input as! AVCaptureDeviceInput).device.position == .back {
            if let captureDevice = cameraWithPosition(.front) {
                do {
                    try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
                } catch {
                    fatalError()
                }
            }
        } else {
            if let captureDevice = cameraWithPosition(.back) {
                do {
                    try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
                } catch {
                    fatalError()
                }
            }
        }
        captureSession.commitConfiguration()
        if let videoConnection = self.videoCaptureOutput.connection(withMediaType: AVMediaTypeVideo), (videoConnection.isVideoOrientationSupported) {
            videoConnection.videoOrientation = self.videoPreviewLayer!.connection.videoOrientation
        }
        
    }
    
    func cameraWithPosition(_ position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        guard let devices = AVCaptureDevice.devices() else { return nil }
        for device in devices {
            if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
                    return device as? AVCaptureDevice
            }
        }
        return nil
    }
    
    func newVideoOrientationAfterRotation(_ angle:Int, start:AVCaptureVideoOrientation) -> AVCaptureVideoOrientation {
        //1 -> 90
        //3 -> 180
        //-3 -> -180
        //-1 -> -90
        var angle = angle
        if (angle == -3) {
            angle = 3
        }
        switch (angle) {
         case -1:
            switch (start) {
            case .portrait: return .landscapeLeft
            default: return .portrait
            }
         case 3:
            switch (start) {
            case .landscapeLeft: return .landscapeRight
            case .landscapeRight: return .landscapeLeft
            default: return .portrait
            }
         case 1:
            switch (start) {
            case .portrait: return .landscapeRight
            default: return .portrait
            }
        default: return .portrait
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        videoPreviewLayer!.frame = CGRect(x: videoPreviewLayer!.frame.minX, y: videoPreviewLayer!.frame.minY, width: size.width, height: size.height)
        videoPreviewLayer!.bounds = CGRect(x: videoPreviewLayer!.frame.minX, y: videoPreviewLayer!.frame.minY, width: size.width, height: size.height)
        let angle = Int(atan2(coordinator.targetTransform.b, coordinator.targetTransform.a))
        if (self.videoPreviewLayer!.connection.isVideoOrientationSupported) {
            self.videoPreviewLayer!.connection.videoOrientation = self.newVideoOrientationAfterRotation(angle, start: self.videoPreviewLayer!.connection.videoOrientation)
        }
        if let videoConnection = self.videoCaptureOutput.connection(withMediaType: AVMediaTypeVideo), (videoConnection.isVideoOrientationSupported) {
            videoConnection.videoOrientation = self.videoPreviewLayer!.connection.videoOrientation
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    func recordButtonDown() {
        guard isRecording == false else { return }
        recordButton.centerButton.opacity = 0.5
        print("record button down")
        currentFrames = []
        isRecording = true
    }
    
    func recordButtonUp() {
        guard isRecording == true else { return }
        print("record button up")
        
        recordButton.isEnabled = false
        isRecording = false
        
        guard let url = self.exportGIF(self.currentFrames, frameDelay: 1/30) else {
            print("Image URL is nil!")
            return
        }
        self.recordButton.isEnabled = true
        self.recordButton.centerButton.opacity = 1
        self.recordButton.setProgress(1)
        print("GIF completed processing")
        self.activeConversation?.insertAttachment(url as URL, withAlternateFilename: nil, completionHandler: nil)
        if (self.presentationStyle == .expanded) {
            self.requestPresentationStyle(.compact)
        }
        self.currentFrames = []
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if (isRecording) {
            var ciImage = CIImage(cvImageBuffer: CMSampleBufferGetImageBuffer(sampleBuffer)!)
            if (self.presentationStyle == .compact) {
                ciImage = ciImage.cropping(to: CGRect(x: view.frame.minX, y: ciImage.extent.height - view.frame.height, width: view.frame.width, height: view.frame.height))
            }
            let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)!
            currentFrames.append(cgImage)
            if (currentFrames.count == maxFrames) {
                recordButtonUp()
            } else {
                recordButton.setProgress(1 - CGFloat(currentFrames.count) / CGFloat(maxFrames))
            }
        }
    }
    
    func exportGIF(_ images:[CGImage], frameDelay delay:Double) -> NSURL? {
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: delay]]
        guard let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_gif_maker.gif") else {
            print("Failure to create URL for temporary file!")
            return nil
        }
        guard let imageDestinationRef = CGImageDestinationCreateWithURL(url, kUTTypeGIF, images.count, nil) else {
            print("Failure to create CGImageDestination")
            return nil
        }
        CGImageDestinationSetProperties(imageDestinationRef, fileProperties)
        let remainingProgress = 1 - recordButton.currProgress
        let initProgress = recordButton.currProgress
        for (index, image) in images.enumerated() {
            self.recordButton.setProgress(CGFloat(index+1)/CGFloat(images.count) * remainingProgress + initProgress)
            CGImageDestinationAddImage(imageDestinationRef, image, frameProperties)
        }
        if CGImageDestinationFinalize(imageDestinationRef) {
            return url
        } else {
            print("Failure to finalize image destination!")
            return nil
        }
    }
    
    // MARK: - Conversation Handling
    
    override func willBecomeActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the inactive to active state.
        // This will happen when the extension is about to present UI.
        
        // Use this method to configure the extension and restore previously stored state.
    }
    
    override func didResignActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the active to inactive state.
        // This will happen when the user dissmises the extension, changes to a different
        // conversation or quits Messages.
        
        // Use this method to release shared resources, save user data, invalidate timers,
        // and store enough state information to restore your extension to its current state
        // in case it is terminated later.
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        // Called when a message arrives that was generated by another instance of this
        // extension on a remote device.
        
        // Use this method to trigger UI updates in response to the message.
    }
    
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user taps the send button.
    }
    
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user deletes the message without sending it.
    
        // Use this to clean up state related to the deleted message.
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called before the extension transitions to a new presentation style.
    
        // Use this method to prepare for the change in presentation style.
    }
    
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called after the extension transitions to a new presentation style.
    
        // Use this method to finalize any behaviors associated with the change in presentation style.
    }
    
}

class RecordButton:UIControl {
    private let centerButton = CAShapeLayer()
    private let outsideRing = CAShapeLayer()
    var currProgress:CGFloat = 0
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        centerButton.path = UIBezierPath(arcCenter: CGPoint(x: 25, y: 25), radius: 20, startAngle: 0, endAngle: CGFloat(M_PI) * 2, clockwise: true).cgPath
        centerButton.fillColor = UIColor.red.cgColor
       
        outsideRing.path = UIBezierPath(arcCenter: CGPoint(x: 25, y: 25), radius: 25, startAngle: 3*CGFloat(M_PI_2), endAngle: 3*CGFloat(M_PI_2) + 2 * CGFloat(M_PI), clockwise: true).cgPath
        outsideRing.lineWidth = 5.5
        outsideRing.strokeColor = UIColor.red.cgColor
        outsideRing.fillColor = UIColor.clear.cgColor
        outsideRing.strokeStart = 0

        self.layer.addSublayer(centerButton)
        self.layer.addSublayer(outsideRing)
    }
    
    func setProgress(_ progress: CGFloat) {
        self.currProgress = progress
        CATransaction.begin()
        outsideRing.strokeEnd = progress
        CATransaction.commit()
        CATransaction.flush()
    }
}


