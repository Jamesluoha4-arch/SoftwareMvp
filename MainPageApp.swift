import SwiftUI

@main // 程序入口标记
struct MainPageApp: App { // 遵循 App 协议
    
    var body: some Scene {
        WindowGroup {
            //PlayPage(isPresented: .constant(true))
            ContentView()
            //NaturePlayPage(isPresented: .constant(true))
            //RhythmPlayPage(isPresented: .constant(true))
        }
    }
}
