//
//  MarkerReusableView.swift
//  Prueba
//
//  Created by Germán Leiva on 29/01/16.
//  Copyright © 2016 Germán Leiva. All rights reserved.
//

import UIKit

protocol MarkerReusableViewDelegate {
    func didTouchMarker()
}

class MarkerReusableView: UICollectionReusableView {
    var delegate:MarkerReusableViewDelegate? = nil
    var bypassToView:UIView!
    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, withEvent: event)
        if hitView == self {
            return self.bypassToView
        }
        return hitView
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesBegan(touches, withEvent: event)
        self.delegate?.didTouchMarker()
    }
}
