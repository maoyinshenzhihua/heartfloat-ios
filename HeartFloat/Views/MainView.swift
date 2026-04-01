import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: HeartRateViewModel
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                titleSection

                heartRateDisplay

                statusSection

                buttonSection

                logSection

                Spacer()

                hintSection
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    private var titleSection: some View {
        Text("心率悬浮窗")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
    }

    private var heartRateDisplay: some View {
        Text(viewModel.heartRate > 0 ? "\(viewModel.heartRate) BPM" : "-- BPM")
            .font(.system(size: 56, weight: .bold))
            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
            .padding(.top, 24)
    }

    private var statusSection: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "正在连接..."
        case .connected:
            return "已连接"
        }
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        }
    }

    private var buttonSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: {
                    if viewModel.connectionState == .connected {
                        viewModel.disconnect()
                    } else {
                        viewModel.connect()
                    }
                }) {
                    HStack {
                        Image(systemName: viewModel.connectionState == .connected ? "link.badge.plus" : "antenna.radiowaves.left.and.right")
                        Text(viewModel.connectionState == .connected ? "断开连接" : (viewModel.connectionState == .connecting ? "取消连接" : "连接手环"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.connectionState == .connected ? Color.gray : Color(red: 1.0, green: 0.42, blue: 0.42))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    viewModel.togglePip()
                }) {
                    HStack {
                        Image(systemName: viewModel.isPipActive ? "pip.exit" : "pip.enter")
                        Text(viewModel.isPipActive ? "隐藏悬浮窗" : "显示悬浮窗")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isPipActive ? Color(red: 1.0, green: 0.42, blue: 0.42) : Color(red: 0.31, green: 0.80, blue: 0.77))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.connectionState != .connected)
                .opacity(viewModel.connectionState == .connected ? 1 : 0.5)
            }

            NavigationLink(destination: SettingsView()) {
                HStack {
                    Image(systemName: "gear")
                    Text("设置")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.61, green: 0.35, blue: 0.71))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(.top, 8)
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("日志终端")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(viewModel.isLogPaused ? "继续" : "暂停") {
                    viewModel.toggleLogPause()
                }
                .font(.system(size: 12))
                .foregroundColor(viewModel.isLogPaused ? .green : .orange)

                Button("复制") {
                    viewModel.copyLogs()
                }
                .font(.system(size: 12))
                .foregroundColor(.blue)

                Button("清空") {
                    viewModel.clearLogs()
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
            }

            ScrollView {
                ScrollViewReader { proxy in
                    Text(displayedLogText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white: 0.33))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("logBottom")
                        .onChange(of: viewModel.logMessages.count) { _ in
                            if !viewModel.isLogPaused {
                                withAnimation(.linear(duration: 0.15)) {
                                    proxy.scrollTo("logBottom", anchor: .bottom)
                                }
                            }
                        }
                }
            }
            .frame(height: 150)
            .background(Color(white: 0.94))
            .cornerRadius(8)
        }
        .padding(.top, 16)
    }

    private var displayedLogText: String {
        if viewModel.isLogPaused, let pausedSnapshot = viewModel.pausedLogSnapshot {
            return pausedSnapshot
        }
        let recent = viewModel.logMessages.suffix(100)
        return recent.joined(separator: "\n")
    }

    private var hintSection: some View {
        Text("提示：请先使用小米运动健康App配对手环")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(HeartRateViewModel())
            .environmentObject(SettingsManager.shared)
    }
}
