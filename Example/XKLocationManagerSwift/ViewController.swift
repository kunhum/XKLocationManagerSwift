//
//  ViewController.swift
//  XKLocationManagerSwift
//
//  Created by kunhum on 05/20/2020.
//  Copyright (c) 2020 kunhum. All rights reserved.
//

import UIKit
//import XKLocationManagerSwift

class ViewController: UIViewController {
    
    let manager = XKLocationManagerSwift.xk_defaultManager()

    @IBOutlet weak var textLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        manager.xk_requestAuthorization(type: .whenInUse)
        
        manager.xk_authorizationStatusDidChange {
            [unowned self]
            (manager, status) in
            
            self.manager.xk_start()
        }
        
        if manager.xk_canLocate() {
            manager.xk_start()
        }
        
        manager.xk_didFinishLocate {
            [unowned self]
            (location, coordinate, placemark, city) in
            
            self.textLabel.text = city
            
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

