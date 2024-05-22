//
//  CollectionDetailsViewControllerPresenter.swift
//  FakeNFT
//
//  Created by Chingiz on 08.05.2024.
//

import Foundation

// MARK: - CollectionDetailsViewControllerPresenter

final class CollectionDetailsViewControllerPresenter {
    
    typealias Completion = (Result<Nft, Error>) -> Void
    
    weak var viewController: (CollectionDetailsViewController & ErrorView)?
    let authorURLString = "https://practicum.yandex.ru/ios-developer/"
    
    // MARK: - Private Properties
    
    private var onLoadCompletion: (([Nft]) -> Void)?
    private var idLikes: Set<String> = []
    private var idAddedToCart: Set<String> = []
    private let nftModel: CatalogModel
    private let nftService: NftService
    private var loadedNFTs: [Nft] = []
    private let userNFTService: UserNFTService
    private var checkedNftIds: Set<String> = []
    private var fetchingNftLikes: Set<String> = []
    private var checkedNft: Set<String> = []
    private var fetchingNftCart: Set<String> = []
    
    // MARK: - Initializers
    
    init(nftModel: CatalogModel, nftService: NftService, userNFTService: UserNFTService) {
        self.nftModel = nftModel
        self.nftService = nftService
        self.userNFTService = userNFTService
    }
    
    // MARK: - Public Methods
    
    func returnCollectionCell(for index: Int) -> CollectionCellModel {
        let nftForIndex = loadedNFTs[index]
        checkIfNftIsFavorite(nftForIndex.id)
        checkIfNftIsAddedToCart(nftForIndex.id)
        return CollectionCellModel(image: nftForIndex.images[0],
                                   name: nftForIndex.name,
                                   rating: nftForIndex.rating,
                                   price: nftForIndex.price,
                                   isLiked: self.isLiked(nftForIndex.id),
                                   isAddedToCart: self.isAddedToCart(nftForIndex.id),
                                   id: nftForIndex.id
        )
    }
    
    func processNFTsLoading() {
        UIBlockingProgressHUD.show()
        nftModel.nfts.forEach { loadNftById(id: $0) }
    }
    
    func setOnLoadCompletion(_ completion: @escaping ([Nft]) -> Void) {
        onLoadCompletion = completion
    }
    
    func changeLike(nftID: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        UIBlockingProgressHUD.show()
        
        userNFTService.getProfile { [weak self] result in
            guard let self = self else { return }
            defer { UIBlockingProgressHUD.dismiss() }
            switch result {
            case .success(let model):
                var likes = model.likes
                let isAdded: Bool
                
                if likes.contains(nftID) {
                    likes.removeAll { $0 == nftID }
                    isAdded = false
                } else {
                    likes.append(nftID)
                    isAdded = true
                }
                
                self.userNFTService.changeLike(newLikes: likes, profile: model) { [weak self] result in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            NotificationCenter.default.post(name: NSNotification.Name("LikeUpdated"), object: nil, userInfo: ["nftID": nftID, "isAdded": isAdded])
                            completion(.success(isAdded))
                        case .failure(let error):
                            let errorModel = self.makeErrorModel(error) { self.changeLike(nftID: nftID, completion: completion) }
                            self.viewController?.showError(errorModel)
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let errorModel = self.makeErrorModel(error) { self.changeLike(nftID: nftID, completion: completion) }
                    self.viewController?.showError(errorModel)
                    completion(.failure(error))
                }
            }
        }
    }
    
    func changeCart(nftID: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        UIBlockingProgressHUD.show()
        
        userNFTService.getCart { [weak self] result in
            guard let self = self else { return }
            defer { UIBlockingProgressHUD.dismiss() }
            switch result {
            case .success(let model):
                var cart = model.nfts
                let id = nftID
                var isAdded = false
                
                if cart.contains(id) {
                    cart.removeAll { $0 == id }
                    isAdded = false
                } else {
                    cart.append(id)
                    isAdded = true
                }
                
                self.userNFTService.changeCart(newCart: cart, cart: model) { [weak self] result in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            NotificationCenter.default.post(name: NSNotification.Name("CartUpdated"), object: nil, userInfo: [:])
                            completion(.success(isAdded))
                        case .failure(let error):
                            let errorModel = self.makeErrorModel(error) { self.changeCart(nftID: nftID, completion: completion) }
                            self.viewController?.showError(errorModel)
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let errorModel = self.makeErrorModel(error) { self.changeCart(nftID: nftID, completion: completion) }
                    self.viewController?.showError(errorModel)
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadNftById(id: String) {
        UIBlockingProgressHUD.show()
        nftService.loadNft(id: id) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let nft):
                self.loadedNFTs.append(nft)
                self.onLoadCompletion?(self.loadedNFTs)
                UIBlockingProgressHUD.dismiss()
            case .failure(let error):
                let errorModel = self.makeErrorModel(error) { self.loadNftById(id: id) }
                self.viewController?.showError(errorModel)
                UIBlockingProgressHUD.dismiss()
            }
        }
    }
    
    private func isLiked(_ idOfCell: String) -> Bool {
        idLikes.contains(idOfCell)
    }
    
    private func isAddedToCart(_ idOfCell: String) -> Bool {
        idAddedToCart.contains(idOfCell)
    }
    
    private func checkIfNftIsFavorite(_ nftId: String) {
        guard !checkedNftIds.contains(nftId), !fetchingNftLikes.contains(nftId) else { return }
        fetchingNftLikes.insert(nftId)
        userNFTService.getProfile { [weak self] result in
            guard let self = self else { return }
            defer { self.fetchingNftLikes.remove(nftId) }
            guard !self.checkedNftIds.contains(nftId) else { return }
            self.checkedNftIds.insert(nftId)
            switch result {
            case .success(let profile):
                let isFavorite = profile.likes.contains(nftId)
                DispatchQueue.main.async {
                    self.viewController?.updateLikeButtonColor(isLiked: isFavorite, for: nftId)
                }
            case .failure(let error):
                let errorModel = self.makeErrorModel(error) { self.checkIfNftIsFavorite(nftId) }
                DispatchQueue.main.async {
                    self.viewController?.showError(errorModel)
                }
            }
        }
    }
    
    private func checkIfNftIsAddedToCart(_ nftId: String) {
        guard !checkedNft.contains(nftId), !fetchingNftCart.contains(nftId) else { return }
        fetchingNftCart.insert(nftId)
        userNFTService.getCart { [weak self] result in
            guard let self = self else { return }
            defer { self.fetchingNftCart.remove(nftId) }
            guard !self.checkedNft.contains(nftId) else { return }
            self.checkedNft.insert(nftId)
            switch result {
            case .success(let cart):
                let isAddedToCart = cart.nfts.contains(nftId)
                DispatchQueue.main.async {
                    if isAddedToCart {
                        self.viewController?.updateCartButtonImage(isAddedToCart: true, for: nftId)
                    }
                }
            case .failure(let error):
                let errorModel = self.makeErrorModel(error) { self.checkIfNftIsAddedToCart(nftId) }
                DispatchQueue.main.async {
                    self.viewController?.showError(errorModel)
                }
            }
        }
    }
    
    // MARK: - Error handling
    
    private func makeErrorModel(_ error: Error, option: (() -> Void)?) -> ErrorModel {
        let message: String
        switch error {
        case is NetworkClientError:
            message = "Произошла сетевая ошибка. Пожалуйста, попробуйте снова."
        default:
            message = "Произошла непредвиденная ошибка. Пожалуйста, попробуйте снова."
        }
        let actionText = "Повторить"
        return ErrorModel(message: message, actionText: actionText) {
            option?()
        }
    }
}
