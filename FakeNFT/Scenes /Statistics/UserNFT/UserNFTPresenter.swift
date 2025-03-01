//
//  UserNFTPresenter.swift
//  FakeNFT
//
//  Created by Сергей on 16.05.2024.
//

import Foundation

protocol UserNFTPresenterProtocol: AnyObject {
    var view: UserNFTCollectionViewProtocol? { get set }
    var nftsIDs: [String] { get set }
    var visibleNFT: [Nft] { get set }
    var profile: ProfileModel? { get set }
    var cart: Cart? { get set }
    var nft: Nft? { get set }
    func viewDidLoad()
    func getNFT()
    func changeLike(nft: Nft, completion: @escaping (Result<Bool, Error>) -> Void)
    func changeCart(nft: Nft, completion: @escaping (Result<Bool, Error>) -> Void)
}

final class UserNFTPresenter: UserNFTPresenterProtocol {

    var nftsIDs: [String] = []
    var visibleNFT: [Nft] = []
    var profile: ProfileModel?
    var cart: Cart?
    var nft: Nft?

    weak var view: UserNFTCollectionViewProtocol?

    private let service = UserNFTService.shared

    func viewDidLoad() {
        getNFT()
        getCart()
    }

    func getProfile(completion: @escaping () -> Void) {
        service.getProfile { result in
            switch result {
            case .success(let object):
                self.profile = object
                completion()
            case .failure(let error):
                print(error)
            }
        }
    }

    func getCart() {
        service.getCart { result in
            switch result {
            case .success(let order):
                self.cart = order
            case .failure(let error):
                print(error)
            }
        }
    }

    func getNFT() {
        UIBlockingProgressHUD.show()
        self.service.visibleNFT = []
        self.service.nftsIDs = self.nftsIDs
        service.getNFT {
            self.getProfile {
                self.visibleNFT = self.service.visibleNFT
                self.view?.reload()
                self.view?.updateEmptyView()
                UIBlockingProgressHUD.dismiss()
            }
        }
    }

    func changeLike(nft: Nft, completion: @escaping (Result<Bool, Error>) -> Void) {
        UIBlockingProgressHUD.show()
        service.getProfile { result in
            switch result {
            case .success(let model):
                var likes = model.likes
                let id = nft.id
                var isLiked = false
                if likes.contains(id) {
                    likes.removeAll { $0 == id }
                    isLiked = false
                } else {
                    likes.append(id)
                    isLiked = true
                }

                self.service.changeLike(newLikes: likes, profile: model) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self?.getProfile() {}
                            completion(.success(isLiked))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                print(error)
            }
        }
    }

    func changeCart(nft: Nft, completion: @escaping (Result<Bool, Error>) -> Void) {
        UIBlockingProgressHUD.show()
        service.getCart { result in
            switch result {
            case .success(let model):
                var cart = model.nfts
                let id = nft.id
                var isAdded = false
                if cart.contains(id) {
                    cart.removeAll { $0 == id }
                    isAdded = false
                } else {
                    cart.append(id)
                    isAdded = true
                }

                self.service.changeCart(newCart: cart, cart: model) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self?.getCart()
                            NotificationCenter.default.post(name: NSNotification.Name("CartUpdated"), object: nil, userInfo: [:])
                            completion(.success(isAdded))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                print(error)
            }
        }
    }
}
