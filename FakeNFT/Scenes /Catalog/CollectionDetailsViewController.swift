//
//  CollectionDetailsViewController.swift
//  FakeNFT
//
//  Created by Chingiz on 25.04.2024.
//

import UIKit

// MARK: - CollectionDetailsViewController

final class CollectionDetailsViewController: UIViewController, ErrorView {
    
    var collection: CatalogModel? {
        didSet {
            if let collection = collection {
                configure(with: collection,
                          imageLoader: CatalogProviderImpl(networkClient: DefaultNetworkClient())
                )
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let presenter: CollectionDetailsViewControllerPresenter
    private var nfts: [Nft] = []
    private var nftCollectionViewHeightConstraint: NSLayoutConstraint?
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        return scrollView
    }()
    
    private lazy var containerView = UIView()
    
    private lazy var coverCollectionImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.layer.masksToBounds = true
        image.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        image.layer.cornerRadius = 12
        image.image = defaultImage
        return image
    }()
    
    private lazy var defaultImage: UIImage? = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        gradientLayer.colors = [
            UIColor(hexString: "#AEAFB4").withAlphaComponent(1.0).cgColor,
            UIColor(hexString: "#AEAFB4").withAlphaComponent(0.3).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        UIGraphicsBeginImageContextWithOptions(gradientLayer.bounds.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        gradientLayer.render(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton()
        if let image = UIImage(systemName: "chevron.backward") {
            let tintedImage = image.withRenderingMode(.alwaysTemplate)
            button.setImage(tintedImage, for: .normal)
            button.tintColor = .closeButton
        }
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var collectionTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .segmentActive
        label.font = .headline3
        return label
    }()
    
    private lazy var authorCollectionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .segmentActive
        label.font = .caption2
        label.text = NSLocalizedString("authorCollectionLabel.text", comment: "")
        return label
    }()
    
    private lazy var authorLinkLabel: UILabel = {
        let label = UILabel()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(authorLinkTapped))
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textColor = .hyperlinkText
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tapGesture)
        return label
    }()
    
    private lazy var descriptionCollectionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = .segmentActive
        label.font = .caption2
        return label
    }()
    
    private lazy var nftCollectionView: UICollectionView = {
        let nftCollection = UICollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        nftCollection.isScrollEnabled = false
        nftCollection.dataSource = self
        nftCollection.delegate = self
        nftCollection.backgroundColor = .backgroundColorActive
        nftCollection.register(
            CollectionDetailsNftCardCell.self,
            forCellWithReuseIdentifier: CollectionDetailsNftCardCell.reuseIdentifier
        )
        return nftCollection
    }()
    
    // MARK: - Initializers
    
    init(presenter: CollectionDetailsViewControllerPresenter) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UIViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewDidLoad()
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func authorLinkTapped() {
        let webViewController = AuthorWebViewController(urlString: presenter.authorURLString)
        webViewController.modalPresentationStyle = .fullScreen
        present(webViewController, animated: true, completion: nil)
    }
    
    // MARK: - Public Methods
    
    func reloadCollectionView() {
        nftCollectionView.reloadData()
    }
    
    func updateLikeButtonColor(isLiked: Bool, for itemId: String) {
        guard let indexPath = indexPath(for: itemId) else { return }
        if let cell = nftCollectionView.cellForItem(at: indexPath) as? CollectionDetailsNftCardCell {
            cell.setLikeButtonState(isLiked: isLiked)
        }
    }
    
    func updateCartButtonImage(isAddedToCart: Bool, for itemId: String) {
        guard let indexPath = indexPath(for: itemId) else { return }
        if let cell = nftCollectionView.cellForItem(at: indexPath) as? CollectionDetailsNftCardCell {
            cell.setCartButtonState(isAdded: isAddedToCart)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupViewDidLoad() {
        setupLayout()
        presenter.viewController = self
        presenter.setOnLoadCompletion { [weak self] nfts in
            self?.nfts = nfts
            self?.reloadCollectionView()
            self?.updateCollectionViewHeight()
        }
        presenter.processNFTsLoading()
    }
    
    private func updateCollectionViewHeight() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nftCollectionView.layoutIfNeeded()
            self.nftCollectionViewHeightConstraint?.constant = self.nftCollectionView.contentSize.height
        }
    }
    
    private func setupLayout() {
        
        view.backgroundColor = .backgroundColorActive
        nftCollectionViewHeightConstraint = nftCollectionView.heightAnchor.constraint(equalToConstant: 0)
        nftCollectionViewHeightConstraint?.isActive = true
        
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        [
            coverCollectionImage,
            collectionTitleLabel,
            authorCollectionLabel,
            authorLinkLabel,
            descriptionCollectionLabel,
            nftCollectionView,
            backButton,
            loadingIndicator
        ].forEach {
            containerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            coverCollectionImage.topAnchor.constraint(equalTo: containerView.topAnchor),
            coverCollectionImage.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            coverCollectionImage.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            coverCollectionImage.heightAnchor.constraint(equalToConstant: 310),
            
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 9),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 9),
            backButton.heightAnchor.constraint(equalToConstant: 24),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            collectionTitleLabel.topAnchor.constraint(equalTo: coverCollectionImage.bottomAnchor, constant: 16),
            collectionTitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            collectionTitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            authorCollectionLabel.topAnchor.constraint(equalTo: collectionTitleLabel.bottomAnchor, constant: 13),
            authorCollectionLabel.leadingAnchor.constraint(equalTo: collectionTitleLabel.leadingAnchor),
            
            authorLinkLabel.leadingAnchor.constraint(equalTo: authorCollectionLabel.trailingAnchor, constant: 4),
            authorLinkLabel.bottomAnchor.constraint(equalTo: authorCollectionLabel.bottomAnchor),
            
            descriptionCollectionLabel.topAnchor.constraint(equalTo: authorCollectionLabel.bottomAnchor, constant: 5),
            descriptionCollectionLabel.leadingAnchor.constraint(equalTo: collectionTitleLabel.leadingAnchor),
            descriptionCollectionLabel.trailingAnchor.constraint(equalTo: collectionTitleLabel.trailingAnchor),
            
            nftCollectionView.topAnchor.constraint(equalTo: descriptionCollectionLabel.bottomAnchor, constant: 24),
            nftCollectionView.leadingAnchor.constraint(equalTo: collectionTitleLabel.leadingAnchor),
            nftCollectionView.trailingAnchor.constraint(equalTo: collectionTitleLabel.trailingAnchor),
            nftCollectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func configure(with catalog: CatalogModel, imageLoader: ImageLoader) {
        loadingIndicator.startAnimating()
        if let url = URL(string: catalog.cover) {
            imageLoader.loadImage(from: url) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingIndicator.stopAnimating()
                    self.coverCollectionImage.image = image ?? self.defaultImage
                }
            }
        } else {
            loadingIndicator.stopAnimating()
            coverCollectionImage.image = defaultImage
        }
        collectionTitleLabel.text = catalog.name
        authorLinkLabel.text = catalog.author
        descriptionCollectionLabel.text = catalog.description
        nftCollectionView.reloadData()
    }
    
    private func indexPath(for itemId: String) -> IndexPath? {
        for (index, nft) in nfts.enumerated() {
            if nft.id == itemId {
                return IndexPath(row: index, section: 0)
            }
        }
        return nil
    }
}

// MARK: - UICollectionViewDataSource

extension CollectionDetailsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return nfts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CollectionDetailsNftCardCell.reuseIdentifier, for: indexPath) as? CollectionDetailsNftCardCell else {
            return UICollectionViewCell()
        }
        let nft = presenter.returnCollectionCell(for: indexPath.row)
        let nftx = nfts[indexPath.row]
        cell.nft = nftx
        cell.configure(data: nft)
        cell.delegate = self
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CollectionDetailsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let interItemSpacing: CGFloat = 10
        let width = (collectionView.bounds.width - 2 * interItemSpacing) / 3
        return CGSize(width: width, height: 202)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }
}

// MARK: - UIScrollViewDelegate

extension CollectionDetailsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < 0 {
            scrollView.contentOffset.y = 0
        }
    }
}

// MARK: - CollectionDetailsNftCardCellDelegate

extension CollectionDetailsViewController: CollectionDetailsNftCardCellDelegate {
    func likeButtonTapped(cell: CollectionDetailsNftCardCell, for itemId: String) {
        presenter.changeLike(nftID: itemId) { result in
            switch result {
            case .success(let isAdded):
                cell.setLikeButtonState(isLiked: isAdded)
                UIBlockingProgressHUD.dismiss()
            case .failure(let error):
                print(error)
                UIBlockingProgressHUD.dismiss()
            }
        }
    }
    
    func cartButtonTapped(cell: CollectionDetailsNftCardCell ,for itemId: String) {
        presenter.changeCart(nftID: itemId) { result in
            switch result {
            case .success(let isAdded):
                cell.setCartButtonState(isAdded: isAdded)
                UIBlockingProgressHUD.dismiss()
            case .failure(let error):
                print(error)
                UIBlockingProgressHUD.dismiss()
            }
        }
    }
}
