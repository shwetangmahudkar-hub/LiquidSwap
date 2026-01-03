import SwiftUI
import AVFoundation
import Combine

// MARK: - Camera Model (Logic)

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn = false
    @Published var capturedImage: UIImage?
    @Published var currentZoom: CGFloat = 1.0
    
    // Output
    private var output = AVCapturePhotoOutput()
    private var currentPosition: AVCaptureDevice.Position = .back
    
    // Serial Queue for Thread Safety
    private let sessionQueue = DispatchQueue(label: "com.liquidswap.cameraQueue")
    private var isConfigured = false
    
    override init() {
        super.init()
    }
    
    func start() {
        checkPermissions()
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { status in
                self.sessionQueue.resume()
                if status { self.setup() }
            }
        case .denied:
            return
        default:
            return
        }
    }
    
    private func setup() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isConfigured else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // 1. Input (Default to Back)
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device) {
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            }
            
            // 2. Output
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            
            self.session.commitConfiguration()
            
            if !self.session.isRunning {
                self.session.startRunning()
            }
            
            self.isConfigured = true
        }
    }
    
    // MARK: - Actions
    
    func takePic() {
        DispatchQueue.main.async { Haptics.shared.playMedium() }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
        Haptics.shared.playLight()
    }
    
    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove existing input
            if let currentInput = self.session.inputs.first as? AVCaptureDeviceInput {
                self.session.removeInput(currentInput)
            }
            
            // Switch Position
            let newPosition: AVCaptureDevice.Position = (self.currentPosition == .back) ? .front : .back
            
            // Find new device
            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentPosition = newPosition
                } else {
                    // Fallback
                    if let oldDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
                       let oldInput = try? AVCaptureDeviceInput(device: oldDevice) {
                        self.session.addInput(oldInput)
                    }
                }
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.main.async { self.currentZoom = 1.0 }
        }
    }
    
    // MARK: - Zoom & Focus
    
    func setZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let deviceInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            let device = deviceInput.device
            
            do {
                try device.lockForConfiguration()
                let maxZoom: CGFloat = 5.0
                let clampedZoom = max(1.0, min(factor, maxZoom))
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
                
                DispatchQueue.main.async { self.currentZoom = clampedZoom }
            } catch {
                print("Zoom Error: \(error)")
            }
        }
    }
    
    func setFocus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let deviceInput = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            let device = deviceInput.device
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                do {
                    try device.lockForConfiguration()
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                    
                    if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                        device.exposurePointOfInterest = point
                        device.exposureMode = .autoExpose
                    }
                    
                    device.unlockForConfiguration()
                } catch {
                    print("Focus Error: \(error)")
                }
            }
        }
    }
}

// Extension to handle photo output
extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { print("Capture Error: \(error.localizedDescription)"); return }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        // Fix Orientation for Front Camera Mirroring
        var finalImage = image
        if currentPosition == .front, let cgImage = image.cgImage {
             finalImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        }
        
        DispatchQueue.main.async {
            self.capturedImage = finalImage
        }
    }
}

// MARK: - VIEW

struct CameraPicker: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @StateObject var camera = CameraModel()
    
    // Interaction State
    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusSquare = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Camera Preview
            CameraPreviewView(camera: camera, focusAction: { location in
                focusPoint = location
                showFocusSquare = true
                camera.setFocus(at: location)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showFocusSquare = false }
                }
            })
            .ignoresSafeArea()
            .gesture(
                MagnificationGesture()
                    .onChanged { val in
                        let delta = val / lastScale
                        lastScale = val
                        let newZoom = currentZoomFactor * delta
                        currentZoomFactor = min(max(newZoom, 1.0), 5.0)
                        camera.setZoom(factor: currentZoomFactor)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                    }
            )
            
            // 2. Focus Square Animation
            if let point = focusPoint, showFocusSquare {
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .position(x: point.x * UIScreen.main.bounds.width, y: point.y * UIScreen.main.bounds.height)
                    .transition(.opacity)
            }
            
            // 3. Controls
            VStack {
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        CameraCircleButton(icon: "xmark", color: .white)
                    }
                    Spacer()
                    Button(action: camera.toggleFlash) {
                        CameraCircleButton(icon: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill", color: camera.isFlashOn ? .yellow : .white)
                    }
                    Button(action: camera.flipCamera) {
                        CameraCircleButton(icon: "arrow.triangle.2.circlepath.camera.fill", color: .white)
                    }
                }
                .padding()
                .padding(.top, 40)
                
                Spacer()
                
                // Zoom Indicator
                if camera.currentZoom > 1.0 {
                    Text("\(String(format: "%.1fx", camera.currentZoom))")
                        .font(.caption).bold()
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundStyle(.yellow)
                        .padding(.bottom, 20)
                }
                
                // Bottom Bar (Shutter)
                HStack {
                    Spacer()
                    Button(action: { camera.takePic() }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.capturedImage) { newImage in
            if let image = newImage {
                selectedImage = image
                dismiss()
            }
        }
    }
}

// MARK: - Internal Helper Views

struct CameraCircleButton: View {
    let icon: String
    var color: Color = .white
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
    }
}

// MARK: - Internal Preview Layer (UIKit Wrapper)

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    var focusAction: (CGPoint) -> Void
    
    func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView(focusAction: focusAction)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: CameraUIView, context: Context) {
        // No updates needed
    }
    
    static func dismantleUIView(_ uiView: CameraUIView, coordinator: ()) {
        uiView.previewLayer?.session = nil
        uiView.previewLayer?.removeFromSuperlayer()
    }
    
    class CameraUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var focusAction: (CGPoint) -> Void
        
        init(focusAction: @escaping (CGPoint) -> Void) {
            self.focusAction = focusAction
            super.init(frame: .zero)
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            self.addGestureRecognizer(tap)
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = self.bounds
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            let point = sender.location(in: self)
            let normalizedX = point.x / self.bounds.width
            let normalizedY = point.y / self.bounds.height
            focusAction(CGPoint(x: normalizedX, y: normalizedY))
        }
    }
}
