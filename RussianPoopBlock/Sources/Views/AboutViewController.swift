import UIKit
import WebKit

class AboutViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "关于"
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let developerLabel: UILabel = {
        let label = UILabel()
        label.text = "开发者：小花爱瞎剪"
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let purposeTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "制作初衷"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let purposeTextLabel: UILabel = {
        let label = UILabel()
        label.text = "灵感来源于 S-Venti 制作的《俄罗斯粑粑块》鬼畜视频，特此将其改编为iOS应用，供大家娱乐体验"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var videoLinkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("观看原视频 (B站)", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.black.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("返回", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.black.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let videoUrl = "https://www.bilibili.com/video/BV1maVTzDEYr"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)

        if GameSettings.shared.musicEnabled {
            MusicService.shared.resumeMusic()
        }
    }

    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#FFD959")

        view.addSubview(titleLabel)
        view.addSubview(developerLabel)
        view.addSubview(purposeTitleLabel)
        view.addSubview(purposeTextLabel)
        view.addSubview(videoLinkButton)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            developerLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            developerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            purposeTitleLabel.topAnchor.constraint(equalTo: developerLabel.bottomAnchor, constant: 40),
            purposeTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            purposeTextLabel.topAnchor.constraint(equalTo: purposeTitleLabel.bottomAnchor, constant: 15),
            purposeTextLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            purposeTextLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            videoLinkButton.topAnchor.constraint(equalTo: purposeTextLabel.bottomAnchor, constant: 40),
            videoLinkButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            videoLinkButton.widthAnchor.constraint(equalToConstant: 250),
            videoLinkButton.heightAnchor.constraint(equalToConstant: 50),

            backButton.topAnchor.constraint(equalTo: videoLinkButton.bottomAnchor, constant: 30),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 200),
            backButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupActions() {
        videoLinkButton.addTarget(self, action: #selector(videoLinkTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        videoLinkButton.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        videoLinkButton.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        backButton.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        backButton.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func videoLinkTapped() {
        SoundManager.shared.playValidClickSound()
        if let url = URL(string: videoUrl) {
            UIApplication.shared.open(url)
        }
    }

    @objc private func backTapped() {
        SoundManager.shared.playValidClickSound()
        navigationController?.popViewController(animated: true)
    }

    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.layer.borderColor = UIColor.systemBlue.cgColor
            sender.layer.borderWidth = 3
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.layer.borderColor = UIColor.black.cgColor
            sender.layer.borderWidth = 2
        }
    }
}
