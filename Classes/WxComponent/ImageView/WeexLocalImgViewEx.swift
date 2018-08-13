//
//  WeexLocalImgViewEx.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/25.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit
import Foundation

extension WeexLocalImgView {
    open override func updateAttributes(_ attributes: [AnyHashable : Any] = [:]) {
        DispatchQueue.main.async {
            [weak self] in
            guard let weakself = self else { return }
            if let newNatId = attributes["natId"] as? String {
                    weakself.natId = newNatId as NSString
                    weakself.setImgWithNatId(newNatId)
            }
        }
        
    }
    
    open override func loadView() -> UIView {
        super.loadView()
        return UIView()
    }
    
    func setImgWithNatId(_ id: String) {
        addImg()
        WeexFileManager.getImgByNatId(id) {
            (imageT) in
            guard let image = imageT else { return }
            DispatchQueue.main.async {
                [weak self] in
                guard let weakself = self else { return }
                weakself.imgView.image = image
            }
        }
    }
    
    fileprivate func addImg() {
        DispatchQueue.main.async {
            [weak self] in
            guard let weakself = self else { return }
            if weakself.imgView == nil {
                let imgViewT = UIImageView()
                weakself.view.addSubview(imgViewT)
                imgViewT.snp.makeConstraints() {
                    make in
                    make.edges.equalToSuperview()
                }
                weakself.imgView = imgViewT
            }
        }
    }
}
