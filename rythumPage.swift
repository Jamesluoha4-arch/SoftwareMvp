import SwiftUI
import Combine

// MARK: - 2. 动效组件：节奏几何
struct RhythmGeometryView: View {
    var isPlaying: Bool
    @State private var beat: Bool = false
    @ObservedObject private var audioManager = AudioManager.shared
    
    var body: some View {
        ZStack {
            // 背景网格线 (保持不变)
            Canvas { context, size in
                let step: CGFloat = 30
                let opactity = 0.05 + Double(audioManager.amplitude * 0.15)
                for x in stride(from: 0, through: size.width, by: step) {
                    context.stroke(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) }, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    context.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y)) }, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)
                }
            }
            .frame(width: 300, height: 300)
            
            // 核心几何律动
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 10 + (audioManager.amplitude * 45))
                    .stroke(Color.white.opacity(0.8 - Double(i) * 0.2), lineWidth: 1.5 + audioManager.amplitude * 2)
                    .frame(width: 80 + CGFloat(i * 40), height: 80 + CGFloat(i * 40))
                    .scaleEffect(0.9 + (audioManager.amplitude * (0.2 + Double(i) * 0.1)))
                    .rotationEffect(.degrees(Double(audioManager.amplitude * 45) + Double(i * 45)))
            }
        }
        .onAppear {
            // 延迟一小下确保视图加载完成再触发动画
            DispatchQueue.main.async {
                updateAnimation()
            }
        }
        // 修正：使用 newValue 确保捕捉到变化
        .onChange(of: isPlaying) { newValue in
            updateAnimation()
        }
    }
    
    private func updateAnimation() {
        if isPlaying {
            // 启动循环动画
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                beat = true
            }
        } else {
            // 关键：强制使用普通动画打断 repeatForever
            // 哪怕 beat 已经是 false，这也会强制重置当前的动画层
            withAnimation(.easeInOut(duration: 0.5)) {
                beat = false
            }
        }
    }
}

// MARK: - 3. 主界面容器
struct RhythmPlayPage: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: PlaybackCategory
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var timerManager = TimerManager.shared
    @State private var innerDragOffset: CGFloat = 0
    @State private var showInfoOverlay: Bool = false
    @State private var activeOverlay: ActiveOverlay? = nil
    @State private var isInterceptOn: Bool = false
    @State private var isExiting: Bool = false // 用于强制重置动效
    
    // 注意力数据
    @State private var taskName: String = ""
    @State private var workDuration: Int = 25
    @State private var breakDuration: Int = 5
    @State private var sessions: Int = 1
    
    var initialAction: InitialAction = .none
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "050505").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                ZStack(alignment: .trailing) {
                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 40, height: 5).frame(maxWidth: .infinity)
                    Button(action: { withAnimation(.spring()) { showInfoOverlay = true } }) {
                        Image(systemName: "info.circle").font(.system(size: 24)).foregroundColor(.white)
                    }.padding(.trailing, 25)
                }.padding(.top, 12)
                
                // Title Area
                VStack(spacing: 8) {
                    Text("节奏").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    Text("工作时间集中注意力").font(.system(size: 14)).foregroundColor(.gray)
                }.padding(.top, 30)
                
                Spacer()
                
                // 动效区域
                RhythmGeometryView(isPlaying: audioManager.isPlaying)
                    .frame(width: 300, height: 300)
                
                Spacer()
                
                // 控制面板
                VStack(spacing: 24) {
                    HStack(spacing: 12) {
                        TabButton(title: "白噪音", isSelected: selectedTab == .whiteNoise) { withAnimation{selectedTab = .whiteNoise; audioManager.currentTab = 0} }
                        TabButton(title: "自然音", isSelected: selectedTab == .nature) { withAnimation{selectedTab = .nature; audioManager.currentTab = 1} }
                        TabButton(title: "节奏", isSelected: selectedTab == .rhythm) { withAnimation{selectedTab = .rhythm; audioManager.currentTab = 2} }
                    }.padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if timerManager.countdownSeconds > 0 {
                                Button(action: { timerManager.isTimerActive.toggle() }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: timerManager.isTimerActive ? "stopwatch" : "pause.fill")
                                        Text(timerManager.timerString())
                                    }
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 16).frame(height: 42)
                                    .background(Color.blue.opacity(0.6)).cornerRadius(21)
                                }.contentShape(Capsule())
                            }
                            
                            CapsuleToolButton(icon: "brain.head.profile", title: "注意力") { withAnimation { activeOverlay = .alarm } }
                            CapsuleToolButton(icon: "bubble.left", title: "反馈") { withAnimation { activeOverlay = .feedback } }
                            CapsuleToolButton(icon: "sparkles", title: "声音编辑") { withAnimation { activeOverlay = .soundEdit } }
                            CapsuleToolButton(icon: "hand.raised", title: "拦截", isOn: isInterceptOn) { isInterceptOn.toggle() }
                            CapsuleToolButton(icon: "waveform.path", title: "混合") { withAnimation { activeOverlay = .mix } }
                        }.padding(.horizontal, 20)
                    }
                    
                    HStack(spacing: 30) {
                                            Button(action: {
                                                audioManager.isPlaying = true
                                                timerManager.stopTimer()
                                                timerManager.countdownSeconds = 0
                                            }) { ControlIconGlass(icon: "arrow.clockwise") }
                                            // 播放按钮：直接调用音频管理器的 toggle
                                            Button(action: {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                audioManager.togglePlayPause()
                                            }) {
                                                ControlIconGlass(icon: audioManager.isPlaying ? "pause.fill" : "play.fill", isMain: true)
                                            }
                                            Button(action: { withAnimation { activeOverlay = .alarm } }) { ControlIconGlass(icon: "timer") }
                                            Button(action: { withAnimation { activeOverlay = .mix } }) { ControlIconGlass(icon: "airplayaudio") }
                                        }.padding(.bottom, 10)
                    
                    Button(action: {}) {
                        Text("发现").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 85)
                            .background(Color(hex: "0F0F0F").opacity(0.8))
                            .clipShape(RoundedCorner(radius: 40, corners: [.topLeft, .topRight]))
                    }.padding(.bottom, -15)
                }
            }
            .blur(radius: (activeOverlay != nil || showInfoOverlay) ? 15 : 0)
            .offset(y: innerDragOffset)
            
            // 浮层遮罩逻辑
            if let overlay = activeOverlay {
                Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { withAnimation { activeOverlay = nil } }
                overlayContent(for: overlay)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
            
            if showInfoOverlay {
                RhythmInfoOverlayView(onClose: { withAnimation { showInfoOverlay = false } },
                                      showRoutineAction: {
                    showInfoOverlay = false
                    withAnimation{
                        activeOverlay = .routine
                    }
                })
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
            showInfoOverlay = true
                }
        .onReceive(TimerManager.shared.$countdownSeconds){ _ in
            
        }
    }


    // MARK: - 4. 动态遮罩内容
    @ViewBuilder
    private func overlayContent(for item: ActiveOverlay) -> some View {
        switch item {
        case .alarm: focusSetupView
        case .feedback: feedbackView
        case .soundEdit: soundEditView
        case .mix: mixView
        case .routine: EmptyView()
        }
    }
    
    // --- 注意力设置遮罩 ---
    private var focusSetupView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("注意力集中").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation {
                    timerManager.startTimer(minutes: workDuration)
                    activeOverlay = nil } }) {
                    Text("完成").foregroundColor(.blue).fontWeight(.medium)
                }
            }
            .padding(.horizontal, 25).padding(.top, 25)
            
            VStack(spacing: 24) {
                // 任务输入
                TextField("", text: $taskName, prompt: Text("做了什么").foregroundColor(.gray))
                    .padding().background(Color.white.opacity(0.1)).cornerRadius(12).foregroundColor(.white)
                
                // 时间选择 (自定义UI)
                HStack(spacing: 15) {
                    VStack(alignment: .leading) {
                        Text("工作时长").font(.caption).foregroundColor(.gray)
                        Picker("", selection: $workDuration) {
                            ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { Text("\($0) min").tag($0) }
                        }.pickerStyle(.wheel).frame(height: 100).clipped().colorInvert().colorMultiply(.white)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    VStack(alignment: .leading) {
                        Text("短暂休息").font(.caption).foregroundColor(.gray)
                        Picker("", selection: $breakDuration) {
                            ForEach(1...30, id: \.self) { Text("\($0) min").tag($0) }
                        }.pickerStyle(.wheel).frame(height: 100).clipped().colorInvert().colorMultiply(.white)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                }
                
                // 回合选择器
                HStack {
                    Button(action: { if sessions > 1 { sessions -= 1 } }) {
                        Image(systemName: "minus.circle.fill").font(.title2)
                            .foregroundColor(sessions == 1 ? .white.opacity(0.2) : .white)
                    }
                    Spacer()
                    Text("回合：\(sessions)").font(.headline).foregroundColor(.white)
                    Spacer()
                    Button(action: { sessions += 1 }) {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.white)
                    }
                }
                .padding().frame(height: 60).background(Color.white.opacity(0.1)).cornerRadius(16)
                
                // 开始按钮
                Button(action: { withAnimation { activeOverlay = nil } }) {
                    Text("开始").font(.system(size: 18, weight: .bold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Color.white).cornerRadius(16)
                }
            }
            .padding(25)
            Spacer()
        }
        .frame(height: 540).background(Color(hex: "0A0A0A")).clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
    }
    
    // 其他复用的小遮罩
    private var feedbackView: some View {
        VStack {
            Text("声音反馈").font(.headline).foregroundColor(.white).padding(.top, 20)
            HStack(spacing: 40) {
                Image(systemName: "face.smiling").font(.system(size: 40)).foregroundColor(.white)
                Image(systemName: "face.dashed").font(.system(size: 40)).foregroundColor(.white)
            }.padding(40)
        }.frame(maxWidth: .infinity, maxHeight: 200).background(Color.black).clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
    }
    
    private var soundEditView: some View {
        VStack(spacing: 20) {
            Text("声音编辑").font(.headline).foregroundColor(.white)
            TextField("", text: .constant(""), prompt: Text("描述声音...").foregroundColor(.gray))
                .padding().background(Color.white.opacity(0.1)).cornerRadius(12)
            Button("应用") { withAnimation { activeOverlay = nil } }
                .frame(maxWidth: .infinity).frame(height: 50).background(Color.white).foregroundColor(.black).cornerRadius(12)
        }.padding(25).frame(maxHeight: 300).background(Color.black).clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
    }
    
    private var mixView: some View {
        VStack(spacing: 20) {
            HStack { Text("混合音频").foregroundColor(.white); Spacer(); Toggle("", isOn: .constant(true)).labelsHidden() }
            Text("混合音频开启时，背景声音将持续播放").font(.caption).foregroundColor(.gray)
        }.padding(25).frame(maxHeight: 200).background(Color.black).clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
    }
}

// MARK: - 5. 节奏信息详情页
struct RhythmInfoOverlayView: View {
    var onClose: () -> Void
    var showRoutineAction:() -> Void
    var body: some View {
        ZStack(alignment: .bottom) { // 核心：强制所有内容底部对齐
            Color.black.ignoresSafeArea()
            
            // 1. 中间滚动内容层
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("节奏").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                        Text("工作时间集中注意力").font(.system(size: 16)).foregroundColor(.gray)
                    }.padding(.top, 60)
                    
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        Image(systemName: "timer").font(.system(size: 80)).foregroundColor(.white)
                    }.frame(width: 200, height: 200).padding(.vertical, 50)
                    
                    Text("节奏变化，快速进入状态").font(.system(size: 18)).foregroundColor(.white).padding(.bottom, 30)
                    
                    VStack(alignment: .leading, spacing: 25) {
                        Divider().background(Color.white.opacity(0.2))
                        Text("节奏").font(.system(size: 14)).foregroundColor(.gray)
                        Text("节奏是高效工作的底层协议。通过音频律动的引导，使大脑皮层进入稳态，降低对环境噪音的敏感度。")
                            .font(.system(size: 20, weight: .medium)).foregroundColor(.white).lineSpacing(8)
                        
                        Divider().background(Color.white.opacity(0.2))
                        Text("原理").font(.system(size: 14)).foregroundColor(.gray)
                        Text("利用双耳节拍技术模拟 Alpha 和 Beta 脑电波，在专注阶段提供稳定的背景支撑。").foregroundColor(.gray)
                    }.padding(.horizontal, 30)
                    
                    // 给底部按钮留出足够的空白占位，确保滚动不到底时不会被遮挡
                    Spacer(minLength: 180)
                }
            }
            
            // 2. 底部固定按钮层（放在 ScrollView 外面）
            VStack(spacing: 12) {
                Button(action: onClose) {
                    Text("开始").font(.system(size: 18, weight: .bold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Color.white).cornerRadius(16)
                }
                
                Button(action: showRoutineAction) {
                    Text("创建例行活动").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Color.white.opacity(0.1)).cornerRadius(16)
                }
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 40) // 距离屏幕底部的安全距离
            .background(
                // 这里加个背景色渐变，可以防止滚动的内容穿透按钮
                LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8), .black]), startPoint: .top, endPoint: .center)
            )
            
            // 3. 顶部的关闭按钮（独立层级）
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    .padding(25)
                }
                Spacer()
            }
        }
    }
}
