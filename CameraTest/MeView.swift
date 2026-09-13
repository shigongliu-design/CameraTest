import SwiftUI

struct MeView: View {
    @State private var isProUser: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Top Section: Avatar, Username, Settings
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            Text("用户名")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("欢迎使用 AI 美图")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: {
                            // Action for Settings
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Core Area: My Works, Favorites, Recently Edited
                    VStack(alignment: .leading, spacing: 15) {
                        Text("我的作品")
                            .font(.headline)
                        HStack {
                            Spacer()
                            VStack {
                                Image(systemName: "photo.stack.fill")
                                Text("我的作品")
                            }
                            Spacer()
                            VStack {
                                Image(systemName: "heart.fill")
                                Text("收藏")
                            }
                            Spacer()
                            VStack {
                                Image(systemName: "clock.fill")
                                Text("最近编辑")
                            }
                            Spacer()
                        }
                        .font(.caption)
                        .padding(.vertical)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Membership Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("会员特权")
                            .font(.headline)
                        HStack {
                            Text("Pro 状态: ") + Text(isProUser ? "已开通" : "未开通").fontWeight(.bold).foregroundColor(isProUser ? .green : .red)
                            Spacer()
                            Button(action: {
                                isProUser.toggle()
                            }) {
                                Text(isProUser ? "管理订阅" : "立即开通")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Text("AI Credits: 100 额度")
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("设置")
                            .font(.headline)
                        LinkRow(icon: "person.crop.circle", title: "账号")
                        LinkRow(icon: "photo.on.rectangle", title: "照片权限")
                        LinkRow(icon: "square.and.arrow.down", title: "保存质量")
                        LinkRow(icon: "hand.raised.fill", title: "隐私")
                        LinkRow(icon: "bell.fill", title: "通知")
                        LinkRow(icon: "arrow.counterclockwise", title: "恢复购买")
                        LinkRow(icon: "info.circle.fill", title: "关于")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 25)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}
