import UIKit

import AVFoundation
import CoreMotion

struct EmailData {
    var outputURL: URL!
    var degree: Double!
}

class CameraViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {

    @IBOutlet weak var camPreview: UIView!

    @IBOutlet weak var cameraButton: UIView!
    
    @IBOutlet weak var degreeLabel: UILabel!
    
    @IBOutlet weak var recordingLabel: UILabel!
    
    let captureSession = AVCaptureSession()

    let movieOutput = AVCaptureMovieFileOutput()

    var previewLayer: AVCaptureVideoPreviewLayer!

    var activeInput: AVCaptureDeviceInput!

    var outputURL: URL!
    
    var manager : CMMotionManager!
    
    var finalDegree : Double!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Camera
        if setupSession() {
            setupPreview()
            startSession()
        }
        
        self.camPreview.translatesAutoresizingMaskIntoConstraints = false
        self.camPreview.addSubview(recordingLabel)
        recordingLabel.isHidden = true

        // Camera Button
        cameraButton.isUserInteractionEnabled = true

        let cameraButtonRecognizer = UITapGestureRecognizer(target: self, action: #selector(CameraViewController.startCapture))

        cameraButton.addGestureRecognizer(cameraButtonRecognizer)

        cameraButton.backgroundColor = UIColor.red
        
        
        self.cameraButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Gyroscope
        self.manager = CMMotionManager()
        self.manager!.gyroUpdateInterval = 0.1

        // remember to stop it.. with:      self.manager?.stopGyroUpdates()
        self.manager?.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: { [weak self] (motion, error) -> Void in

        // Get the attitude of the device
        if let attitude = motion?.attitude {
            // Get the pitch (in radians) and convert to degrees.
            // Import Darwin to get M_PI in Swift
            // print(attitude.pitch * 180.0/M_PI)

            DispatchQueue.main.async {
                let degree = attitude.pitch * 180 / Double.pi
                self?.degreeLabel.text = String(degree)
                self?.finalDegree = degree
                
                if (degree >= 30 && degree <= 45) {
                    self?.cameraButton.backgroundColor = UIColor.green
                } else {
                    self?.cameraButton.backgroundColor = UIColor.red
                }
            }
        }

        })


    }

    func setupPreview() {
        // Configure previewLayer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = camPreview.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        camPreview.layer.addSublayer(previewLayer)
    }

    //MARK:- Setup Camera

    func setupSession() -> Bool {

        captureSession.sessionPreset = AVCaptureSession.Preset.high

        // Setup Camera
        let camera = AVCaptureDevice.default(for: AVMediaType.video)! // rear camera
        // let camera = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video, position: AVCaptureDevice.Position.front)! // front camera
        do {

            let input = try AVCaptureDeviceInput(device: camera)

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
        } catch {
            print("Error setting device video input: \(error)")
            return false
        }

        // Setup Microphone
        let microphone = AVCaptureDevice.default(for: AVMediaType.audio)!

        do {
            let micInput = try AVCaptureDeviceInput(device: microphone)
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
            }
        } catch {
            print("Error setting device audio input: \(error)")
            return false
        }


        // Movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        return true
    }

    func setupCaptureMode(_ mode: Int) {
        // Video Mode

    }

    //MARK:- Camera Session
    func startSession() {

        if !captureSession.isRunning {
            videoQueue().async {
                self.captureSession.startRunning()
            }
        }
    }

    func stopSession() {
        if captureSession.isRunning {
            videoQueue().async {
                self.captureSession.stopRunning()
            }
        }
    }

    func videoQueue() -> DispatchQueue {
        return DispatchQueue.main
    }

    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation

        switch UIDevice.current.orientation {
            case .portrait:
                orientation = AVCaptureVideoOrientation.portrait
            case .landscapeRight:
                orientation = AVCaptureVideoOrientation.landscapeLeft
            case .portraitUpsideDown:
                orientation = AVCaptureVideoOrientation.portraitUpsideDown
            default:
                 orientation = AVCaptureVideoOrientation.landscapeRight
         }

         return orientation
     }

    @objc func startCapture() {
        
        startRecording()

    }

    //EDIT 1: I FORGOT THIS AT FIRST

    func tempURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString

        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mp4")
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        let vc = segue.destination as! VideoPlaybackViewController
        let data: EmailData = sender as! EmailData

        vc.videoURL = data.outputURL as URL
        vc.finalDegree = data.degree as Double
    }

    func startRecording() {
        recordingLabel.isHidden = false
        
        _ = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(stopRecording), userInfo: nil, repeats: false)

        if movieOutput.isRecording == false {

            let connection = movieOutput.connection(with: AVMediaType.video)

            if (connection?.isVideoOrientationSupported)! {
                connection?.videoOrientation = currentVideoOrientation()
            }

            if (connection?.isVideoStabilizationSupported)! {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }

            let device = activeInput.device

            if (device.isSmoothAutoFocusSupported) {

                do {
                    try device.lockForConfiguration()
                    device.isSmoothAutoFocusEnabled = false
                    device.unlockForConfiguration()
                } catch {
                   print("Error setting configuration: \(error)")
                }

            }

            //EDIT2: And I forgot this
            outputURL = tempURL()
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)

            }
        else {
            stopRecording()
        }

   }

    @objc func stopRecording() {

       recordingLabel.isHidden = true
       if movieOutput.isRecording == true {
          cameraButton.backgroundColor = UIColor.red

          movieOutput.stopRecording()
       }
   }

    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {

    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {

        if (error != nil) {

            print("Error recording movie: \(error!.localizedDescription)")

        } else {
            let videoRecorded = outputURL! as URL

            let data = EmailData(outputURL: videoRecorded, degree: self.finalDegree)
            performSegue(withIdentifier: "showVideo", sender: data)

        }

    }

}
