import SwiftUI
import Combine


// MARK: - 2. 动效组件
struct RippleCircle: View {
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 0.8
    @StateObject private var audioManager = AudioManager.shared
    var delay: Double
    var isAnimating: Bool
    // 添加一个唯一的 ID 用于强制重置动画
    var resetID: UUID
    
    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.0)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2 + (audioManager.amplitude * 3)
            )
            .scaleEffect(isAnimating ? scale : 0.2)
            .opacity(isAnimating ? opacity : 0.0)
            .id(resetID) // 关键：ID 改变时 View 会重新创建，从而重置动画状态
            .onAppear { if isAnimating { startAnimation() } }
            .animation(.interactiveSpring(), value: audioManager.amplitude)
    }
    
    private func startAnimation() {
        // 先重置状态
        scale = 0.2
        opacity = 0.8
        withAnimation(Animation.easeOut(duration: 3.0).delay(delay).repeatForever(autoreverses: false)) {
            scale = 1.6
            opacity = 0.0
        }
    }
}


// MARK: - 主页面
struct PlayPage: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: PlaybackCategory
    @State private var innerDragOffset: CGFloat = 0
    @StateObject private var audioManager = AudioManager.shared
    @State private var showInfoOverlay: Bool = false
    
    @State private var activeOverlay: ActiveOverlay? = nil
    @State private var isInterceptOn: Bool = false // 工具栏拦截状态
    @State private var isApplyingSound: Bool = false
    @State private var showSuccessIcon: Bool = false
    
    @State private var alarmTime = Date()
    @State private var isBlockAppOn: Bool = false // 闹钟遮罩内部开关状态
    @State private var isTimerActive: Bool = false
    @State private var countdownSeconds: Int = 0
    
    @State private var mixAudioEnabled: Bool = true
    @State private var animationResetID = UUID() // 用于强制重置动效
    @State private var isExiting: Bool = false // 用于强制重置动效
    
    var initialAction: InitialAction = .none
    
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "050505").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                ZStack(alignment: .trailing) {
                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 40, height: 5).frame(maxWidth: .infinity)
                    
                    Button(action: { withAnimation(.spring()) { showInfoOverlay = true } }) {
                        Image(systemName: "info.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                    .padding(.trailing, 25)
                }.padding(.top, 12)
                
                // Title Area
                VStack(spacing: 8) {
                    Text(selectedTab == .whiteNoise ? "白噪音" : (selectedTab == .nature ? "自然之声" : "节奏"))
                        .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    Text("夜间好梦").font(.system(size: 14)).foregroundColor(.gray)
                }.padding(.top, 30)
                
                Spacer()
                
                // 中央动画 - 通过 id(animationResetID) 确保重置时续播
                ZStack {
                    if audioManager.isPlaying {
                        ForEach(0..<3) { i in
                            RippleCircle(delay: Double(i) * 1.0, isAnimating: audioManager.isPlaying, resetID: animationResetID)
                        }
                    }
                    Image(systemName: "moon.stars.fill").font(.system(size: 80)).foregroundColor(.white.opacity(0.9))
                }
                .id(animationResetID)
                .frame(width: 250, height: 250)
                
                Spacer()
                
                // 底部控制面板
                VStack(spacing: 24) {
                    HStack(spacing: 12) {
                        TabButton(title: "白噪音", isSelected: selectedTab == .whiteNoise) { withAnimation{selectedTab = .whiteNoise; audioManager.currentTab = 0} }
                        TabButton(title: "自然音", isSelected: selectedTab == .nature) { withAnimation{selectedTab = .nature; audioManager.currentTab = 1} }
                        TabButton(title: "节奏", isSelected: selectedTab == .rhythm) { withAnimation{selectedTab = .rhythm; audioManager.currentTab = 2} }
                    }.padding(.horizontal, 20)
                    
                    // 横向工具栏
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if countdownSeconds > 0 {
                                Button(action: { isTimerActive.toggle() }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isTimerActive ? "stopwatch" : "pause.fill")
                                        Text(formatTime(countdownSeconds))
                                    }
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 16).frame(height: 42)
                                    .background(Color.blue.opacity(0.6)).cornerRadius(21)
                                }.contentShape(Capsule())
                            }
                            
                            CapsuleToolButton(icon: "bubble.left", title: "反馈") { withAnimation { activeOverlay = .feedback } }
                            CapsuleToolButton(icon: "sparkles", title: "声音编辑") { withAnimation { activeOverlay = .soundEdit } }
                            CapsuleToolButton(icon: "alarm", title: "闹钟") {
                                // 打开闹钟时，让遮罩内的开关状态先同步工具栏当前的状态
                                isBlockAppOn = isInterceptOn
                                withAnimation { activeOverlay = .alarm }
                            }
                            CapsuleToolButton(icon: "hand.raised", title: "拦截", isOn: isInterceptOn) { isInterceptOn.toggle() }
                            CapsuleToolButton(icon: "waveform.path", title: "混合") { withAnimation { activeOverlay = .mix } }
                        }.padding(.horizontal, 20)
                    }
                    
                    // 主控制按钮
                    HStack(spacing: 30) {
                        // 重置图标
                        Button(action: { resetPlaybackAction() }) {
                            ControlIconGlass(icon: "arrow.clockwise")
                        }.contentShape(Circle())
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                // 调用全局音频管理器的播放/暂停逻辑
                                audioManager.togglePlayPause()
                            }
                        }) {
                            // 根据全局播放状态切换图标
                            ControlIconGlass(
                                icon: audioManager.isPlaying ? "pause.fill" : "play.fill",
                                isMain: true
                            )
                        }
                        .contentShape(Circle())
                        
                        Button(action: {
                            isBlockAppOn = isInterceptOn
                            withAnimation { activeOverlay = .alarm }
                        }) {
                            ControlIconGlass(icon: "timer")
                        }.contentShape(Circle())
                        
                        Button(action: { withAnimation { activeOverlay = .mix } }) {
                            ControlIconGlass(icon: "airplayaudio")
                        }.contentShape(Circle())
                    }.padding(.bottom, 10)
                    
                    Button(action: {}) {
                        Text("发现").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 85)
                            .background(Color(hex: "0F0F0F").opacity(0.8))
                            .clipShape(RoundedCorner(radius: 40, corners: [.topLeft, .topRight]))
                    }.contentShape(Rectangle()).padding(.bottom, -15)
                }
            }
            .blur(radius: (activeOverlay != nil || showInfoOverlay) ? 15 : 0)
            .offset(y: innerDragOffset)
            
            // --- 浮窗图层 ---
            if let overlay = activeOverlay {
                Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { withAnimation { activeOverlay = nil } }
                overlayContent(for: overlay)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
            
            if isApplyingSound { soundLoadingOverlay.zIndex(30) }
            
            if showInfoOverlay {
                InfoOverlayView(
                    onClose: { withAnimation { showInfoOverlay = false } },
                    showRoutineAction: {
                        showInfoOverlay = false
                        withAnimation { activeOverlay = .routine }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(100)
            }
        }
        .offset(y: innerDragOffset)
        .offset(y: isExiting ? -UIScreen.main.bounds.height : 0) // 执行退出时的位移
        .opacity(isExiting ? 0 : 1) // 退出时渐隐
        .gesture(
            DragGesture()
                .onChanged { v in
                    // 只允许向上滑动时产生位移反馈
                    if v.translation.height < 0 {
                        innerDragOffset = v.translation.height
                    }
                }
                .onEnded { v in
                    // 判断滑动距离是否足以触发退出 (向上划动，所以是小于 -100)
                    if v.translation.height < -100 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExiting = true // 触发自定义向上飞出的动画
                            innerDragOffset = 0
                        }
                        
                        // 等待动画结束后，静默关闭窗口（此时窗口已经在屏幕外，不会看到向下的动作）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isPresented = false
                        }
                    } else {
                        // 不足以触发退出，弹回原位
                        withAnimation(.spring()) {
                            innerDragOffset = 0
                        }
                    }
                }
        )
        .onAppear{
            if audioManager.currentTab != PlaybackCategory.whiteNoise.rawValue{
                audioManager.currentTab = PlaybackCategory.whiteNoise.rawValue
            }
            if !audioManager.isPlaying{
                audioManager.togglePlayPause()
            }
            showInfoOverlay = true
                }
    }

    @ViewBuilder
    private func overlayContent(for item: ActiveOverlay) -> some View {
        switch item {
        case .feedback: feedbackView
        case .soundEdit: soundEditView
        case .alarm: alarmFullScreenView
        case .mix: mixView
        case .routine: routineFullScreenView
        }
    }

    // --- 逻辑函数 ---
    
    private func resetPlaybackAction() {
        // 先确保处于播放状态
        audioManager.isPlaying = true
        withAnimation {
            // 1. 更新 UUID 强制 RippleCircle 重新创建并启动动画
            animationResetID = UUID()
            // 2. 隐藏工具栏计时器
            countdownSeconds = 0
            isTimerActive = false
        }
    }

    // --- 遮罩视图定义 ---
    
    private var feedbackView: some View {
        VStack(spacing: 20) {
            Text("声音反馈").font(.headline).foregroundColor(.white).padding(.top, 25)
            HStack(spacing: 30) {
                SquareIconButton(icon: "face.smiling")
                SquareIconButton(icon: "face.dashed")
            }
            Spacer()
            Button(action: { withAnimation { activeOverlay = nil } }) {
                Text("取消")
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.gray.opacity(0.3)).foregroundColor(.white).cornerRadius(25)
            }
            .contentShape(Rectangle())
            .padding(.bottom, 35)
        }
        .padding(.horizontal, 25).frame(height: 300).background(Color.black).clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
    }

    private var soundEditView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("声音编辑").font(.title3.bold()).foregroundColor(.white)
            TextField("", text: .constant(""), prompt: Text("描述你想听到的声音...").foregroundColor(.gray))
                .padding().background(Color.white.opacity(0.1)).cornerRadius(12).foregroundColor(.white)
            
            Button(action: { startApplySoundAnimation() }) {
                Text("应用").font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 50).background(Color.white).cornerRadius(12)
            }
            .contentShape(Rectangle())
            
            Button(action: { withAnimation { activeOverlay = nil } }) {
                Text("取消")
                    .frame(maxWidth: .infinity).frame(height: 50).background(Color.gray.opacity(0.3)).foregroundColor(.white).cornerRadius(12)
            }
            .contentShape(Rectangle())
        }
        .padding(25).frame(height: 400).background(Color.black).clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
    }

    private var alarmFullScreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text("智能闹钟").font(.title.bold()).foregroundColor(.white)
                DatePicker("", selection: $alarmTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().colorInvert().colorMultiply(.white).frame(maxWidth: .infinity)
                Text("预计睡眠时间：\(calculateSleepTime())").font(.caption).foregroundColor(.gray)
                
                // 内部开关
                Toggle("拦截干扰应用", isOn: $isBlockAppOn)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                
                Spacer()
                HStack(spacing: 15) {
                    Button(action: { withAnimation { activeOverlay = nil } }) {
                        Text("取消").frame(maxWidth: .infinity).frame(height: 55).background(Color.gray.opacity(0.3)).cornerRadius(15).foregroundColor(.white)
                    }.contentShape(Rectangle())
                    
                    Button(action: {
                        // 【功能修复】：将遮罩内部的选中状态同步给工具栏
                        // 如果 isBlockAppOn 为 false，isInterceptOn 也会变为 false（熄灭）
                        isInterceptOn = isBlockAppOn
                        
                        startCountdown()
                        withAnimation { activeOverlay = nil }
                    }) {
                        Text("确认").frame(maxWidth: .infinity).frame(height: 55).background(Color.white).cornerRadius(15).foregroundColor(.black)
                    }.contentShape(Rectangle())
                }
            }.padding(25)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { withAnimation { activeOverlay = nil } }) {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            .padding(12).background(Color.white.opacity(0.1)).clipShape(Circle())
                    }.padding(25)
                }
                Spacer()
            }
        }
    }

    private var mixView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("AirPlay").font(.headline)
                Spacer()
                Image(systemName: "airplayaudio")
            }.foregroundColor(.white)
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("播放").font(.system(size: 14)).foregroundColor(.gray)
                    Text("混合音频").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                }
                Spacer()
                Toggle("", isOn: $mixAudioEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding(.top, 5)
            
            Text("混合音频开启时，背景声音将持续播放").font(.caption).foregroundColor(.gray)
            
            Button(action: { withAnimation { activeOverlay = nil } }) {
                Text("完成")
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.gray.opacity(0.3)).foregroundColor(.white).cornerRadius(25)
            }
            .contentShape(Rectangle())
            .padding(.top, 10)
        }
        .padding(25).frame(height: 350).background(Color.black).clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
    }
    
    private var routineFullScreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer().frame(height: 60)
                Image(systemName: "bell.badge.fill").font(.system(size: 40)).foregroundColor(.white)
                Text("例行活动").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                Text("选择您想开始会话的时间。").font(.system(size: 16)).foregroundColor(.gray)
                
                DatePicker("", selection: $alarmTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().colorInvert().colorMultiply(.white).frame(maxWidth: .infinity)
                
                HStack(spacing: 8) {
                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                        DaySelectionButton(title: day)
                    }
                }.padding(.top, 10)
                
                Text("选择此例行活动的星期几").font(.system(size: 14)).foregroundColor(.gray)
                Spacer()
                
                Button(action: { withAnimation { activeOverlay = nil } }) {
                    Text("创建例行活动").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 1))
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 25).padding(.bottom, 40)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { withAnimation { activeOverlay = nil } }) {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            .padding(12).background(Color.white.opacity(0.1)).clipShape(Circle())
                    }.padding(25)
                }
                Spacer()
            }
        }
    }

    private func startApplySoundAnimation() {
        activeOverlay = nil
        withAnimation { isApplyingSound = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSuccessIcon = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { isApplyingSound = false; showSuccessIcon = false }
            }
        }
    }
    
    private var soundLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 20) {
                if showSuccessIcon { Image(systemName: "checkmark").font(.system(size: 40, weight: .bold)).foregroundColor(.white) }
                else { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(2) }
            }
            .frame(width: 150, height: 150)
            .glassStyle(opacity: 0.2, cornerRadius: 24)
        }
    }

    private func calculateSleepTime() -> String {
        let diff = alarmTime.timeIntervalSinceNow
        let s = Int(diff > 0 ? diff : diff + 86400)
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
    
    private func startCountdown() {
        let diff = alarmTime.timeIntervalSinceNow
        countdownSeconds = Int(diff > 0 ? diff : diff + 86400)
        isTimerActive = true
    }
    
    private func updateCountdown() {
        if isTimerActive && countdownSeconds > 0 {
            countdownSeconds -= 1
            if countdownSeconds == 0 { audioManager.isPlaying = false; isTimerActive = false }
        }
    }
    
    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

// MARK: - 4. 信息详情页
struct InfoOverlayView: View {
    var onClose: () -> Void
    var showRoutineAction: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("白噪音").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                        Text("夜间好梦").font(.system(size: 16)).foregroundColor(.gray)
                    }.padding(.top, 60)
                    
                    Image(systemName: "waveform") // 替换为 white_icon
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180).foregroundColor(.white).padding(.vertical, 40)
                    
                    Text("利用声音的力量改善睡眠").font(.system(size: 18)).foregroundColor(.white).padding(.bottom, 30)
                    
                    VStack(alignment: .leading, spacing: 25) {
                        Divider().background(Color.gray.opacity(0.3))
                        Text("白噪音").font(.system(size: 14)).foregroundColor(.gray)
                        Text("白噪音通过覆盖环境中的突发噪音，营造平稳和谐的听觉背景。")
                            .font(.system(size: 22, weight: .medium)).foregroundColor(.white).lineSpacing(8)
                        
                        Divider().background(Color.gray.opacity(0.3))
                        Text("工作原理").font(.system(size: 14)).foregroundColor(.gray)
                        Text("AI生成的白噪音利用精密算法模拟自然界声学特征...")
                            .font(.system(size: 18)).foregroundColor(.gray).lineSpacing(6)
                    }.padding(.horizontal, 30)
                    
                    Spacer(minLength: 220)
                }
            }
            .mask(LinearGradient(gradient: Gradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1), .init(color: .black, location: 0.85), .init(color: .clear, location: 1)]), startPoint: .top, endPoint: .bottom))
            
            VStack(spacing: 15) {
                Button(action: onClose) {
                    Text("开始").font(.system(size: 18, weight: .bold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 56).background(Color.white).cornerRadius(16)
                }.contentShape(Rectangle())
                
                Button(action: showRoutineAction) {
                    Text("创建例行活动").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 56).background(Color.gray.opacity(0.3)).cornerRadius(16)
                }.contentShape(Rectangle())
            }.padding(.horizontal, 25).padding(.bottom, 40).background(Color.black)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            .padding(12).background(Color.white.opacity(0.1)).clipShape(Circle())
                    }.padding([.trailing, .top], 25)
                }
                Spacer()
            }
        }
    }
}

