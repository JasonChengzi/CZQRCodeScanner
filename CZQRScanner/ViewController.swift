//
//  ViewController.swift
//  CZQRScanner
//
//  Created by Jason.Chengzi on 12/22/16.
//  Copyright © 2016 czlee. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    fileprivate var scanRect            : CGRect    = CGRect.zero
    fileprivate var isQRCodeCaptured    : Bool      = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setup()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

extension ViewController {
    func setup() {
        let size    = CGSize(width: view.frame.width * 0.8, height: view.frame.height * 0.8)
        let origin  = CGPoint(x: view.center.x - size.width / 2, y: view.center.y - size.height / 2)
        scanRect    = CGRect(origin: origin, size: size)
        
        let authorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { [unowned self] granted in
                guard granted else { return self.showNotification("Cannot access camera") }
                self.setupCapture()
            }
        case .authorized:
            setupCapture()
        case .restricted, .denied:
            showNotification("Cannot access camera")
        }
    }
    func setupCapture() {
        DispatchQueue.main.async {
            let session = AVCaptureSession()
            let device  = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            
            do {
                let deviceInput     = try AVCaptureDeviceInput(device: device)
                session.addInput(deviceInput)
                
                let metadataOutput  = AVCaptureMetadataOutput()
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                session.addOutput(metadataOutput)
                metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
                
                guard let previewLayer = AVCaptureVideoPreviewLayer(session: session) else { return }
                previewLayer.videoGravity  = AVLayerVideoGravityResizeAspectFill
                previewLayer.frame         = self.view.frame
                self.view.layer.insertSublayer(previewLayer, at: 0)
                
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureInputPortFormatDescriptionDidChange, object: nil, queue: OperationQueue.current) { (notification) in
                    metadataOutput.rectOfInterest = previewLayer.metadataOutputRectOfInterest(for: self.scanRect)
                }
                
                let readerView  = QRCodeReaderView(scanRect: self.scanRect)
                self.view.addSubview(readerView)
                
                session.startRunning()
            } catch let error as NSError {
                self.showNotification(error.localizedDescription)
            }
        }
    }
}

extension ViewController {
    func showNotification(_ message: String) {
        let controller = UIAlertController(title: "BE AWARE", message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Okay", style: .cancel, handler: nil))
        show(controller, sender: self)
    }
    func showReadingError(_ message: String) {
        let controller = UIAlertController(title: "WARNING", message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Okay", style: .cancel, handler: nil))
        show(controller, sender: self)
    }
    func showConfirm(_ message: String) {
        let controller = UIAlertController(title: "MESSAGE", message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Not now", style: .cancel) { action in
            self.presentResult()
        })
        controller.addAction(UIAlertAction(title: "GO", style: .destructive) { (action) in
            
        })
        show(controller, sender: self)
    }
}

extension ViewController {
    func presentResult() {
        
    }
}

extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject else { return showReadingError("Read failed") }
        guard metadataObject.type == AVMetadataObjectTypeQRCode && isQRCodeCaptured == false else { return showReadingError("Incorrect type") }
        isQRCodeCaptured = true
        print("Scanned result: \n\(metadataObject.stringValue)")
        
        guard let stringValue = metadataObject.stringValue else { return showReadingError("Incorrect QRCode") }
        if stringValue.hasPrefix("http://") || stringValue.hasPrefix("https://") {
            return showReadingError("QRCode points to a url link, would you want to open it in safari?")
        } else {
            self.presentResult()
        }
    }
}

class QRCodeReaderView: UIView {
    fileprivate var scanRect: CGRect = CGRect.zero
    
    convenience init(scanRect: CGRect) {
        self.init(frame: UIScreen.main.bounds)
        
        backgroundColor = UIColor.clear
        self.scanRect   = scanRect
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        
        let screenPath  = CGMutablePath()
        screenPath.addRect(bounds)
        context.addPath(screenPath)
        
        let scanPath    = CGMutablePath()
        scanPath.addRect(scanRect)
        context.addPath(scanPath)
        
        let path        = CGMutablePath()
        path.addPath(screenPath)
        path.addPath(scanPath)
        context.addPath(path)
        
        context.drawPath(using: .eoFill)
    }
}
