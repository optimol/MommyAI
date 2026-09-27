import PhotosUI
import SwiftUI

enum MommyTheme {
    static let background = Color(red: 0.055, green: 0.045, blue: 0.075)
    static let panel = Color.white.opacity(0.075)
    static let panelBorder = Color.white.opacity(0.12)
    static let hotPink = Color(red: 1.0, green: 0.20, blue: 0.46)
    static let angryRed = Color(red: 1.0, green: 0.16, blue: 0.20)
    static let cream = Color(red: 1.0, green: 0.94, blue: 0.85)
    static let mint = Color(red: 0.38, green: 0.94, blue: 0.70)
}

struct ScreenContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }
}

struct Eyebrow: View {
    let text: String
    var color = MommyTheme.hotPink

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.black))
            .tracking(2.4)
            .foregroundStyle(color)
    }
}

struct MommyButton: View {
    let title: String
    var icon: String?
    var color = MommyTheme.hotPink
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline.weight(.black))
                if let icon {
                    Image(systemName: icon)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(disabled ? Color.gray.opacity(0.35) : color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: disabled ? .clear : color.opacity(0.3), radius: 16, y: 8)
        }
        .disabled(disabled)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(MommyTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MommyTheme.panelBorder, lineWidth: 1)
            }
    }
}

extension View {
    func mommyCard() -> some View {
        modifier(CardModifier())
    }
}

struct PhotoPickerCard: View {
    let title: String
    let subtitle: String
    let image: UIImage?
    let onImage: (UIImage) -> Void
    @State private var selection: PhotosPickerItem?
    @State private var isShowingCamera = false

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selection, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(MommyTheme.panel)
                        .frame(height: 310)

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 310)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay(alignment: .bottom) {
                                Label(
                                    "Tap to choose another",
                                    systemImage: "photo.on.rectangle.angled"
                                )
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(14)
                            }
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 44))
                                .foregroundStyle(MommyTheme.hotPink)
                            Text(title)
                                .font(.title3.weight(.black))
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(28)
                    }
                }
            }
            .buttonStyle(.plain)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            Task {
                guard let data = try? await newValue.loadTransferable(type: Data.self),
                      let selectedImage = UIImage(data: data) else { return }
                onImage(selectedImage)
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker(onImage: onImage)
                .ignoresSafeArea()
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct VotePill: View {
    let label: String
    let state: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.subheadline.weight(.bold))
            Spacer()
            Text(state)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
