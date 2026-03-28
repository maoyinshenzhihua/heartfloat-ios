import UIKit

class SettingsViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "游戏设置"
        label.font = UIFont.boldSystemFont(ofSize: 28)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var animationSwitch = createSwitchRow(title: "动画效果", isOn: GameSettings.shared.animationEnabled)
    private lazy var musicSwitch = createSwitchRow(title: "背景音乐", isOn: GameSettings.shared.musicEnabled)
    private lazy var controllerSwitch = createSwitchRow(title: "控制器支持", isOn: GameSettings.shared.controllerEnabled)
    private lazy var gameSoundSwitch = createSwitchRow(title: "游戏音效", isOn: GameSettings.shared.gameSoundEnabled)
    private lazy var smallScreenSwitch = createSwitchRow(title: "小屏模式", isOn: GameSettings.shared.smallScreenEnabled)

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
        view.addSubview(stackView)
        view.addSubview(backButton)

        stackView.addArrangedSubview(animationSwitch)
        stackView.addArrangedSubview(musicSwitch)
        stackView.addArrangedSubview(controllerSwitch)
        stackView.addArrangedSubview(gameSoundSwitch)
        stackView.addArrangedSubview(smallScreenSwitch)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            backButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 200),
            backButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func createSwitchRow(title: String, isOn: Bool) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 2
        container.layer.borderColor = UIColor.black.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let label = UILabel()
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false

        let switchControl = UISwitch()
        switchControl.isOn = isOn
        switchControl.onTintColor = .systemBlue
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.tag = stackView.arrangedSubviews.count

        container.addSubview(label)
        container.addSubview(switchControl)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            switchControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            switchControl.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func setupActions() {
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        for (index, view) in stackView.arrangedSubviews.enumerated() {
            if let container = view as? UIView,
               let switchControl = container.subviews.compactMap({ $0 as? UISwitch }).first {
                switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
            }
        }
    }

    @objc private func backTapped() {
        SoundManager.shared.playValidClickSound()
        navigationController?.popViewController(animated: true)
    }

    @objc private func switchValueChanged(_ sender: UISwitch) {
        SoundManager.shared.playValidClickSound()

        switch sender.tag {
        case 0:
            GameSettings.shared.animationEnabled = sender.isOn
        case 1:
            GameSettings.shared.musicEnabled = sender.isOn
            if sender.isOn {
                MusicService.shared.startMusic()
            } else {
                MusicService.shared.stopMusic()
            }
        case 2:
            GameSettings.shared.controllerEnabled = sender.isOn
        case 3:
            GameSettings.shared.gameSoundEnabled = sender.isOn
            SoundManager.shared.setSoundEnabled(sender.isOn)
        case 4:
            GameSettings.shared.smallScreenEnabled = sender.isOn
        default:
            break
        }
    }
}
