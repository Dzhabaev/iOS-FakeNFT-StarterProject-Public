//
//  RatingView.swift
//  FakeNFT
//
//  Created by Chalkov on 13.05.2024.
//

import UIKit

final class RatingView: UIStackView {
    
    private let fillStarImage: UIImage? = UIImage(named: "starFilled")
    private let emptyStarImage: UIImage? = UIImage(named: "starEmpty")
    
    init(rating: Int = 5) {
        super.init(frame: .zero)
        axis = .horizontal
        spacing = 2
        translatesAutoresizingMaskIntoConstraints = false
        
        (1...rating).forEach {
            let imageView = UIImageView()
            imageView.image = emptyStarImage
            imageView.tag = $0
            addArrangedSubview(imageView)
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupRating(rating: Int) {
        subviews.forEach {
            if let imageView = $0 as? UIImageView {
                imageView.image = imageView.tag > rating ? emptyStarImage : fillStarImage
            }
        }
    }
}
