import SwiftUI
import Combine
import AVFoundation

// MARK: - 1. 颜色扩展 (支持 6 位和 8 位 Hex)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 2. 形状工具
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - 3. 玻璃质感修饰符 (修复参数不匹配问题)
struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: Double
    var showBorder: Bool
    var addFloatingEffect: Bool // 确保这里有这个属性
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 模糊背景基底
                    Color(hex: "0F0F0F").opacity(opacity)
                    
                    // 只有当 addFloatingEffect 为 true 时才显示漂浮圆
                    // 注意：FloatingBlurCircle 定义在你的 ContentView 文件中
                    if addFloatingEffect {
                        FloatingBlurCircle()
                            .mask(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    
                    // 顶部高光渐变
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0.12), location: 0),
                        .init(color: .clear, location: 0.5)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(showBorder ? 0.35 : 0.15), lineWidth: showBorder ? 1.5 : 0.5)
            )
    }
}

// MARK: - 4. 视图扩展 (修复方法签名)
extension View {
    func glassStyle(
        opacity: Double = 0.74,
        cornerRadius: CGFloat = 28,
        showBorder: Bool = false,
        addFloatingEffect: Bool = false // 增加此参数以匹配调用
    ) -> some View {
        self.modifier(GlassModifier(
            cornerRadius: cornerRadius,
            opacity: opacity,
            showBorder: showBorder,
            addFloatingEffect: addFloatingEffect
        ))
    }
}

enum PlaybackCategory: Int {
    case whiteNoise = 0
    case nature = 1
    case rhythm = 2
    
    var title: String {
        switch self {
        case .whiteNoise: return "白噪音"
        case .nature: return "自然之声"
        case .rhythm: return "节奏"
        }
    }
    
    var icon: String {
        switch self {
        case .whiteNoise: return "moon.stars"
        case .nature: return "leaf.fill"
        case .rhythm: return "bolt.ring.closed"
        }
    }
}
enum ActiveOverlay: Identifiable {
    case feedback, soundEdit, alarm, mix, routine
    var id: Int { self.hashValue }
}


struct DaySelectionButton: View {
    let title: String
    @State private var isSelected: Bool = false
    
    var body: some View {
        Button(action: { isSelected.toggle() }) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
        }
    }
}

struct CapsuleToolButton: View {
    var icon: String; var title: String; var isOn: Bool = false; var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isOn ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16).frame(height: 42)
            .background(isOn ? Color.white.opacity(0.15) : Color.clear)
            .overlay(Capsule().stroke(Color.white.opacity(isOn ? 0.4 : 0.15), lineWidth: 1))
        }
        .contentShape(Capsule())
    }
}

struct ControlIconGlass: View {
    var icon: String; var isMain: Bool = false
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.1))
            Image(systemName: icon).font(.system(size: isMain ? 22 : 16, weight: .bold)).foregroundColor(.white)
        }.frame(width: isMain ? 65 : 52, height: isMain ? 65 : 52)
         .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}

struct TabButton: View {
    var title: String; var isSelected: Bool; var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity).frame(height: 55)
                .glassStyle(opacity: isSelected ? 0.25 : 0.08, cornerRadius: 18)
        }.contentShape(Rectangle())
    }
}

struct SquareIconButton: View {
    var icon: String
    var body: some View {
        Image(systemName: icon).font(.system(size: 35)).foregroundColor(.white)
            .frame(width: 85, height: 85).glassStyle(opacity: 0.1, cornerRadius: 18)
    }
}
struct MainPlayContainer: View {
    @Binding var isPresented: Bool
    @State private var currentCategory: PlaybackCategory = .whiteNoise
    
    // 如果想从外部指定初始进入哪个频道，可以加个构造函数
    init(isPresented: Binding<Bool>, initialCategory: PlaybackCategory = .whiteNoise) {
        self._isPresented = isPresented
        self._currentCategory = State(initialValue: initialCategory)
    }

    var body: some View {
        ZStack {
            // TabView 负责横向滑动切换界面
            TabView(selection: $currentCategory) {
                // 页面 1
                PlayPage(isPresented: $isPresented, selectedTab: $currentCategory)
                    .tag(PlaybackCategory.whiteNoise)
                
                // 页面 2
                NaturePlayPage(isPresented: $isPresented, selectedTab: $currentCategory)
                    .tag(PlaybackCategory.nature)
                
                // 页面 3
                RhythmPlayPage(isPresented: $isPresented, selectedTab: $currentCategory)
                    .tag(PlaybackCategory.rhythm)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // 隐藏系统圆点
            .ignoresSafeArea()
        }
    }
}


struct SwipeUpToCloseModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture().onEnded { value in
                    // 关键点：height < -80 表示手指往上滑
                    if value.translation.height < -80 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    }
                }
            )
    }
}


enum InitialAction {
    case none
    case showInfo // 显示信息/遮罩
}





class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var isPlaying: Bool = false
    @Published var currentTab: Int = 0 { didSet { setupTrack() } }
    @Published var amplitude: CGFloat = 0.0 // 实时振幅 (0.0 - 1.0)
    
    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink? // 使用高精度定时器同步屏幕刷新率
    private let tracks = ["white_noise", "nature_sounds","rhythm_beat"]

    init() {
        setupAudioSession()
        setupTrack()
        autoStart()
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    private func autoStart(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
            if !self.isPlaying{
                self.togglePlayPause()
            }
        }
    }

    func setupTrack() {
        guard let url = Bundle.main.url(forResource: tracks[currentTab], withExtension: "mp3") else { return }
        let wasPlaying = isPlaying
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.isMeteringEnabled = true // 开启电平监测
            player?.numberOfLoops = -1
            if wasPlaying { player?.play() }
        } catch { print("加载失败") }
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
            stopMonitoring()
        } else {
            if player == nil { setupTrack() }
            player?.play()
            startMonitoring()
        }
        isPlaying.toggle()
    }

    // 使用 DisplayLink 保证动效每秒 60/120 帧的流畅度
    private func startMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateMeters))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        amplitude = 0
    }

    @objc private func updateMeters() {
        guard let player = player, player.isPlaying else { return }
        player.updateMeters()
        
        // 将分贝 (-60dB 到 0dB) 映射为 0.0 到 1.0 的线性数值
        let power = player.averagePower(forChannel: 0)
        let level = max(0.0, CGFloat(power + 60) / 60)
        
        DispatchQueue.main.async {
            self.amplitude = level
        }
    }
}
