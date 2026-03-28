import Foundation
import CoreBluetooth

protocol BleServiceDelegate: AnyObject {
    func bleServiceDidUpdateHeartRate(_ heartRate: Int)
    func bleServiceDidChangeState(_ state: BleService.ConnectionState)
    func bleServiceDidLog(_ message: String)
}

class BleService: NSObject {
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    static let shared = BleService()
    
    weak var delegate: BleServiceDelegate?
    
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var currentHeartRate: Int = 0
    private var isScanning = false
    
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")
    private let clientCharacteristicConfigUUID = CBUUID(string: "2902")
    
    private let targetDeviceNames = [
        "Mi Smart Band 9 Pro",
        "Mi Smart Band 9",
        "Mi Band 9 Pro",
        "Mi Band 9",
        "Band 9 Pro",
        "Band 9",
        "Mi Smart Band",
        "Mi Band",
        "Xiaomi Smart Band"
    ]
    
    private var scanTimeoutTimer: Timer?
    private let scanTimeout: TimeInterval = 30.0
    
    private override init() {
        super.init()
    }
    
    func startService() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.heartfloat.ble"])
        }
    }
    
    func startScan() {
        guard let centralManager = centralManager else {
            startService()
            return
        }
        
        guard centralManager.state == .poweredOn else {
            log("蓝牙未开启")
            return
        }
        
        if isScanning {
            stopScan()
        }
        
        log("开始扫描BLE设备...")
        isScanning = true
        connectionState = .connecting
        delegate?.bleServiceDidChangeState(.connecting)
        
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { [weak self] _ in
            self?.handleScanTimeout()
        }
    }
    
    func stopScan() {
        isScanning = false
        centralManager?.stopScan()
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        log("停止扫描")
    }
    
    func disconnect() {
        stopScan()
        if let peripheral = peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        heartRateCharacteristic = nil
        connectionState = .disconnected
        delegate?.bleServiceDidChangeState(.disconnected)
        log("已断开连接")
    }
    
    private func handleScanTimeout() {
        if isScanning {
            stopScan()
            connectionState = .disconnected
            delegate?.bleServiceDidChangeState(.disconnected)
            log("扫描超时，未找到设备")
        }
    }
    
    private func connectToDevice(_ peripheral: CBPeripheral) {
        log("连接设备: \(peripheral.name ?? "未知")")
        self.peripheral = peripheral
        centralManager?.connect(peripheral, options: nil)
    }
    
    private func log(_ message: String) {
        delegate?.bleServiceDidLog(message)
    }
    
    private func parseHeartRateData(_ data: Data) {
        guard data.count >= 2 else { return }
        
        let flags = data[0]
        let is16Bit = (flags & 0x01) != 0
        
        let heartRate: Int
        if is16Bit && data.count >= 3 {
            heartRate = Int(data[1]) | (Int(data[2]) << 8)
        } else {
            heartRate = Int(data[1])
        }
        
        if heartRate >= 30 && heartRate <= 220 {
            currentHeartRate = heartRate
            delegate?.bleServiceDidUpdateHeartRate(heartRate)
            HttpServerManager.shared.updateHeartRate(heartRate)
            log("心率: \(heartRate) BPM")
        }
    }
}

extension BleService: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("蓝牙已开启")
        case .poweredOff:
            log("蓝牙已关闭")
            connectionState = .disconnected
            delegate?.bleServiceDidChangeState(.disconnected)
        case .unauthorized:
            log("蓝牙权限未授权")
        case .unsupported:
            log("设备不支持蓝牙")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? ""
        
        if !deviceName.isEmpty {
            log("发现设备: \(deviceName) [\(peripheral.identifier.uuidString)]")
        }
        
        if targetDeviceNames.contains(where: { deviceName.lowercased().contains($0.lowercased()) }) {
            log("找到目标设备: \(deviceName)")
            stopScan()
            connectToDevice(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("设备连接成功")
        connectionState = .connected
        delegate?.bleServiceDidChangeState(.connected)
        
        peripheral.delegate = self
        peripheral.discoverServices([heartRateServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("设备已断开连接")
        connectionState = .disconnected
        delegate?.bleServiceDidChangeState(.disconnected)
        self.peripheral = nil
        heartRateCharacteristic = nil
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("连接失败: \(error?.localizedDescription ?? "未知错误")")
        connectionState = .disconnected
        delegate?.bleServiceDidChangeState(.disconnected)
    }
}

extension BleService: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log("服务发现失败: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        log("发现 \(services.count) 个服务")
        
        for service in services {
            if service.uuid == heartRateServiceUUID {
                log("找到心率服务")
                peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            log("特征发现失败: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == heartRateMeasurementUUID {
                log("找到心率测量特征")
                heartRateCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("数据更新失败: \(error.localizedDescription)")
            return
        }
        
        if characteristic.uuid == heartRateMeasurementUUID {
            if let data = characteristic.value {
                parseHeartRateData(data)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("通知状态更新失败: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            log("心率通知已启用")
        }
    }
}
