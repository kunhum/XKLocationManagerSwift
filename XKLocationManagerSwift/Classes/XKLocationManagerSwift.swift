//
//  XKLocationManagerSwift.swift
//  Health
//
//  Created by Nicholas on 2020/5/1.
//  Copyright © 2020 Nicholas. All rights reserved.
//

import UIKit
import CoreLocation

enum XKLocationAuthorizeType {
    case whenInUse
    case always
}

enum XKLocationType {
    ///定位城市，一次即停
    case onceCity
}

class XKLocationManagerSwift: NSObject {
    
    ///编译回调
    typealias XKGeocodeHandler = (_ location: CLLocation?, _ coordinate: CLLocationCoordinate2D?, _ placemark: CLPlacemark?, _ city: String?) -> Void
    ///定位完成回调
    typealias XKFinishLocatHandler = (_ location: CLLocation, _ coordinate: CLLocationCoordinate2D, _ placemark: CLPlacemark, _ city: String) -> Void
    
    let manager = CLLocationManager()
    
    var statusHandler: ((_ manager: CLLocationManager, _ status: CLAuthorizationStatus) -> Void)?
    
    var locationType = XKLocationType.onceCity
    
    private var geocodeHandler: XKGeocodeHandler?
    private var finishHandler: XKFinishLocatHandler?
    private var failHandler: ((_ error: NSError?, _ message: String?) -> Void)?
    
    static func xk_defaultManager() -> XKLocationManagerSwift {
        let manager = XKLocationManagerSwift()
        
        let locationManager             = manager.manager
        locationManager.delegate        = manager
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        return manager
    }
    
    
    
}

extension XKLocationManagerSwift : CLLocationManagerDelegate {
    
    //MARK: 授权状态改变
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        statusHandler?(manager, status)
    }
    //MARK: 定位信息更新
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.last else { return }
        
        let coordinate = location.coordinate
        let geocoder   = CLGeocoder()
        
        //反编译地址
        geocoder.reverseGeocodeLocation(location) {
            (placemarks, error) in
            
            guard error == nil else {
                self.failHandler?(error as NSError?, nil)
                return
                
            }
            
            guard let placemark = placemarks?.first else {
                self.failHandler?(nil, "获取地址信息失败")
                return
                
            }
            
            //四大直辖市的城市信息无法通过locality获得，只能通过获取省份的方法来获得（如果city为空，则可知为直辖市）
            var tmpCity = placemark.locality
            if tmpCity == nil {
                tmpCity = placemark.administrativeArea
            }
            guard let city = tmpCity else {
                self.failHandler?(nil, "获取地址信息失败")
                return
            }
            
            self.finishHandler?(location, coordinate, placemark, city)
            
        }
        
        xk_stop()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        let convertionError = error as NSError
        
        if convertionError.code == CLError.denied.rawValue {
            xk_requestAuthorization(type: .whenInUse)
            xk_stop()
            return
        }
        
        failHandler?(error as NSError, nil)
        xk_stop()
    }
    
}
//MARK: - helper
extension XKLocationManagerSwift {
    
    //MARK: 高德地图路线规划
    static func xk_showAMapPath(targetLocation: CLLocationCoordinate2D, currentLocation: CLLocationCoordinate2D, targetName: String) {
        
        let actionText = NSString(format: "iosamap://path?sourceApplication=applicationName&sid=&slat=%f&slon=%f&sname=当前位置&did=&dlat=%f&dlon=%f&dname=%@&dev=0&t=0", currentLocation.latitude, currentLocation.longitude, targetLocation.latitude, targetLocation.longitude, targetName)
        
        guard let naviText = xk_encodeChinese(text: actionText as String) else { return }
        guard let url = URL(string: naviText as String) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
                UIApplication.shared.openURL(url)
            }
        }
        
    }
    
    static func xk_containChinese(text: String) -> Bool {
        
        let convertionText = text as NSString
        
        for i in 0..<convertionText.length {
            let a = convertionText.character(at: i)
            if i > 0x4e00 && a < 0x9fff {
                return true
            }
        }
        return false
        
    }
    
    static func xk_encodeChinese(text: String) -> String? {
        
        let hasChinese = xk_containChinese(text: text)
        let tmpText    = text as NSString
        if (hasChinese) {
            
            guard let afterText = tmpText.addingPercentEncoding(withAllowedCharacters: NSCharacterSet(charactersIn: "`#%^{}\"[]|\\<> ").inverted) else { return nil }
            
            return afterText
        }
        return nil
        
    }
}
//MARK: - action
extension XKLocationManagerSwift {
    
    //MARK: 请求授权
    func xk_requestAuthorization(type: XKLocationAuthorizeType) {
        if CLLocationManager.locationServicesEnabled() == false {
            print("当前设备无定位服务")
            return
        }
        type == .whenInUse ? manager.requestWhenInUseAuthorization() : manager.requestAlwaysAuthorization()
    }
    //MARK: 判断是否有定位服务
    func xk_locationServicesEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    //MARK: 获取当前授权状态
    func xk_currentAuthorizationStatus() -> CLAuthorizationStatus {
        return CLLocationManager.authorizationStatus()
    }
    //MARK: 判断是否允许定位
    func xk_canLocate() -> Bool {
        return xk_currentAuthorizationStatus() == .authorizedAlways || xk_currentAuthorizationStatus() == .authorizedWhenInUse
    }
    //MARK: 授权改变回调
    func xk_authorizationStatusDidChange(handler: ((_ manager: CLLocationManager, _ status: CLAuthorizationStatus) -> Void)?) {
        statusHandler = handler
    }
    //MARK: 跳转至手机设置页
    func xk_showLocationSettingInDevice() {
        
        let urlString = UIApplicationOpenSettingsURLString
        
        let settingUrl = URL(string: urlString)!
        guard UIApplication.shared.canOpenURL(settingUrl) else {
            return
        }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(settingUrl, options: [:]) { (result) in }
        } else {
            // Fallback on earlier versions
            UIApplication.shared.openURL(settingUrl)
        }
    }
    //MARK: 开始定位
    func xk_start() {
        guard xk_locationServicesEnabled() else {
            failHandler?(nil, "定位服务未启用")
            return
        }
        guard xk_canLocate() else {
            failHandler?(nil, "定位权限不足")
            return
        }
        manager.startUpdatingLocation()
        
    }
    //MARK: 停止定位
    func xk_stop() {
        manager.startUpdatingLocation()
    }
    //MARK: 设置精确度
    func xk_setLocationAccuracy(accuracy: CLLocationAccuracy) {
        manager.desiredAccuracy = accuracy
    }
    //MARK: 失败回调
    func xk_fail(handler: ((_ error: NSError?, _ message: String?) -> Void)?) {
        failHandler = handler
    }
    //MARK: 定位完成回调
    func xk_didFinishLocate(handler: XKFinishLocatHandler?) {
        finishHandler = handler
    }
    //MARK: 根据地址编译坐标
    func xk_geocode(address: String, finishHandler: XKGeocodeHandler?) {
        geocodeHandler = finishHandler
    }
}


