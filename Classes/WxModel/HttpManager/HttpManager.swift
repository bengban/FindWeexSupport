//
//  HttpManager.swift
//  WeexDemo
//
//  Created by 徐林琳 on 2018/6/14.
//  Copyright © 2018年 taobao. All rights reserved.
//

import UIKit
import Alamofire

struct ServerConfig {
    struct errcode {
        static var maintain = 0x0010
        static var unusable = 0x0011
    }
    
    static let useNewServerBooks = true
    struct command {
        struct account {
            static let touristLogin = "account.touristLogin";
            static let thirdPartyLogin = "account.thirdPartyLogin";
            static let login = "account.login";
            static let checkPhoneNumber = "account.checkPhoneNumber";
            static let register = "account.register"
            
            static let getInfo = "account.getInfo"
            //            static let getUserInfo = "account.getUserInfo"
            static let completeInfo = "account.completeInfo"
            static let changePassword = "account.changePassword"
            static let setUserImage = "account.setUserImage"
            static let forgetPassword = "account.forgetPassword"
            
            static let bindPhoneNumber = "account.bindPhoneNumber"
            
            static let follow = "account.follow"
            static let verifyFriend = "account.verifyFriend"
            static let addFriend = "account.addFriend"
            
            static let feedback = "account.feedback"
        }
        
        
        struct leTV {
            static let bindSession = "leTV.bindSession"
            static let createTVSession = "leTV.createTVSession"
            
            static let getNews = "leTV.getNews"
            static let getNewNews = "leTV.getNewNews"
            static let getImageTextVindicate = "leTV.getImageTextVindicate"
            static let setNewsIsRead = "leTV.setNewsIsRead"
        }
        
        struct action {
            static let sendAction = "action.sendAction"
            static let pull = "action.pull"
            static let like = "action.like"
            static let getComment = "action.getComment"
            
        }
        struct message {
            static let pullNotification = "message.pullNotification"
            static let setAlreadyRead = "message.setAlreadyRead"
            
            static let checkAlreadyRead = "message.checkAlreadyRead"
            
        }
        struct musicScore {
            static let getHomeRecommend = "musicScore.getHomeRecommend"
            static let getAllBooks = "musicScore.getAllBooks"
            
            static let getPracticeRecent = "musicScore.getPracticeRecent"
            static let addPracticeMusic = "musicScore.addPracticeMusic"
            static let delPracticeMusic = "musicScore.delPracticeMusic"
            static let getFoldersByUserId = "musicScore.getFoldersByUserId"
            static let checkPracticeMusic = "musicScore.checkPracticeMusic"
            static let getPracticeMusic = "musicScore.getPracticeMusic"
            
            static let delFolder = "musicScore.delFolder"
            static let getMusicsByFolder = "musicScore.getMusicsByFolder"
            
            static let getBooksByTag = "musicScore.getBooksByTag"
            static let getMusicsByBook = "musicScore.getMusicsByBook"
            static let getBookById = "musicScore.getBookById"
            static let getMusicInfo = "musicScore.getMusicInfo"
            
            static let getUpdateTime = "musicScore.getUpdateTime"
            
            static let addPracticeRecent = "musicScore.addPracticeRecent"
            static let delPracticeRecent = "musicScore.delPracticeRecent"
            
            static let getMusicStyles = "musicScore.getMusicStyles"
            static let getMusicTags = "musicScore.getMusicTags"
            static let getMusicsInter = "musicScore.getMusicsInter"
            static let getBooksInter = "musicScore.getBooksInter"
            static let getBooksByAuthor = "musicScore.getBooksByAuthor"
            
            static let getAllBookSets = "musicScore.getAllBookSets"
            
            static let addMusicClicks = "musicScore.addMusicClicks"
            static let addBookClicks = "musicScore.addBookClicks"
        }
        struct statistics {
            static let  uploadData = "statistics.uploadData"
            static let  getData = "statistics.getData"
            static let  getScoreByMusicId = "statistics.getScoreByMusicId"
        }
        
        struct file {
            static let getToken = "file.getToken"
        }
        
        struct pay {
            static let getTn = "pay.getTn"
            
            static let getRecord = "pay.getRecord"
            static let getProductList = "pay.getProductList"
            static let getOwnedMusic = "pay.getOwnedMusic"
            static let permanentPurchase = "pay.permanentPurchase"
            static let purchaseBook = "pay.purchaseBook"
            
            static let getUserMoney = "pay.getUserMoney"
            
            static let applePay = "pay.applePay"
            static let getApplePayProduct = "pay.getApplePayProduct"
        }
        
        struct system {
            static let getIosAppValid = "system.getIosAppValid"
        }
    }
    
    struct server {
        static var address = "https://api.etango.cn:13001"      // "http://192.168.7.56:3002    https://api.etango.cn:13001" //
//        static var friendAddress = ServerFriendAddress
//        static var urlAddress = ServerUrlAddress
    }
    
    struct version {
        static var ver = 512
        static var lang = "zh_cn"
    }
}


class HttpManager: NSObject {
    class var shared : HttpManager {
        struct Static {
            static let instance : HttpManager = HttpManager()
        }
        return Static.instance
    }
    
    // 上传文件
    fileprivate func getQiniuToken(name: String, block:@escaping ( _ key : String?, _ token : String?, _ ErrorMsg: String?)->()) {
        postNewServer(ServerConfig.command.file.getToken, params: ["fileName": name]) {
            (body, error) in
            guard error == nil,
                let dic = body as? [String: Any],
                let key = dic["key"] as? String,
                let token = dic["token"] as? String else {
                    block(nil, nil, error)
                    return
            }
            block(key, token, nil)
        }
    }
    
    fileprivate func qiniuUpload(filePath: String, token: String, key: String, block:@escaping (_ key : String?, _ ErrorMsg: String?)->()) {
        if !FileManager.default.fileExists(atPath: filePath) {
            block(nil, "文件不存在")
            return
        }
        QNUploadManager().putFile(filePath, key: key, token: token, complete:{ (res, fileKey, resp) in
            if let error = res?.error, resp == nil {
                block(nil, error.localizedDescription)
                return
            }
            block(fileKey ?? "", nil)
        }, option: nil)
        
    }
    
    func uploadFile(filePath: String, block:@escaping (_ key : String?, _ ErrorMsg: String?)->()) {
        let fileUrl = URL(fileURLWithPath: filePath)
        let fileName = fileUrl.lastPathComponent
        getQiniuToken(name: fileName) {[weak self] (key, token, error) in
            guard let weakself = self, error == nil, let key = key, let token = token else {
                block(nil, error)
                return
            }
            weakself.qiniuUpload(filePath: filePath, token: token, key: key) {(key, error) in
                guard error == nil, let key = key else {
                    block(nil, error)
                    return
                }
                block(key, nil)
            }
        }
    }
    
    func uploadNatImgs(idAry:[String], block:@escaping (_ key : [String], _ ErrorMsg: String?)->()) {
        var keys: [String] = []
        
        for id in idAry {
            WeexFileManager.natIdToPath(id) {[weak self]
                path in
                guard let weakself = self else { return }
                if path == "" {
                    keys.append("")
                    try? FileManager.default.removeItem(atPath: path)
                    if keys.count == idAry.count {
                        block(keys, nil)
                    }
                } else {
                    weakself.uploadFile(filePath: path) { (key, error) in
                        keys.append(key ?? "")
                        try? FileManager.default.removeItem(atPath: path)
                        if keys.count == idAry.count {
                            block(keys, nil)
                        }
                    }
                }
            }
        }
    }
    
}

extension NSObject {
    func postNewServer(_ cmd: String, params:[String: Any]?, block:@escaping (_ response: Any?, _ errMsg: String?)->()) {
        let type = cmd.contains("account") ? 2 : 3
        
        var parameters = [
            "header": [
                "size": 0,
                "orn": "",
                "dst": "",
                "type": type,
                "cmd": cmd,
                "ver": ServerConfig.version.ver,
                "lang": ServerConfig.version.lang, //LanguageManager.COM_LOCAL("en")
                "sess": "0166a265269cce70",
                "seq": 0,
                "code": 0,
                "desc": "",
                "stmp": DeviceInfo.getCurrentTime(),
                "ext": ""
            ],
            ]
        
        parameters["body"] = params ?? [:]
        //        print(ServerConfig.server.address)
        Alamofire.request(ServerConfig.server.address, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Content-type" : "application/json"])
            .responseJSON {
                re in
                print("ServerConfig.server.address:\(ServerConfig.server.address)--parameters\(parameters)")
                if re.result.isSuccess{
                    guard
                        let value = re.result.value as? [String: Any],
                        let header = value["header"] as? [String: Any]
                        else {
                            block(nil, "response is empty")
                            return
                    }
                    //                    print(value)
                    guard let code = header["code"] as? Int , code == 0 else {
                        if let msg = header["desc"] as? String,
                            let code = header["code"] as? Int {
                            
                            if code == 5 && !cmd.contains("checkPracticeMusic") {
                                block(nil, "无效的session,请重新登录")
                                return
                            }
                            block(["code" : code], msg)
                        } else {
                            block(nil, "response is empty")
                        }
                        
                        return
                    }
                    block(value["body"], nil)
                } else {
                    block(nil, "web is error")
                }
        }
        
    }
    
}
