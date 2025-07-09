//
//  ViewController.swift
//  3dModelCreation_r&d
//
//  Created by KSMACMINI-019 on 09/07/25.
//

import UIKit
import RealityKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var capturedImageCount = 0
    var maxImages = 50 // You can limit or allow user to decide
    let folderURL: URL = {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("ScanImages")
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture Photo", for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        captureButton.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        captureButton.frame = CGRect(x: 80, y: 200, width: 250, height: 50)
        view.addSubview(captureButton)
        
        let processButton = UIButton(type: .system)
        processButton.setTitle("Generate 3D Model", for: .normal)
        processButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        processButton.addTarget(self, action: #selector(startPhotogrammetry), for: .touchUpInside)
        processButton.frame = CGRect(x: 80, y: 300, width: 250, height: 50)
        view.addSubview(processButton)
    }

    @objc func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert("Camera not available")
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.cameraCaptureMode = .photo
        present(picker, animated: true)
    }

    @objc func startPhotogrammetry() {
        // Check if device supports photogrammetry
        guard PhotogrammetrySession.isSupported else {
            showAlert("Photogrammetry not supported on this device.")
            return
        }

        Task {
            do {
                let outputURL = folderURL.appendingPathComponent("HeadModel.usdz")

                // Setup session config
                var config = PhotogrammetrySession.Configuration()
                config.sampleOrdering = .unordered
                config.featureSensitivity = .normal

                // Create session
                let session = try PhotogrammetrySession(input: folderURL, configuration: config)

                // Process request
                try await session.process(requests: [
                    .modelFile(url: outputURL)
                ])

                Task {
                    for try await output in session.outputs {
                        switch output {
                        case .requestProgress(let request, let fraction):
                            let percent = Int(fraction * 100)
                            print("📸 Progress for \(request): \(percent)%")

                        case .processingComplete:
                            print("✅ Photogrammetry completed!")
                            showAlert("3D model is ready!")

                        case .requestError(_, let error):
                            print("❌ Error: \(error.localizedDescription)")
                            showAlert("Processing error: \(error.localizedDescription)")

                        default:
                            break
                        }
                    }
                    // Note: place process() before or after loop depending on flow
                }

            } catch {
                print("❌ Failed to run photogrammetry: \(error)")
                showAlert("Error: \(error.localizedDescription)")
            }
        }
    }

    
    // MARK: - Delegate Method
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            showAlert("Image not found")
            return
        }

        // Save image to folder
        let imageName = "capture_\(capturedImageCount).jpg"
        let fileURL = folderURL.appendingPathComponent(imageName)
        if let data = image.jpegData(compressionQuality: 0.95) {
            try? data.write(to: fileURL)
            capturedImageCount += 1
            print("Saved: \(imageName)")
        }

        if capturedImageCount >= maxImages {
            showAlert("Captured max \(maxImages) images")
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
