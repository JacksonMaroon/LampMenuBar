import SwiftUI

struct LampPopoverView: View {
    @ObservedObject var controller: LampController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Color buttons row
            HStack(spacing: 10) {
                ForEach(LampController.LampColor.allCases, id: \.self) { color in
                    ColorButton(
                        color: color,
                        isSelected: controller.selectedColor == color,
                        action: { controller.setColor(color) }
                    )
                }

                // Power button
                Button(action: { controller.togglePower() }) {
                    ZStack {
                        Circle()
                            .fill(controller.isOn ?
                                  LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom) :
                                  LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 28, height: 28)

                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(controller.isOn ? .white : .gray)
                    }
                }
                .buttonStyle(.plain)
            }

            // Brightness slider
            BrightnessSlider(value: $controller.brightness)
                .onChange(of: controller.brightness) { _, newValue in
                    controller.setBrightness(newValue)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .fixedSize()
    }
}

struct ColorButton: View {
    let color: LampController.LampColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color.gradient)
                .frame(width: 28, height: 28)
                .overlay {
                    if color == .white {
                        Circle()
                            .strokeBorder(.gray.opacity(0.3), lineWidth: 1)
                    }
                }
                .shadow(color: color.color.opacity(isSelected ? 0.6 : 0.3), radius: isSelected ? 6 : 2)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct BrightnessSlider: View {
    @Binding var value: Double
    private let sliderWidth: CGFloat = 280

    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.black, .gray, .yellow.opacity(0.8), .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: sliderWidth, height: 8)

            // Thumb
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(x: thumbOffset())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newValue = gesture.location.x / sliderWidth * 100
                            value = min(max(newValue, 0), 100)
                        }
                )
        }
        .frame(width: sliderWidth, height: 18)
    }

    private func thumbOffset() -> CGFloat {
        let usableWidth = sliderWidth - 18
        return (value / 100) * usableWidth
    }
}

#Preview {
    LampPopoverView(controller: LampController())
        .padding()
}
