import UIKit

class MainMenuViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "俄罗斯粑粑块"
        label.font = UIFont.boldSystemFont(ofSize: 48)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let startGameBtn = UIButton(type: .system)
    private let gameRecordBtn = UIButton(type: .system)
    private let gameSettingsBtn = UIButton(type: .system)
    private let aboutBtn = UIButton(type: .system)

    private let copyrightLabel: UILabel = {
        let label = UILabel()
        label.text = "© 2026 俄罗斯粑粑块"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .black
        label.textAlignment = .center
        label.alpha = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()

        SoundManager.shared.initSoundManager(soundEnabled: GameSettings.shared.gameSoundEnabled)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)

        if GameSettings.shared.musicEnabled {
            MusicService.shared.startMusic()
        }

        if GameSettings.shared.animationEnabled {
            applyPresentAnimation()
        }
    }

    private func setupUI() {
        view.backgroundColor = UIColor(hex: "#FFD959")

        view.addSubview(titleLabel)
        view.addSubview(stackView)
        view.addSubview(copyrightLabel)

        setupMenuButton(startGameBtn, title: "开始游戏")
        setupMenuButton(gameRecordBtn, title: "游戏记录")
        setupMenuButton(gameSettingsBtn, title: "游戏设置")
        setupMenuButton(aboutBtn, title: "应用关于")

        stackView.addArrangedSubview(startGameBtn)
        stackView.addArrangedSubview(gameRecordBtn)
        stackView.addArrangedSubview(gameSettingsBtn)
        stackView.addArrangedSubview(aboutBtn)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 60),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            copyrightLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            copyrightLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupMenuButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 22)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.black.cgColor
        button.heightAnchor.constraint(equalToConstant: 65).isActive = true
    }

    private func setupActions() {
        startGameBtn.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)
        gameRecordBtn.addTarget(self, action: #selector(gameRecordTapped), for: .touchUpInside)
        gameSettingsBtn.addTarget(self, action: #selector(gameSettingsTapped), for: .touchUpInside)
        aboutBtn.addTarget(self, action: #selector(aboutTapped), for: .touchUpInside)

        startGameBtn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        gameRecordBtn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        gameSettingsBtn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        aboutBtn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)

        startGameBtn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        gameRecordBtn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        gameSettingsBtn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        aboutBtn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func startGameTapped() {
        SoundManager.shared.playValidClickSound()
        MusicService.shared.stopMusic()
        let gameVC = GameViewController()
        gameVC.modalPresentationStyle = .fullScreen

        if GameSettings.shared.animationEnabled {
            TransitionHelper.shared.applyFadeTransition(to: gameVC, presenting: true)
            present(gameVC, animated: false)
        } else {
            present(gameVC, animated: true)
        }
    }

    @objc private func gameRecordTapped() {
        SoundManager.shared.playValidClickSound()
        let recordVC = GameRecordViewController()

        if GameSettings.shared.animationEnabled {
            let transition = TransitionHelper.shared.createFadeTransition(isPresenting: true)
            navigationController?.view.layer.add(transition, forKey: "fadeTransition")
        }
        navigationController?.pushViewController(recordVC, animated: false)
    }

    @objc private func gameSettingsTapped() {
        SoundManager.shared.playValidClickSound()
        let settingsVC = SettingsViewController()

        if GameSettings.shared.animationEnabled {
            let transition = TransitionHelper.shared.createFadeTransition(isPresenting: true)
            navigationController?.view.layer.add(transition, forKey: "fadeTransition")
        }
        navigationController?.pushViewController(settingsVC, animated: false)
    }

    @objc private func aboutTapped() {
        SoundManager.shared.playValidClickSound()
        let aboutVC = AboutViewController()

        if GameSettings.shared.animationEnabled {
            let transition = TransitionHelper.shared.createFadeTransition(isPresenting: true)
            navigationController?.view.layer.add(transition, forKey: "fadeTransition")
        }
        navigationController?.pushViewController(aboutVC, animated: false)
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
