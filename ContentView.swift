import SwiftUI


// MARK: - 1. 动效组件：水波纹
struct RippleEffectView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.white.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .scaleEffect(animate ? 2.0 : 1.0)
                    .opacity(animate ? 0.0 : 1.0)
                    .animation(
                        Animation.easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.6),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - 2. 动效组件：流星与漂浮圆
struct StarMeteorView: View {
    @State private var animate = false
    var delay: Double = 0
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 4, height: 4)
                .blur(radius: 2)
                .overlay(
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 40, height: 2)
                        .rotationEffect(.degrees(45), anchor: .leading),
                    alignment: .leading
                )
                .offset(x: animate ? proxy.size.width + 50 : -50,
                        y: animate ? proxy.size.height + 50 : -50)
                .onAppear {
                    withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false).delay(delay)) {
                        animate = true
                    }
                }
        }.clipped()
    }
}

struct FloatingBlurCircle: View {
    @State private var move = false
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 40, height: 40)
                .blur(radius: 20)
                .offset(x: move ? proxy.size.width - 40 : 5,
                        y: move ? proxy.size.height - 40 : 5)
                .onAppear {
                    withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                        move.toggle()
                    }
                }
        }
    }
}



// MARK: - 4. 业务组件
struct SceneCard: View {
    var title: String
    var imageName: String
    var height: CGFloat
    var titleAlignment: Alignment = .topLeading
    var showMeteor: Bool = false
    var meteorDelay: Double = 0
    
    var body: some View {
        ZStack(alignment: titleAlignment) {
            if showMeteor { StarMeteorView(delay: meteorDelay) }
            // 这里会调用你 Assets 里的图片
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: height)
                .clipped()
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(16)
        }
        .frame(height: height)
        .glassStyle(opacity: 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

struct SoundBubble: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 100, height: 75)
            .glassStyle(opacity: 0.74, cornerRadius: 40, showBorder: true, addFloatingEffect: true)
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 10)
    }
}

// MARK: - 5. 更新后的 Mini 播放栏组件
struct MiniPlayerBar: View {
    @StateObject private var audioManager = AudioManager.shared
    var currentTheme: PlaybackCategory{
        PlaybackCategory(rawValue: audioManager.currentTab) ?? .whiteNoise
    }
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                if audioManager.isPlaying {
                    RippleEffectView()
                        .scaleEffect(0.8 + audioManager.amplitude * 0.5)
                        .opacity(0.5 + audioManager.amplitude * 0.5)
                }
                
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: currentTheme.icon)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 20))
                    .id(currentTheme.icon) // 增加 ID 确保图标切换时有动效
                    .transition(.scale.combined(with: .opacity))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // 实现功能：文字联动状态切换
                Text(audioManager.isPlaying ? "正在播放" : "停止播放")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .transition(.opacity) // 让文字切换平滑一点
                
                Text(currentTheme.title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .id(currentTheme.title)
                                    .transition(.push(from: .bottom)) // 文字切换动效
            }
            
            Spacer()
            
            HStack(spacing: 25) {
                Image(systemName: "alarm").foregroundColor(.white.opacity(0.7)).font(.system(size: 20))
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        audioManager.togglePlayPause()
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .frame(width: 30)
                }
            }
            .padding(.trailing, 5)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            Capsule()
                .fill(Color(hex: "1A1A1A"))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - 6. 主界面
struct ContentView: View {
    @State private var bannerAnimate = false
    @State private var soundSectionOpacity: Double = 0
    @State private var showWhiteNoise = false  // 对应 PlayPage
    @State private var showNature = false      // 对应 NaturePlayPage
    @State private var showRhythm = false      // 对应 RhythmPlayPage
    @State private var currentTheme: PlaybackCategory = .whiteNoise // 记录当前选择的主题
    @State private var isPlayerPresented = false // 统一控制弹窗显示
    @State private var initialAction: InitialAction = .none 
    @StateObject private var audioManager = AudioManager.shared
    
    private func navigateTo(category:PlaybackCategory, action: InitialAction){
        self.currentTheme = category
        self.initialAction = action
        switch category {
            case .whiteNoise: audioManager.currentTab = 0
            case .nature:     audioManager.currentTab = 1
            case .rhythm:     audioManager.currentTab = 2
            }
        withAnimation(.spring()){
            self.isPlayerPresented = true
        }
    }
    
    
    var currentDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 40) {
                    headerAndScenesSection
                    
                    // 声音板块
                    VStack(alignment: .leading, spacing: 0) {
                        Text("声音")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        Spacer().frame(height: 35)
                        
                        GeometryReader { proxy in
                            let minY = proxy.frame(in: .global).minY
                            let screenHeight = UIScreen.main.bounds.height
                            
                            ZStack(alignment: .topTrailing) {
                                // 声音板块背景图
                                Image("face_lines")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 320)
                                    .opacity(0.6)
                                    .offset(x: 60, y: 100)
                                
                                Image("image_shooting_star")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 140)
                                    .offset(x: -15, y: -20)
                                
                                VStack(alignment: .leading, spacing: 20) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("晚上好").font(.system(size: 18)).foregroundColor(.white.opacity(0.8))
                                        Text("用户昵称")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 8).padding(.horizontal, 20)
                                            .glassStyle(opacity: 0.3, cornerRadius: 12)
                                        Text("现在是\(currentDateText)夜间，一起开启好梦").font(.system(size: 14)).foregroundColor(.gray)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        // 1. 白噪音入口
                                        SoundBubble(title: "白噪音")
                                            .offset(y: 20)
                                            .onTapGesture {
                                                switchTheme(to: . whiteNoise)
                                            }
                                        
                                        // 2. 自然之声入口
                                        SoundBubble(title: "自然之声")
                                            .offset(y: 120).offset(x: 40)
                                            .onTapGesture {
                                                switchTheme(to: . nature)
                                            }
                                        
                                        // 3. 节奏入口
                                        SoundBubble(title: "节奏")
                                            .offset(y: 220).offset(x: -200)
                                            .onTapGesture {
                                                switchTheme(to: . rhythm)
                                            }
                                    }
                                    .padding(.top, 25)
                                }
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .opacity(soundSectionOpacity)
                            .onChange(of: minY) { newValue in
                                if newValue < screenHeight * 0.85 {
                                    withAnimation(.easeIn(duration: 0.8)) {
                                        soundSectionOpacity = 1.0
                                    }
                                }
                            }
                        }
                        .frame(height: 400)
                    }
                    .padding(.top, 20)
                }
                .padding(.bottom, 140)
            }
            .gesture(
                DragGesture().onEnded {value in
                    if value.translation.height > 80{
                        withAnimation(.spring()){
                            isPlayerPresented = true
                        }
                    }
                    
                }
            )
            MiniPlayerBar()
                .onTapGesture {
                    // 点击 Mini Bar 默认跳转到白噪音页
                    withAnimation(.spring()) {
                        self.currentTheme = PlaybackCategory(rawValue: audioManager.currentTab) ?? .whiteNoise
                        isPlayerPresented = true }
                }
        }
        // --- 零侵入转场配置 ---
        .fullScreenCover(isPresented: $isPlayerPresented, onDismiss: {initialAction = .none}){
            Group {
                            switch currentTheme {
                            case .whiteNoise:
                                // 修复：必须传递 $currentTheme 以满足 @Binding 要求
                                PlayPage(isPresented: $isPlayerPresented, selectedTab: $currentTheme, initialAction: initialAction)
                            case .nature:
                                // 假设你的自然音页面叫 NaturePlayPage
                                NaturePlayPage(isPresented: $isPlayerPresented, selectedTab: $currentTheme, initialAction: initialAction)
                            case .rhythm:
                                // 节奏页面
                                RhythmPlayPage(isPresented: $isPlayerPresented, selectedTab: $currentTheme, initialAction: initialAction)
                            }
                        }
                        // 整个全屏覆盖层使用黑色背景，防止切换瞬间闪白
                        .background(Color.black.ignoresSafeArea())
        } }
    private func switchTheme(to theme: PlaybackCategory) {
            withAnimation(.easeInOut) {
                self.currentTheme = theme
                switch theme {
                case .whiteNoise: audioManager.currentTab = 0
                case .nature: audioManager.currentTab = 1
                case .rhythm: audioManager.currentTab = 2
                }
                self.isPlayerPresented = true // 点击泡泡直接进入全屏
            }
        }
    
    private var headerAndScenesSection: some View {
        VStack(spacing: 28) {
            // Header
            HStack {
                Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .frame(width: 34, height: 34)
                    .overlay(Text("logo").font(.system(size: 8)).foregroundColor(.white))
                Text("Brand Name").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Spacer()
                Image(systemName: "gift").foregroundColor(.white)
                Image(systemName: "sparkles")
                    .padding(8)
                    .background(Circle().stroke(Color.white.opacity(0.4)))
                    .foregroundColor(.white)
            }.padding(.horizontal)

            // Banner
            ZStack(alignment: .bottomLeading) {
                Image("image_share")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .scaleEffect(bannerAnimate ? 1.2 : 1.0)
                    .animation(Animation.easeInOut(duration: 8.0).repeatForever(autoreverses: true), value: bannerAnimate)
                
                Text("分享并邀请").font(.system(size: 22, weight: .heavy)).foregroundColor(.white).padding(.leading, 24).padding(.bottom, 30)
            }
            .frame(height: 200).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 28)).glassStyle(opacity: 0.74).padding(.horizontal)
            .onAppear { bannerAnimate = true }

            // 场景卡片
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("场景").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Text("显示全部").foregroundColor(.gray)
                }.padding(.horizontal)
                
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 14) {
                        SceneCard(title: "专注", imageName: "focus", height: 210, showMeteor: true)
                            .onTapGesture { navigateTo(category: .rhythm, action: .showInfo)}
                        SceneCard(title: "创造", imageName: "create", height: 120, titleAlignment: .bottomLeading)
                    }
                    VStack(spacing: 14) {
                        SceneCard(title: "休息", imageName: "rest", height: 100, titleAlignment: .topTrailing)
                            .onTapGesture { navigateTo(category: .whiteNoise, action: .showInfo)}
                        SceneCard(title: "冥想", imageName: "meditate", height: 190, titleAlignment: .bottomTrailing, showMeteor: true, meteorDelay: 1.0)
                            .onTapGesture { navigateTo(category: .nature, action: .showInfo)}
                    }
                }.padding(.horizontal)
            }
        }
    }
}
