import SwiftUI

struct MeView: View {
    @State private var isPro = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("个人信息")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text("用户名")
                                .font(.title)
                            Text("查看并编辑个人资料")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section(header: Text("作品")) {
                    NavigationLink(destination: Text("我的作品")) { Text("我的作品") }
                    NavigationLink(destination: Text("收藏")) { Text("收藏") }
                    NavigationLink(destination: Text("最近编辑")) { Text("最近编辑") }
                }

                Section(header: Text("会员")) {
                    HStack {
                        Text("AI 美图 Pro")
                        Spacer()
                        Text(isPro ? "已订阅" : "未订阅")
                            .foregroundColor(isPro ? .green : .red)
                    }
                    Toggle(isOn: $isPro) {
                        Text("订阅 AI 美图 Pro")
                    }
                }
                
                Section(header: Text("AI Credits")) {
                    HStack {
                        Text("剩余 Credits")
                        Spacer()
                        Text("100")
                    }
                }

                Section(header: Text("设置")) {
                    NavigationLink(destination: Text("账号设置")) { Text("账号") }
                    NavigationLink(destination: Text("照片权限")) { Text("照片权限") }
                    NavigationLink(destination: Text("保存质量")) { Text("保存质量") }
                    NavigationLink(destination: Text("隐私")) { Text("隐私") }
                    NavigationLink(destination: Text("通知")) { Text("通知") }
                    NavigationLink(destination: Text("恢复购买")) { Text("恢复购买") }
                    NavigationLink(destination: Text("关于我们")) { Text("关于") }
                }
                
                Section {
                    Text("当前版本: 1.0.0")
                        .foregroundColor(.gray)
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("我的")
        }
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}
