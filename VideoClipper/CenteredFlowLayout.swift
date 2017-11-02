//
//  CenteredFlowLayout.swift
//  Prueba
//
//  Created by Germán Leiva on 28/01/16.
//  Copyright © 2016 Germán Leiva. All rights reserved.
//

import UIKit

protocol CenteredFlowLayoutDelegate:class {
    func layout(_ layout:CenteredFlowLayout,changedModeTo isCentered:Bool)
}

class CenteredFlowLayout: UICollectionViewFlowLayout {
    weak var delegate:CenteredFlowLayoutDelegate? = nil
    
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
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        let spacing = self.itemSize.width + self.minimumInteritemSpacing
        let halfSpacing = spacing / 2
        
        let count = round(proposedContentOffset.x / halfSpacing)
        
        let finalX = halfSpacing * count
        
        self.isCentered = finalX.truncatingRemainder(dividingBy: spacing) != 0
        
        return CGPoint(x: finalX, y: proposedContentOffset.y)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attributesArray = [UICollectionViewLayoutAttributes]()
        
        for attributes in super.layoutAttributesForElements(in: rect.offsetBy(dx: -self.commonOffset,dy: 0))! {
            let copiedAttributes = attributes.copy() as! UICollectionViewLayoutAttributes
            self.applyLayoutAttributes(copiedAttributes)
            attributesArray.append(copiedAttributes)
        }
        return attributesArray
        
//        let attributesArray = super.layoutAttributesForElementsInRect(CGRectOffset(rect,-self.commonOffset,0))!
//        for attributes in attributesArray {
//            self.applyLayoutAttributes(attributes)
//        }
//        return attributesArray
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.layoutAttributesForItem(at: indexPath)!.copy() as! UICollectionViewLayoutAttributes
        self.applyLayoutAttributes(attributes)
        return attributes
    }

    func applyLayoutAttributes(_ attributes: UICollectionViewLayoutAttributes) -> Void {
        // Check for representedElementKind being nil, indicating this is a cell and not a header or decoration view
            
        if (attributes.representedElementKind == nil) {
            attributes.center = CGPoint(x: attributes.center.x + self.commonOffset, y: attributes.center.y)
        }
    }
    
    override var collectionViewContentSize : CGSize {
        let delta = (self.minimumInteritemSpacing + self.itemSize.width) * CGFloat(self.collectionView!.numberOfItems(inSection: 0))
        return CGSize(width: self.collectionView!.frame.width + delta, height: self.collectionView!.frame.height)
    }
}
