//
//  CenteredFlowLayout.swift
//  Prueba
//
//  Created by Germán Leiva on 28/01/16.
//  Copyright © 2016 Germán Leiva. All rights reserved.
//

import UIKit

protocol CenteredFlowLayoutDelegate {
    func layout(layout:CenteredFlowLayout,changedModeTo isCentered:Bool)
}

class CenteredFlowLayout: UICollectionViewFlowLayout {
    var delegate:CenteredFlowLayoutDelegate? = nil
    
    var isCentered = false {
        didSet {
            self.delegate?.layout(self, changedModeTo: isCentered)
        }
    }
    
    var commonOffset:CGFloat {
        get {
            return self.collectionView!.frame.width / 2 - self.minimumInteritemSpacing / 2
        }
    }
    
    func changeMode() {
        isCentered = !isCentered
        self.invalidateLayout()
        let delta = (self.itemSize.width + self.minimumInteritemSpacing) / 2
        var direction = CGFloat(1)
        var minimum = CGFloat(0)
        if isCentered {
            direction = -1
            minimum = delta
        }
        let xOffset = max(self.collectionView!.contentOffset.x + delta * direction,minimum)

        self.collectionView!.setContentOffset(CGPoint(x: xOffset, y: 0), animated: true)
    }
    
    override func targetContentOffsetForProposedContentOffset(proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        let spacing = self.itemSize.width + self.minimumInteritemSpacing
        let halfSpacing = spacing / 2
        
        let count = round(proposedContentOffset.x / halfSpacing)
        
        let finalX = halfSpacing * count
        
        self.isCentered = finalX % spacing != 0
        
        return CGPoint(x: finalX, y: proposedContentOffset.y)
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
//        var attributesArray = [UICollectionViewLayoutAttributes]()
//        
//        for attributes in super.layoutAttributesForElementsInRect(CGRectOffset(rect,-self.commonOffset,0))! {
//            let copiedAttributes = attributes.copy() as! UICollectionViewLayoutAttributes
//            self.applyLayoutAttributes(copiedAttributes)
//            attributesArray.append(copiedAttributes)
//        }
//        return attributesArray
        
        let attributesArray = super.layoutAttributesForElementsInRect(CGRectOffset(rect,-self.commonOffset,0))!
        for attributes in attributesArray {
            self.applyLayoutAttributes(attributes)
        }
        return attributesArray
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.layoutAttributesForItemAtIndexPath(indexPath)!.copy() as! UICollectionViewLayoutAttributes
        self.applyLayoutAttributes(attributes)
        return attributes
    }

    func applyLayoutAttributes(attributes: UICollectionViewLayoutAttributes) -> Void {
        // Check for representedElementKind being nil, indicating this is a cell and not a header or decoration view
            
        if (attributes.representedElementKind == nil) {
            attributes.center = CGPoint(x: attributes.center.x + self.commonOffset, y: attributes.center.y)
        }
    }
    
    override func collectionViewContentSize() -> CGSize {
        let delta = (self.minimumInteritemSpacing + self.itemSize.width) * CGFloat(self.collectionView!.numberOfItemsInSection(0))
        return CGSize(width: self.collectionView!.frame.width + delta, height: self.collectionView!.frame.height)
    }
}
