//
//  WeexFileManagerEx.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/25.
//  Copyright © 2018年 taobao. All rights reserved.
//


import Photos


extension WeexFileManager {
    static func natIdToPath(_ id: String, block: @escaping (_ path: String) -> Void) {
        guard id.contains("nat://static/image/") else {
            block("")
            return
        }
        let localId = id.replacingOccurrences(of: "nat://static/image/", with: "")
        let strAry = localId.components(separatedBy: "/")
        
        let assetResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [strAry[0]], options: nil)
        let asset = assetResult[0]
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData)
            -> Bool in
            return true
        }
        
        PHImageManager.default().requestImageData(for: asset, options: nil) {
            (imageData, dataUTI, orientation, info) in
            
            let saveFolder = WeexFilePath.MediaTmp.image
            if !FileManager.default.fileExists(atPath: saveFolder) {
                try? FileManager.default.createDirectory(atPath: saveFolder, withIntermediateDirectories: true, attributes: nil)
            }
            guard let imgUrl = info!["PHImageFileURLKey"] as? URL,
                let fileName = imgUrl.lastPathComponent as String? else {
                return
            }
            
            let savePath = saveFolder + fileName
            
            FileManager.default.createFile(atPath: savePath, contents: imageData, attributes: nil)
            if FileManager.default.fileExists(atPath: savePath) {
                block(savePath)
            } else {
                block("")
            }
            print("地址：",savePath)
            
        }
        //获取保存的图片路径
//        asset.requestContentEditingInput(with: options, completionHandler: {
//            (contentEditingInput:PHContentEditingInput?, info: [AnyHashable : Any]) in
//            let path = contentEditingInput?.fullSizeImageURL?.absoluteString ?? ""
//            print("地址：",path)
//            block(path)
//
//        })
    }
    
    static func getImgByNatId(_ id: String,  block: @escaping (_ image: UIImage?) -> Void) {
        guard id.contains("nat://static/image/") else {
            block(nil)
            return
        }
        let localId = id.replacingOccurrences(of: "nat://static/image/", with: "")
        let assetResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [localId], options: nil)
        let asset = assetResult[0]
        //获取保存的原图
        PHImageManager.default().requestImage(for: asset,
                                              targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit,
                                              options: nil, resultHandler: { (image, _:[AnyHashable : Any]?) in
                                                block(image)
        })
    }
}
