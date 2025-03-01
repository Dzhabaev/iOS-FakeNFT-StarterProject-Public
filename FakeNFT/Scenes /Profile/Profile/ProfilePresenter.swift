//
//  ProfilePresenter.swift
//  FakeNFT
//
//  Created by Chalkov on 10.05.2024.
//

import UIKit

protocol ProfilePresenterProtocol: AnyObject {
    var view: ProfileViewControllerProtocol? { get set }
    
    var provider: ProfileProviderProtocol? { get set }

    func viewDidLoad()
    func editBarButtonTapped()
    func myNFTCellSelected()
    func favoritesNFTCellSelected()
    func aboutCellSelected()

    func fetchProfile()
    func getProfile() -> ProfileModel?
}

final class ProfilePresenter: ProfilePresenterProtocol {
    
    private var profile: ProfileModel?
    
    weak var view: ProfileViewControllerProtocol?
    var provider: ProfileProviderProtocol? 
}

//MARK: - ProfilePresenterProtocol
extension ProfilePresenter {
        
    func viewDidLoad() {
        fetchProfile()
        observe()
    }
    
    func editBarButtonTapped() {
        view?.navigateToProfileEditScreen()
    }
    
    func observe() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ProfileUpdatedNotification"),
            object: nil,
            queue: nil) { [weak self] notification in
            
            if let data = notification.userInfo as? [String: ProfileModel] {
                let profile = data["profile"]
                self?.profile = profile
                self?.view?.showProfile(profile)
            }
        }
    }
    
    func fetchProfile() {
        provider?.getProfile { [weak self] profile in
            
            guard let self else { return }
            guard let profile else { return }
            self.profile = profile
            view?.showProfile(profile)
            
            let profileItems = getProfileItems(profile)
            view?.showProfileItems(profileItems)
        }
    }
    
    func getProfileItems(_ profile: ProfileModel) -> [ProfileItem] {
        let data = [
            ProfileItem(name: "Мои NFT (\(profile.nfts.count))"),
            ProfileItem(name: "Избранные NFT (\(profile.likes.count))"),
            ProfileItem(name: "О разработчике"),
        ]
        return data
    }
    
    func getProfile() -> ProfileModel? {
       return profile
    }
    
    func myNFTCellSelected() {
        view?.navigateToMyNFTScreen()
    }
    
    func favoritesNFTCellSelected() {
        view?.navigateToFavoritesNFTScreen()
    }
    
    func aboutCellSelected() {
        view?.navigateToAboutScreen()
    }
}

// MARK: - FavoritesDelegate

extension ProfilePresenter: FavoritesDelegate {
    func didDeleteItem(at id: String) {
        guard
            let profile,
            let deletedIndex = profile.likes.firstIndex(of: id)
        else { return }
        
        var likes = profile.likes
        likes.remove(at: deletedIndex)
        
        let newProfile = ProfileModel(
            name: profile.name,
            avatar: profile.avatar,
            description: profile.description,
            website: profile.website,
            nfts: profile.nfts,
            likes: likes,
            id: profile.id
        )
        view?.showProfile(newProfile)
            
        view?.showProgressHUB()
        
        provider?.updateProfile(newProfile) { [weak self] error in
            guard let self else { return }
            view?.dismissProgressHUB()
            let profileItems = getProfileItems(newProfile)
            view?.showProfileItems(profileItems)
            
            if let error {
                print(error)
            }
        }
    }
}

