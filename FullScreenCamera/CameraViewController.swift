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
    // 초기 설정 1
    // - captureSession
    // - AVCaptureDeviceInput
    // - AVCapturePhotoOutput
    // - Custom DispatchQueue
    // - AVCaptureDevice
    
    let captureSession = AVCaptureSession()
    var videoDeviceInput: AVCaptureDeviceInput! // 카메라 디바이스 할당
    let photoOutput = AVCapturePhotoOutput()
    
    let sessionQueue = DispatchQueue(label: "session queue")
    let videoDeviceDiscoverySession
        = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera,
                                                         .builtInWideAngleCamera,
                                                         .builtInTrueDepthCamera],
                                           mediaType: .video, position: .unspecified)
    

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
        
        // 초기 설정 2
        previewView.session = captureSession
        sessionQueue.async {
            self.setupSession()
            self.startSession()
        }
        setupUI()
        
    }
    
    func setupUI() {
        photoLibraryButton.layer.cornerRadius = 10
        photoLibraryButton.layer.masksToBounds = true
        photoLibraryButton.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        photoLibraryButton.layer.borderWidth = 1
        
        captureButton.layer.cornerRadius = captureButton.bounds.height / 2
        captureButton.layer.masksToBounds = true
        
        blurBGView.layer.cornerRadius = blurBGView.bounds.height / 2
        blurBGView.layer.masksToBounds = true
    }
    
    
    @IBAction func switchCamera(sender: Any) {
        // 카메라는 1개 이상이어야함
        guard videoDeviceDiscoverySession.devices.count > 1 else {
            return
        }
        
        // 반대 카메라 찾아서 재설정
        // - 반대 카메라 찾고
        // - 새로운 디바이스를 가지고 세션 업데이트
        // - 카메라 토글 버튼 업데이트
        
        sessionQueue.async {
            
            // 카메라 찾기
            let currentVideoDevice = self.videoDeviceInput.device // 현재 디바이스 가져옴
            let currentPosition = currentVideoDevice.position // 디바이스(카메라)의 위치 확인
            let isFront = currentPosition == .front // 디바이스 포지션이 isFront?
            let preferredPosition: AVCaptureDevice.Position = isFront ? .back : .front
            
            let devices = self.videoDeviceDiscoverySession.devices
            
            var newVideoDevice: AVCaptureDevice?
            // 첫 번쨰 카메라를 찾아 newVideoDevice 에 할당
            newVideoDevice = devices.first { device in preferredPosition == device.position }
            
            // 캡처 세션 업데이트
            if let newDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: newDevice)
                    self.captureSession.beginConfiguration()
                    self.captureSession.removeInput(self.videoDeviceInput) //
                    
                    // add new device input
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.captureSession.addInput(self.videoDeviceInput)
                    }
                    
                    self.captureSession.commitConfiguration()
                    
                    // UI 작업
                    DispatchQueue.main.async {
                        self.updateSwitchCameraIcon(position: preferredPosition)
                    }
                } catch let error {
                    print("error occured while creating device input: \(error.localizedDescription)")
                }
                
                    
            }
        }
        
    }
    
    func updateSwitchCameraIcon(position: AVCaptureDevice.Position) {
        switch position {
        case .front:
            let image = #imageLiteral(resourceName: "ic_camera_front")
            switchButton.setImage(image, for: .normal)
        case .back:
            let image = #imageLiteral(resourceName: "ic_camera_rear")
            switchButton.setImage(image, for: .normal)
        default:
            break
        }
        
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        // photoOutput의 capturePhoto 메소드
        // orientation
        // photooutput
        
        // 기기 방향 가져오기
        let videoPreviewLayerOrientaton = self.previewView.videoPreviewLayer.connection?.videoOrientation
        
        //
        sessionQueue.async {
            let connection = self.photoOutput.connection(with: .video)
            connection?.videoOrientation = videoPreviewLayerOrientaton!
            let setting = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: setting, delegate: self)    // 사진 찍기
        }

    }
    
    
    func savePhotoLibrary(image: UIImage) {
        // capture한 이미지 포토라이브러리에 저장
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // 저장
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { (success, error) in
                    print("success? \(success)")
                })
            } else {
                // 다시 요청
                print("--> 사진 라이브러리 접근 권한을 받지 못하였습니다.")
            }
        }
    }
}


extension CameraViewController {
    // MARK: - Setup session and preview
    func setupSession() {
        // captureSession 구성하기
        // - presetSetting 하기
        // - beginConfiguration
        // - Add Video Input
        // - Add Photo Output
        // - commitConfiguration
        
        captureSession.sessionPreset = .photo
        captureSession.beginConfiguration()
        
        // add video input
        guard let camera = videoDeviceDiscoverySession.devices.first else {
            captureSession.commitConfiguration()
            return
        }
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput // self.videoDeviceInput의 nil 방지
            } else {
                captureSession.commitConfiguration()
                return
            }
            
        } catch {
            captureSession.commitConfiguration()
            return
        }
        
        // add photo output
        photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        } else {
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.commitConfiguration()
        
    }
    
    
    
    func startSession() {
        // session Start
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }

    }
    
    func stopSession() {
        // session Stop
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
        
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // capturePhoto delegate method 구현
        // 사진이 찍혔을 때 (버튼이 눌리고 이미지 만들어짐)
        
        guard error == nil else { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }
        self.savePhotoLibrary(image: image)
        
    }
}
