import SwiftUI
import UIKit

// MARK: - Editor tabs & controls

enum EditorTab: String, CaseIterable, Identifiable {
    case ai = "AI 美化"
    case beauty = "美颜"
    case adjust = "调整"
    case filter = "滤镜"
    var id: String { rawValue }
}

enum BeautyControl: String, CaseIterable, Identifiable {
    case smoothing, whitening, rosy, acne, darkCircles
    case slimFace, bigEyes, nose, chin

    var id: String { rawValue }

    static let skin: [BeautyControl] = [.smoothing, .whitening, .rosy, .acne, .darkCircles]
    static let shape: [BeautyControl] = [.slimFace, .bigEyes, .nose, .chin]

    var title: String {
        switch self {
        case .smoothing: return "磨皮"
        case .whitening: return "美白"
        case .rosy: return "红润"
        case .acne: return "祛痘"
        case .darkCircles: return "黑眼圈"
        case .slimFace: return "瘦脸"
        case .bigEyes: return "大眼"
        case .nose: return "鼻型"
        case .chin: return "下巴"
        }
    }

    var icon: String {
        switch self {
        case .smoothing: return "drop"
        case .whitening: return "sun.max"
        case .rosy: return "heart"
        case .acne: return "bandage"
        case .darkCircles: return "eye"
        case .slimFace: return "person.crop.circle"
        case .bigEyes: return "eye.circle"
        case .nose: return "triangle"
        case .chin: return "chevron.down.circle"
        }
    }

    var keyPath: WritableKeyPath<BeautyParameters, Double> {
        switch self {
        case .smoothing: return \.smoothing
        case .whitening: return \.whitening
        case .rosy: return \.rosy
        case .acne: return \.acne
        case .darkCircles: return \.darkCircles
        case .slimFace: return \.slimFace
        case .bigEyes: return \.bigEyes
        case .nose: return \.nose
        case .chin: return \.chin
        }
    }
}

enum AdjustControl: String, CaseIterable, Identifiable {
    case brightness, contrast, saturation, warmth, sharpen, vignette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brightness: return "亮度"
        case .contrast: return "对比度"
        case .saturation: return "饱和度"
        case .warmth: return "色温"
        case .sharpen: return "锐化"
        case .vignette: return "暗角"
        }
    }

    var icon: String {
        switch self {
        case .brightness: return "sun.max"
        case .contrast: return "circle.lefthalf.filled"
        case .saturation: return "drop.halffull"
        case .warmth: return "thermometer.medium"
        case .sharpen: return "triangle"
        case .vignette: return "circle.dashed"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .sharpen, .vignette: return 0...100
        default: return -100...100
        }
    }

    var keyPath: WritableKeyPath<BeautyParameters, Double> {
        switch self {
        case .brightness: return \.brightness
        case .contrast: return \.contrast
        case .saturation: return \.saturation
        case .warmth: return \.warmth
        case .sharpen: return \.sharpen
        case .vignette: return \.vignette
        }
    }
}

// MARK: - Editor

struct AIBeautyEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let sourceImage: UIImage
    private let title: String

    @State private var engine: BeautyEngine?
    @State private var params = BeautyParameters()
    @State private var renderedImage: UIImage?
    @State private var originalPreview: UIImage?
    @State private var filterThumbnails: [FilterPreset: UIImage] = [:]
    @State private var renderTask: Task<Void, Never>?

    @State private var selectedTab: EditorTab = .ai
    @State private var selectedBeauty: BeautyControl = .smoothing
    @State private var selectedAdjust: AdjustControl = .brightness
    @State private var isShowingOriginal = false
    @State private var isSaving = false
    @State private var isShowingSaveConfirmation = false

    init(uiImage: UIImage, initialTab: EditorTab = .ai) {
        sourceImage = uiImage
        _selectedTab = State(initialValue: initialTab)
        // Opened from a quick tool (滤镜 / 调整): start from the untouched photo.
        if initialTab != .ai {
            var start = BeautyParameters()
            start.aiIntensity = 0
            _params = State(initialValue: start)
        }
        title = initialTab == .ai ? "AI 美化" : initialTab.rawValue
    }

    /// Kept for older call sites. Prefer `init(uiImage:)` so the full-quality photo is used.
    init(image: Image) {
        sourceImage = image.asUIImageRendered(size: CGSize(width: 1080, height: 1080)) ?? UIImage()
        title = "AI 美化"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            preview
            bottomPanel
        }
        .navigationBarHidden(true)
        .task { await loadEngine() }
        .onChange(of: params) { scheduleRender() }
        .alert("保存成功", isPresented: $isShowingSaveConfirmation) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("照片已保存到你的相册")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left").font(.title2)
            }
            Spacer()
            Text(title).font(.headline)
            Spacer()
            if isSaving {
                ProgressView()
            } else {
                Button("保存") { saveImage() }
                    .fontWeight(.bold)
                    .disabled(engine == nil)
            }
        }
        .padding()
    }

    // MARK: Preview with before/after

    private var preview: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = isShowingOriginal ? originalPreview : renderedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView("正在识别人脸…")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)

            if engine != nil {
                Text(isShowingOriginal ? "原图" : "按住对比")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(24)
                    .onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { pressing in
                        isShowingOriginal = pressing
                    })
            }
        }
    }

    // MARK: Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            switch selectedTab {
            case .ai: aiPanel
            case .beauty: beautyPanel
            case .adjust: adjustPanel
            case .filter: filterPanel
            }

            Picker("", selection: $selectedTab) {
                ForEach(EditorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .disabled(engine == nil)
    }

    private var aiPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("AI 美化强度")
                Spacer()
                Text("\(Int(params.aiIntensity))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("重置") { params.aiIntensity = 50 }
                    .font(.caption)
            }
            Slider(value: $params.aiIntensity, in: 0...100, step: 1) {
                Text("AI 美化强度")
            } minimumValueLabel: {
                Text("0").font(.caption)
            } maximumValueLabel: {
                Text("100").font(.caption)
            }
        }
        .padding(.horizontal)
    }

    private var beautyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if engine?.hasFaces == false {
                Label("未检测到人脸，美颜对这张照片无效", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            valueSlider(title: selectedBeauty.title,
                        value: binding(for: selectedBeauty.keyPath),
                        range: 0...100,
                        reset: { params[keyPath: selectedBeauty.keyPath] = 0 })

            controlRow(title: "肌肤", controls: BeautyControl.skin)
            controlRow(title: "美型", controls: BeautyControl.shape)
        }
    }

    private func controlRow(title: String, controls: [BeautyControl]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 32)
                .padding(.top, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(controls) { control in
                        chip(title: control.title,
                             icon: control.icon,
                             isSelected: selectedBeauty == control,
                             isActive: params[keyPath: control.keyPath] > 0) {
                            selectedBeauty = control
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var adjustPanel: some View {
        VStack(spacing: 10) {
            valueSlider(title: selectedAdjust.title,
                        value: binding(for: selectedAdjust.keyPath),
                        range: selectedAdjust.range,
                        reset: { params[keyPath: selectedAdjust.keyPath] = 0 })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AdjustControl.allCases) { control in
                        chip(title: control.title,
                             icon: control.icon,
                             isSelected: selectedAdjust == control,
                             isActive: params[keyPath: control.keyPath] != 0) {
                            selectedAdjust = control
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var filterPanel: some View {
        VStack(spacing: 10) {
            if params.filter != .original {
                valueSlider(title: "\(params.filter.title) 强度",
                            value: $params.filterIntensity,
                            range: 0...100,
                            reset: { params.filterIntensity = 100 })
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilterPreset.allCases) { preset in
                        Button {
                            params.filter = preset
                        } label: {
                            VStack(spacing: 4) {
                                Group {
                                    if let thumb = filterThumbnails[preset] {
                                        Image(uiImage: thumb).resizable().scaledToFill()
                                    } else {
                                        Color.gray.opacity(0.2)
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(params.filter == preset ? Color.purple : .clear, lineWidth: 2)
                                )
                                Text(preset.title)
                                    .font(.caption)
                                    .foregroundStyle(params.filter == preset ? Color.purple : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: Reusable pieces

    private func valueSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, reset: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("重置", action: reset)
                    .font(.caption)
            }
            Slider(value: value, in: range, step: 1)
        }
        .padding(.horizontal)
    }

    private func chip(title: String, icon: String, isSelected: Bool, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.purple.opacity(0.2) : Color.gray.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(alignment: .topTrailing) {
                        if isActive {
                            Circle().fill(Color.purple).frame(width: 8, height: 8)
                        }
                    }
                Text(title).font(.caption)
            }
            .foregroundStyle(isSelected ? Color.purple : .primary)
        }
        .buttonStyle(.plain)
    }

    private func binding(for keyPath: WritableKeyPath<BeautyParameters, Double>) -> Binding<Double> {
        Binding(get: { params[keyPath: keyPath] },
                set: { params[keyPath: keyPath] = $0 })
    }

    // MARK: Rendering

    private func loadEngine() async {
        guard engine == nil else { return }
        let image = sourceImage
        let loaded = await Task.detached(priority: .userInitiated) { BeautyEngine(image: image) }.value
        guard let loaded else { return }
        engine = loaded
        originalPreview = UIImage(cgImage: loaded.previewImage)
        scheduleRender(debounce: false)

        let thumbs = await Task.detached(priority: .utility) { loaded.filterThumbnails() }.value
        filterThumbnails = thumbs.mapValues { UIImage(cgImage: $0) }
    }

    private func scheduleRender(debounce: Bool = true) {
        guard let engine else { return }
        let current = params
        renderTask?.cancel()
        renderTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(40))
            }
            guard !Task.isCancelled else { return }
            let output = await Task.detached(priority: .userInitiated) { engine.render(current) }.value
            guard !Task.isCancelled, let output else { return }
            renderedImage = UIImage(cgImage: output)
        }
    }

    private func saveImage() {
        guard let engine else { return }
        let current = params
        isSaving = true
        Task {
            let output = await Task.detached(priority: .userInitiated) {
                engine.render(current, fullResolution: true)
            }.value
            isSaving = false
            guard let output else { return }
            PhotoSaver().writeToPhotoAlbum(image: UIImage(cgImage: output))
            isShowingSaveConfirmation = true
        }
    }
}

struct AIBeautyEditorView_Previews: PreviewProvider {
    static var previews: some View {
        AIBeautyEditorView(uiImage: UIImage(systemName: "person.crop.square") ?? UIImage())
    }
}
