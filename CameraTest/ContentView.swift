//
//  ContentView.swift
//  CameraTest
//
//  Created by Shigong Liu on 1/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showingPhotoPickerAIBeautify = false
    @State private var showingCollagePhotoPicker = false

    var body: some View {
        TabView {
            NavigationView {
                VStack {
                    // Top section: Brand name and Settings button
                    HStack {
                        Text("AI 美图")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            // Action for settings
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                        }
                    }
                    .padding()

                    Spacer()

                    // Main title
                    Text("让照片变得更好看")
                        .font(.title)
                        .padding(.bottom, 40)

                    // Two primary entry points
                    VStack(spacing: 20) {
                        Button(action: {
                            showingPhotoPickerAIBeautify = true
                        }) {
                            Label("AI 美化", systemImage: "sparkles")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                        .sheet(isPresented: $showingPhotoPickerAIBeautify) {
                            PhotoPickerView(selectionLimit: 1, mode: .aiBeautify)
                        }

                        Button(action: {
                            showingCollagePhotoPicker = true
                        }) {
                            Label("拼图", systemImage: "photo.on.rectangle.angled")
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                        .sheet(isPresented: $showingCollagePhotoPicker) {
                            CollagePhotoPickerView()
                        }
                    }
                    .padding(.horizontal)

                    // Quick Tools
                    HStack(spacing: 20) {
                        VStack {
                            Button(action: { /* Action for Erase */ }) {
                                Image(systemName: "eraser.fill")
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            Text("消除")
                                .font(.caption)
                        }
                        VStack {
                            Button(action: { /* Action for Expand Image */ }) {
                                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            Text("扩图")
                                .font(.caption)
                        }
                        VStack {
                            Button(action: { /* Action for Filter */ }) {
                                Image(systemName: "camera.filters")
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            Text("滤镜")
                                .font(.caption)
                        }
                        VStack {
                            Button(action: { /* Action for Adjust */ }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            Text("调整")
                                .font(.caption)
                        }
                    }
                    .padding(.top, 30)

                    // Recent Works
                    VStack(alignment: .leading) {
                        Text("最近作品")
                            .font(.headline)
                            .padding(.leading)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(0..<5) { index in
                                    Button(action: {
                                        // Action to continue editing recent work
                                    }) {
                                        Image(systemName: "photo.fill") // Placeholder thumbnail
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 30)

                    Spacer()
                }
                .navigationBarHidden(true) // Hide default navigation bar
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            }

            MeView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
