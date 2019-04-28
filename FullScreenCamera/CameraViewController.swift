//
//  ViewController.swift
//  FullScreenCamera
//
//  Created by joonwon lee on 28/04/2019.
//  Copyright © 2019 com.joonwon. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController {
    
    private let captureSession = AVCaptureSession()
    private var isSessionRunning = false
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    
    var videoDeviceInput: AVCaptureDeviceInput!
    let photoOutput = AVCapturePhotoOutput()
    let photoOutputSetting = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)

    @IBOutlet weak var photoLibraryButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var blurBGView: UIVisualEffectView!
    @IBOutlet weak var switchButton: UIButton!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        previewView.session = captureSession
        
        
        /*
         Setup the capture session.
         In general, it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. We dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.setupSession()
            self.startSession()
        }
    }
    
    func setupUI() {
        photoLibraryButton.layer.cornerRadius = 10
        photoLibraryButton.layer.masksToBounds = true
        photoLibraryButton.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        photoLibraryButton.layer.borderWidth = 1
        
        captureButton.layer.cornerRadius = captureButton.bounds.height/2
        captureButton.layer.masksToBounds = true
        
        blurBGView.layer.cornerRadius = blurBGView.bounds.height/2
        blurBGView.layer.masksToBounds = true
        
    }
    
    
    @IBAction func switchCamera(sender: Any) {
        // 카메라는 1개 이상이어야함
        guard videoDeviceDiscoverySession.devices.count > 1 else {
            return
        }
        
        
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            let isFront = currentPosition == .front
            let preferredPosition: AVCaptureDevice.Position = isFront ? .back : .front
            
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice?
            
            // find new device input (.back or .front)
            newVideoDevice = devices.first { $0.position == preferredPosition }
            
            if let newDevice = newVideoDevice {
                do {
                    
                    // update session configuration
                    let videoDeviceInput = try AVCaptureDeviceInput(device: newDevice)
                    self.captureSession.beginConfiguration()
                    self.captureSession.removeInput(self.videoDeviceInput)
                    
                    // Add new device input
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.captureSession.addInput(self.videoDeviceInput)
                    }
                    self.captureSession.commitConfiguration()
                    
                    
                    // update button image
                    DispatchQueue.main.async {
                        self.updateSwitchCameraIcon(position: preferredPosition)
                    }
                } catch let error {
                    print("errror occured while creagting device input: \(error.localizedDescription)")
                }
            }
            
            
            
            
        }
    }
    
    func updateSwitchCameraIcon(position: AVCaptureDevice.Position) {
        switch position {
        case .front:
            switchButton.setImage(#imageLiteral(resourceName: "ic_camera_front"), for: .normal)
        case .back:
            switchButton.setImage(#imageLiteral(resourceName: "ic_camera_rear"), for: .normal)
        default:
            break
        }
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        let videoPreviewLayerOrientation = self.previewView.videoPreviewLayer.connection?.videoOrientation

        sessionQueue.async {
            let connection = self.photoOutput.connection(with: .video)
            connection?.videoOrientation = videoPreviewLayerOrientation!
            let setting = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: setting, delegate: self)
        }
    }
    
    
    func savePhotoLibrary(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { (_, error) in
                    DispatchQueue.main.async {
                        self.photoLibraryButton.setImage(image, for: .normal)
                    }
                })

            } else {
                print("error to save photo library")
            }
        }
    }
}


extension CameraViewController {
    // MARK: - Setup session and preview
    func setupSession() {
        captureSession.sessionPreset = .photo
        captureSession.beginConfiguration()
        
        // Add Video Input
        do {
            var defaultVideoDevice: AVCaptureDevice?
            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                // In the event that the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
            
            guard let camera = defaultVideoDevice else {
                captureSession.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                captureSession.commitConfiguration()
                return
            }
        } catch {
            captureSession.commitConfiguration()
            return
        }
        
        // Add photo output
        photoOutput.setPreparedPhotoSettingsArray([photoOutputSetting], completionHandler: nil)
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        } else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.commitConfiguration()
    }
    
    
    
    func startSession() {
        if !captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }
        self.savePhotoLibrary(image: image)
    }
}
