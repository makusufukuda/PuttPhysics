import Flutter
import Photos
import PhotosUI
import UIKit

final class OriginalVideoPicker: NSObject, PHPickerViewControllerDelegate {
    private var pendingResult: FlutterResult?

    func pickVideo(
        from presentingController: UIViewController,
        result: @escaping FlutterResult
    ) {
        guard pendingResult == nil else {
            result(FlutterError(
                code: "PICKER_BUSY",
                message: "Video picker is already open",
                details: nil
            ))
            return
        }

        var configuration = PHPickerConfiguration(
            photoLibrary: PHPhotoLibrary.shared()
        )
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        pendingResult = result
        presentingController.present(picker, animated: true)
    }

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)

        let result = pendingResult
        pendingResult = nil

        guard let selected = results.first else {
            result?(nil)
            return
        }

        guard let identifier = selected.assetIdentifier else {
            result?(FlutterError(
                code: "ASSET_IDENTIFIER_MISSING",
                message: "Selected video has no asset identifier",
                details: nil
            ))
            return
        }

        result?([
            "assetIdentifier": identifier
        ])
    }
}
