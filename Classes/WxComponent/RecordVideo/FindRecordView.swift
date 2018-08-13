//
//  FindRecordView.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/12.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit
import SnapKit

protocol FindRecordViewDelegate {
    func dismissVC()
    func recordFinish(videoStr: String)
}

class FindRecordView: UIView, FindRecordModelDelegate {
    
    fileprivate var viewType = FindRecordViewType.fullscreen
    var recordModel: FindRecordModel!
    fileprivate var delegate: FindRecordViewDelegate?
    
    //    fileprivate lazy var timeLabel: UILabel = {
    //        let label = UILabel(frame: CGRect.zero)
    //        label.backgroundColor = UIColor.clear
    //        label.textColor = UIColor.white
    //        label.font = UIFont.systemFont(ofSize: 18)
    //        label.text = "00:00/00:00"
    //        self.addSubview(label)
    //        return label
    //    }()
    
    fileprivate lazy var progressView: RecordProgressView = {
        let progressView = RecordProgressView()
        progressView.backgroundColor = UIColor.clear
        self.addSubview(progressView)
        
        progressView.snp.makeConstraints() {
            make in
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 90, height: 90))
            make.bottom.equalTo(-50)
        }
        return progressView
    }()
    
    fileprivate lazy var cancelBtn: UIButton = {
        let cancelBtn = UIButton()
        cancelBtn.setBackgroundImage(UIImage(named: "btn_back"), for: .normal)
        cancelBtn.addTarget(self, action: #selector(dismissVC), for: .touchUpInside)
        self.addSubview(cancelBtn)
        
        return cancelBtn
    }()
    
    fileprivate lazy var turnCamera: UIButton = {
        let turnCamera = UIButton()
        turnCamera.setBackgroundImage(UIImage(named: "btn_camera"), for: .normal)
        turnCamera.addTarget(self, action: #selector(turnCameraBtnClick), for: .touchUpInside)
        self.addSubview(turnCamera)
        
        return turnCamera
    }()
    
    fileprivate lazy var recordBtn: UIButton = {
        let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        btn.layer.cornerRadius = 35
        btn.layer.masksToBounds = true
        btn.backgroundColor = UIColor.init(hexString: "5D62C8")
        //        btn.setBackgroundImage(UIImage(named: "btn_record"), for: .normal)
        btn.addTarget(self, action: #selector(recordBtnClick), for: .touchUpInside)
        return btn
    }()
    
    fileprivate var recordTime: CGFloat = 0
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(frame: CGRect, viewType: FindRecordViewType, delegate: FindRecordViewDelegate?) {
        self.init(frame: frame)
        self.viewType = viewType
        self.delegate = delegate
        setUI()
    }
    
    fileprivate func setUI() {
        recordModel = FindRecordModel(type: self.viewType, delegate: self, superView: self)
        progressView.addSubview(recordBtn)
        recordBtn.snp.makeConstraints() {
            make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 80, height: 80))
        }
        progressView.resetProgress()
        
        cancelBtn.snp.makeConstraints() {
            make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(27)
            make.size.equalTo(CGSize(width: 35, height: 35))
        }
        
        turnCamera.snp.makeConstraints() {
            make in
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(27)
            make.size.equalTo(CGSize(width: 35, height: 35))
        }
    }
    
    @objc fileprivate func recordBtnClick() {
        switch recordModel.recordState {
        case .ready:
            recordModel.startRecord()
        case .recording:
            recordModel.stopRecord()
        default:
            break
        }
    }
    
    @objc fileprivate func dismissVC() {
        delegate?.dismissVC()
    }
    
    @objc fileprivate func turnCameraBtnClick() {
        recordModel.turnCameraAction()
    }
    
    // 实现FindRecordModelDelegate
    func updateRecordState(state: RecordState) {
        switch state {
        case .ready:
            progressView.resetProgress()
        case .recording:
            break
        case .pause:
            break
        case .finish:
            if let url = recordModel.getRecordStr() {
                delegate?.recordFinish(videoStr: url)
            }
        }
    }
    
    func updateRecordTime(curRecord: CGFloat, maxTime: CGFloat) {
        DispatchQueue.main.async {[weak self] in
            guard let weakself = self else { return }
            weakself.progressView.updateProgress(withValue: curRecord/maxTime)
        }
    }
}
