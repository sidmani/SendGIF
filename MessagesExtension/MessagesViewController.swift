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
typealias Filter = (name: String, key: String)

class MessagesViewController: MSMessagesAppViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    var videoPreviewLayer = CALayer()
    let videoCaptureOutput = AVCaptureVideoDataOutput()
    
    var currentFrames:[CGImage] = []
    var isRecording = false
    let ciContext = CIContext()
    let maxFrames = 150 //30 * num of seconds
    var frameNum = 0
    var isReversed = false
    var currentOrientation:AVCaptureVideoOrientation = .portrait
    
    var currentFilter:Filter?
    
    
    @IBOutlet weak var speedControl: UISegmentedControl!
    @IBOutlet weak var recordButton: RecordButton!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var filterPicker: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        if let captureDevice = cameraWithPosition(.back) {
            do {
                try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
            } catch {
                fatalError()
            }
        }
      //  videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)!
     //   self.view.layer.addSublayer(videoPreviewLayer!)
        self.view.layer.addSublayer(videoPreviewLayer)

        self.view.bringSubview(toFront: recordButton)
        self.view.bringSubview(toFront: speedControl)
        self.view.viewWithTag(5)!.tintColor = UIColor.white
        self.view.viewWithTag(4)!.tintColor = UIColor.white
        
        
        videoPreviewLayer.contentsGravity = kCAGravityResizeAspectFill
        videoPreviewLayer.frame = self.view.layer.frame
        videoPreviewLayer.bounds = self.view.layer.bounds

        self.view.bringSubview(toFront: self.view.viewWithTag(4)!)
        self.view.bringSubview(toFront: self.view.viewWithTag(5)!)
        self.view.bringSubview(toFront: filterButton)
        self.view.bringSubview(toFront: filterPicker)

        videoCaptureOutput.alwaysDiscardsLateVideoFrames = true
        let cameraQueue = DispatchQueue(label: "cameraQueue")
        videoCaptureOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        captureSession.addOutput(videoCaptureOutput)
        captureSession.startRunning()
        videoPreviewLayer.transform = CATransform3DMakeRotation(CGFloat.pi/2, 0, 0, 1)

//        if let videoConnection = self.videoCaptureOutput.connection(withMediaType: AVMediaTypeVideo), (videoConnection.isVideoOrientationSupported) {
//        }
        recordButton.addTarget(self, action: #selector(recordButtonDown), for: .touchDown)
        recordButton.addTarget(self, action: #selector(recordButtonUp), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(recordButtonUp), for: .touchUpOutside)
    }

    @IBAction func switchCamera(_ sender: AnyObject) {
        guard let input = captureSession.inputs[0] as? AVCaptureInput else { return }
        captureSession.beginConfiguration()
        captureSession.removeInput(input)
        if (input as! AVCaptureDeviceInput).device.position == .back {
            UIView.animate(withDuration: 1) {
                let transform = CGAffineTransform.init(rotationAngle: CGFloat(M_PI))
                self.view.viewWithTag(5)!.transform = transform
            }

            if let captureDevice = cameraWithPosition(.front) {
                do {
                    try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
                } catch {
                    fatalError()
                }
            }
        } else {
            UIView.animate(withDuration: 1) {
                let transform = CGAffineTransform.init(rotationAngle: 0)
                self.view.viewWithTag(5)!.transform = transform
            }

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
            videoConnection.videoOrientation = newVideoOrientationAfterRotation(0, start: currentOrientation)
        }
        videoPreviewLayer.transform = CATransform3DMakeRotation(CGFloat.pi/2, 0, 0, 1)

    }
    
    @IBAction func openFilterPicker(_ sender: AnyObject) {
        if (filterPicker.isHidden) {
            filterButton.setTitle("Back", for: .normal)
            filterPicker.isHidden = false
        } else {
            filterButton.setTitle("No Filter", for: .normal)
            filterPicker.isHidden = true
        }
    }
    
    @IBAction func reverseGIF(_ sender: AnyObject) {
        if (isReversed) {
            isReversed = false
            UIView.animate(withDuration: 0.5) {
                let transform = CGAffineTransform.init(rotationAngle: 0)
                self.view.viewWithTag(4)!.transform = transform
                self.speedControl.tintColor = UIColor.red
            }
            recordButton.switchReversed(false)
        } else {
            isReversed = true
            UIView.animate(withDuration: 0.5) {
                let transform = CGAffineTransform.init(rotationAngle: CGFloat(M_PI))
                self.view.viewWithTag(4)!.transform = transform
                self.speedControl.tintColor = UIColor.blue
            }
            recordButton.switchReversed(true)
        }
    }
    
    func cameraWithPosition(_ position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        guard let devices = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: position) else { return nil }
        for device in devices.devices {
            if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
                    return device
            }
        }
        return nil
    }
    
    func newVideoTransformAfterRotation(_ angle:Int, start:AVCaptureVideoOrientation) -> CATransform3D {
        //1 -> 90
        //3 -> 180
        //-3 -> -180
        //-1 -> -90
        print("\(angle) \(start.rawValue)")
        var angle = angle
        if (angle == -3) {
            angle = 3
        }
        switch (angle) {
         case -1:
            switch (start) {
            case .portrait: return CATransform3DMakeRotation(-CGFloat.pi/2, 0, 0, 1)
            default: return CATransform3DMakeRotation(0, 0, 0, 1)
            }
         case 3:
            switch (start) {
            case .landscapeLeft: return CATransform3DMakeRotation(CGFloat.pi, 0, 0, 1)
            case .landscapeRight: return CATransform3DMakeRotation(CGFloat.pi, 0, 0, 1)
            default: return CATransform3DMakeRotation(0, 0, 0, 1)
            }
         case 1:
            switch (start) {
            case .portrait: return CATransform3DMakeRotation(CGFloat.pi/2, 0, 0, 1)
            default: return CATransform3DMakeRotation(0, 0, 0, 1)
            }
        default: return CATransform3DMakeRotation(0, 0, 0, 1)
        }
    }
    
    func newVideoOrientationAfterRotation(_ angle:Int, start:AVCaptureVideoOrientation) -> AVCaptureVideoOrientation {
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        videoPreviewLayer.frame = CGRect(x: videoPreviewLayer.frame.minX, y: videoPreviewLayer.frame.minY, width: size.width, height: size.height)
        videoPreviewLayer.bounds = CGRect(x: videoPreviewLayer.frame.minX, y: videoPreviewLayer.frame.minY, width: size.width, height: size.height)
        let angle = Int(atan2(coordinator.targetTransform.b, coordinator.targetTransform.a))
        //if (self.videoPreviewLayer!.connection.isVideoOrientationSupported) {
    //        self.videoPreviewLayer!.connection.videoOrientation = self.newVideoOrientationAfterRotation(angle, start: self.videoPreviewLayer!.connection.videoOrientation)
        //}
        if let videoConnection = self.videoCaptureOutput.connection(withMediaType: AVMediaTypeVideo), (videoConnection.isVideoOrientationSupported) {
            videoConnection.videoOrientation = newVideoOrientationAfterRotation(0, start: currentOrientation)
        }

       // if let videoConnection = self.videoCaptureOutput.connection(withMediaType: AVMediaTypeVideo), (videoConnection.isVideoOrientationSupported) {
    //        videoConnection.videoOrientation = self.videoPreviewLayer!.connection.videoOrientation
        //    videoPreviewLayer.transform = newVideoOrientationAfterRotation(angle, start: videoConnection.videoOrientation)
      //  }
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    func recordButtonDown() {
        guard isRecording == false else { return }
        recordButton.centerButton.opacity = 0.5
        print("record button down")
        currentFrames = []
        isRecording = true
        speedControl.isUserInteractionEnabled = false
    }
    
    func recordButtonUp() {
        guard isRecording == true else { return }
        print("record button up")
        speedControl.isUserInteractionEnabled = true
        recordButton.isEnabled = false
        isRecording = false
        var gifSpeed:Double = 1
        if (speedControl.selectedSegmentIndex == 0) {
            gifSpeed = 2
        }
        guard let url = self.exportGIF(self.currentFrames, frameDelay: gifSpeed * 1.0/30.0) else {
            print("Image URL is nil!")
            self.recordButton.isEnabled = true
            self.recordButton.centerButton.opacity = 1
            self.recordButton.setProgress(1)
            self.currentFrames = []
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
        frameNum = 0
        self.currentFrames = []
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        var ciImage = CIImage(cvImageBuffer: CMSampleBufferGetImageBuffer(sampleBuffer)!)
        if (self.presentationStyle == .compact) {
            ciImage = ciImage.cropping(to: CGRect(x: view.frame.minX, y: ciImage.extent.height - view.frame.height, width: view.frame.width, height: view.frame.height))
        }

        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)!
        CATransaction.begin()
        videoPreviewLayer.contents = cgImage
        CATransaction.commit()
        CATransaction.flush()

        if (isRecording) {
            switch (speedControl.selectedSegmentIndex) {
            case 1:
                currentFrames.append(cgImage)
            case 0:
                currentFrames.append(cgImage)
            case 2:
                if (frameNum % 2 == 0) {
                    currentFrames.append(cgImage)
                }
            default: break
            }
            if (currentFrames.count == maxFrames) {
                recordButtonUp()
            } else {
                recordButton.setProgress(1 - CGFloat(currentFrames.count) / CGFloat(maxFrames))
            }
            frameNum += 1
        }
    }
    
    func exportGIF(_ images:[CGImage], frameDelay delay:Double) -> URL? {
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: delay]]
        guard let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_gif_maker.gif") else {
            print("Failure to create URL for temporary file!")
            return nil
        }
        guard let imageDestinationRef = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeGIF, images.count, nil) else {
            print("Failure to create CGImageDestination")
            return nil
        }
        CGImageDestinationSetProperties(imageDestinationRef, fileProperties as CFDictionary?)
        let remainingProgress = 1 - recordButton.currProgress
        let initProgress = recordButton.currProgress
       
        for (index, image) in (isReversed ? images.reversed().enumerated() : images.enumerated()) {
            self.recordButton.setProgress(CGFloat(index+1)/CGFloat(images.count) * remainingProgress + initProgress)
            CGImageDestinationAddImage(imageDestinationRef, image, frameProperties as CFDictionary?)
        }
        if CGImageDestinationFinalize(imageDestinationRef) {
            return url
        } else {
            print("Failure to finalize image destination!")
            return nil
        }
    }

}

class RecordButton:UIControl {
    let centerButton = CAShapeLayer()
    let outsideRing = CAShapeLayer()
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
    
    func switchReversed(_ val:Bool) {
        if (val) {
            outsideRing.strokeColor = UIColor.blue.cgColor
            centerButton.fillColor = UIColor.blue.cgColor
        } else {
            outsideRing.strokeColor = UIColor.red.cgColor
            centerButton.fillColor = UIColor.red.cgColor
        }
    }
}


