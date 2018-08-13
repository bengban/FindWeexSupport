//
//  LocalImageView.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/25.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit

class LocalImageView: UIView {
    fileprivate var url: URL?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUrl(_ url: URL) {
        let data = try? Data.init(contentsOf: url, options: .mappedRead)
        
        let img = UIImage.init(contentsOfFile: url.absoluteString)
        let imgView = UIImageView.init(image: img)
        addSubview(imgView)
        
        imgView.snp.makeConstraints() {
            make in
            make.edges.equalToSuperview()
        }
    }

}
