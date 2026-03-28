import UIKit

class SettingsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private let numberSizeSlider = UISlider()
    private let numberSizeLabel = UILabel()
    private let numberColorButton = UIButton(type: .system)
    
    private let labelSizeSlider = UISlider()
    private let labelSizeLabel = UILabel()
    private let labelColorButton = UIButton(type: .system)
    
    private let opacitySlider = UISlider()
    private let opacityLabel = UILabel()
    
    private let httpSwitch = UISwitch()
    private let portTextField = UITextField()
    private let applyPortButton = UIButton(type: .system)
    private let localIpLabel = UILabel()
    private let apiEndpointsLabel = UILabel()
    
    private let resetButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
        SettingsManager.shared.addListener(self)
    }
    
    deinit {
        SettingsManager.shared.removeListener(self)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "设置"
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        setupDisplaySection()
        setupHttpSection()
        setupResetSection()
    }
    
    private func setupDisplaySection() {
        let sectionView = createSectionView(title: "显示设置")
        
        let numberSizeRow = createSliderRow(
            title: "数字大小",
            min: 12,
            max: 48,
            slider: numberSizeSlider,
            label: numberSizeLabel
        )
        numberSizeSlider.addTarget(self, action: #selector(numberSizeChanged), for: .valueChanged)
        sectionView.addArrangedSubview(numberSizeRow)
        
        let numberColorRow = createColorRow(title: "数字颜色", button: numberColorButton)
        numberColorButton.addTarget(self, action: #selector(numberColorTapped), for: .touchUpInside)
        sectionView.addArrangedSubview(numberColorRow)
        
        let labelSizeRow = createSliderRow(
            title: "标签大小",
            min: 8,
            max: 32,
            slider: labelSizeSlider,
            label: labelSizeLabel
        )
        labelSizeSlider.addTarget(self, action: #selector(labelSizeChanged), for: .valueChanged)
        sectionView.addArrangedSubview(labelSizeRow)
        
        let labelColorRow = createColorRow(title: "标签颜色", button: labelColorButton)
        labelColorButton.addTarget(self, action: #selector(labelColorTapped), for: .touchUpInside)
        sectionView.addArrangedSubview(labelColorRow)
        
        let opacityRow = createSliderRow(
            title: "背景透明度",
            min: 0,
            max: 100,
            slider: opacitySlider,
            label: opacityLabel
        )
        opacitySlider.addTarget(self, action: #selector(opacityChanged), for: .valueChanged)
        sectionView.addArrangedSubview(opacityRow)
        
        stackView.addArrangedSubview(sectionView)
    }
    
    private func setupHttpSection() {
        let sectionView = createSectionView(title: "HTTP 服务器")
        
        let httpRow = createSwitchRow(title: "启用 HTTP 推送", switch: httpSwitch)
        httpSwitch.addTarget(self, action: #selector(httpSwitchChanged), for: .valueChanged)
        sectionView.addArrangedSubview(httpRow)
        
        let portRow = UIStackView()
        portRow.axis = .horizontal
        portRow.spacing = 12
        portRow.alignment = .center
        
        let portLabel = UILabel()
        portLabel.text = "端口:"
        portLabel.font = .systemFont(ofSize: 16)
        portRow.addArrangedSubview(portLabel)
        
        portTextField.keyboardType = .numberPad
        portTextField.borderStyle = .roundedRect
        portTextField.textAlignment = .center
        portTextField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        portRow.addArrangedSubview(portTextField)
        
        applyPortButton.setTitle("应用", for: .normal)
        applyPortButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        applyPortButton.backgroundColor = .systemBlue
        applyPortButton.setTitleColor(.white, for: .normal)
        applyPortButton.layer.cornerRadius = 8
        applyPortButton.addTarget(self, action: #selector(applyPortTapped), for: .touchUpInside)
        applyPortButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
        applyPortButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        portRow.addArrangedSubview(applyPortButton)
        
        sectionView.addArrangedSubview(portRow)
        
        localIpLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        localIpLabel.textColor = .secondaryLabel
        localIpLabel.numberOfLines = 0
        sectionView.addArrangedSubview(localIpLabel)
        
        apiEndpointsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        apiEndpointsLabel.textColor = .tertiaryLabel
        apiEndpointsLabel.numberOfLines = 0
        sectionView.addArrangedSubview(apiEndpointsLabel)
        
        stackView.addArrangedSubview(sectionView)
    }
    
    private func setupResetSection() {
        let sectionView = createSectionView(title: "重置")
        
        resetButton.setTitle("恢复默认设置", for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        resetButton.backgroundColor = .systemRed
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.layer.cornerRadius = 12
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        resetButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        sectionView.addArrangedSubview(resetButton)
        
        stackView.addArrangedSubview(sectionView)
    }
    
    private func createSectionView(title: String) -> UIStackView {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 16
        section.backgroundColor = .secondarySystemBackground
        section.layer.cornerRadius = 12
        section.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        section.isLayoutMarginsRelativeArrangement = true
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        section.addArrangedSubview(titleLabel)
        
        return section
    }
    
    private func createSliderRow(title: String, min: Float, max: Float, slider: UISlider, label: UILabel) -> UIStackView {
        let row = UIStackView()
        row.axis = .vertical
        row.spacing = 8
        
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.distribution = .equalSpacing
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        headerRow.addArrangedSubview(titleLabel)
        
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        headerRow.addArrangedSubview(label)
        
        row.addArrangedSubview(headerRow)
        
        slider.minimumValue = min
        slider.maximumValue = max
        row.addArrangedSubview(slider)
        
        return row
    }
    
    private func createColorRow(title: String, button: UIButton) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        row.addArrangedSubview(titleLabel)
        
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.separator.cgColor
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        row.addArrangedSubview(button)
        
        row.addArrangedSubview(UIView())
        
        return row
    }
    
    private func createSwitchRow(title: String, switch: UISwitch) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)
        row.addArrangedSubview(titleLabel)
        
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(`switch`)
        
        return row
    }
    
    private func loadSettings() {
        numberSizeSlider.value = Float(SettingsManager.shared.bpmNumberSize)
        numberSizeLabel.text = "\(SettingsManager.shared.bpmNumberSize)sp"
        numberColorButton.backgroundColor = SettingsManager.shared.bpmNumberColor
        
        labelSizeSlider.value = Float(SettingsManager.shared.bpmLabelSize)
        labelSizeLabel.text = "\(SettingsManager.shared.bpmLabelSize)sp"
        labelColorButton.backgroundColor = SettingsManager.shared.bpmLabelColor
        
        opacitySlider.value = Float(SettingsManager.shared.backgroundOpacity)
        opacityLabel.text = "\(SettingsManager.shared.backgroundOpacity)%"
        
        httpSwitch.isOn = SettingsManager.shared.isHttpPushEnabled
        portTextField.text = "\(SettingsManager.shared.httpPushPort)"
        
        updateHttpInfo()
    }
    
    private func updateHttpInfo() {
        if let ip = HttpServerManager.shared.getLocalIPAddress() {
            localIpLabel.text = "http://\(ip):\(SettingsManager.shared.httpPushPort)"
            apiEndpointsLabel.text = """
            GET /heartbeat - 获取心率值
            GET /heartbeat.json - JSON格式
            GET /live - 直播页面
            """
        } else {
            localIpLabel.text = "无网络连接"
            apiEndpointsLabel.text = ""
        }
    }
    
    @objc private func numberSizeChanged() {
        let value = Int(numberSizeSlider.value)
        SettingsManager.shared.bpmNumberSize = value
        numberSizeLabel.text = "\(value)sp"
    }
    
    @objc private func labelSizeChanged() {
        let value = Int(labelSizeSlider.value)
        SettingsManager.shared.bpmLabelSize = value
        labelSizeLabel.text = "\(value)sp"
    }
    
    @objc private func opacityChanged() {
        let value = Int(opacitySlider.value)
        SettingsManager.shared.backgroundOpacity = value
        opacityLabel.text = "\(value)%"
    }
    
    @objc private func numberColorTapped() {
        showColorPicker(initialColor: SettingsManager.shared.bpmNumberColor) { color in
            SettingsManager.shared.bpmNumberColor = color
            self.numberColorButton.backgroundColor = color
        }
    }
    
    @objc private func labelColorTapped() {
        showColorPicker(initialColor: SettingsManager.shared.bpmLabelColor) { color in
            SettingsManager.shared.bpmLabelColor = color
            self.labelColorButton.backgroundColor = color
        }
    }
    
    @objc private func httpSwitchChanged() {
        SettingsManager.shared.isHttpPushEnabled = httpSwitch.isOn
        
        if httpSwitch.isOn {
            HttpServerManager.shared.startServer(port: SettingsManager.shared.httpPushPort)
        } else {
            HttpServerManager.shared.stopServer()
        }
        
        updateHttpInfo()
    }
    
    @objc private func applyPortTapped() {
        guard let portText = portTextField.text,
              let port = Int(portText),
              port >= 1024 && port <= 65535 else {
            showAlert(title: "端口无效", message: "端口必须在 1024 到 65535 之间")
            return
        }
        
        SettingsManager.shared.httpPushPort = port
        
        if SettingsManager.shared.isHttpPushEnabled {
            HttpServerManager.shared.stopServer()
            HttpServerManager.shared.startServer(port: port)
        }
        
        updateHttpInfo()
        showAlert(title: "成功", message: "端口已更新为 \(port)")
    }
    
    @objc private func resetTapped() {
        let alert = UIAlertController(title: "重置设置", message: "确定要恢复默认设置吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { _ in
            SettingsManager.shared.resetToDefaults()
            self.loadSettings()
        })
        present(alert, animated: true)
    }
    
    private func showColorPicker(initialColor: UIColor, completion: @escaping (UIColor) -> Void) {
        let colorPicker = UIColorPickerViewController()
        colorPicker.selectedColor = initialColor
        colorPicker.delegate = ColorPickerDelegate(completion: completion)
        present(colorPicker, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

extension SettingsViewController: SettingsChangeListener {
    func onSettingsChanged() {
        loadSettings()
    }
}

class ColorPickerDelegate: NSObject, UIColorPickerViewControllerDelegate {
    private let completion: (UIColor) -> Void
    
    init(completion: @escaping (UIColor) -> Void) {
        self.completion = completion
    }
    
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        completion(viewController.selectedColor)
    }
    
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        completion(color)
    }
}
