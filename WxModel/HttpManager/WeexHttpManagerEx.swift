//
//  WeexHttpManagerEx.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/22.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit

extension WeexHttpManager {
    func uploadFile(_ filePath: String,callback: @escaping WXModuleKeepAliveCallback) {
        HttpManager.shared.uploadFile(filePath: filePath) {
            (key, error) in
            callback(["key": key ?? "", "error": error ?? ""], false)
        }
    }
    
    func uploadNatImgs(_ idAry: [String],callback: @escaping WXModuleKeepAliveCallback) {
        HttpManager.shared.uploadNatImgs(idAry: idAry) {
            (keys, error) in
            callback(["keys": keys, "error": error ?? ""], false)
        }
    }
}
