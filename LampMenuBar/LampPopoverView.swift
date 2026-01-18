import SwiftUI

struct LampPopoverView: View {
    @ObservedObject var controller: LampController

    var body: some View {
        let swatchSize: CGFloat = 28
        let swatchSpacing: CGFloat = 10
        let swatchCount = CGFloat(LampController.LampColor.allCases.count)
        let sliderWidth = (swatchCount * swatchSize) + ((swatchCount - 1) * swatchSpacing)
        let powerSize: CGFloat = 42

        HStack(spacing: 14) {
            // Power button
            Button(action: { controller.togglePower() }) {
                ZStack {
                    Circle()
                        .fill(controller.isOn ?
                              LinearGradient(colors: [.gray.opacity(0.22), .gray.opacity(0.12)], startPoint: .top, endPoint: .bottom) :
                              LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                        .frame(width: powerSize, height: powerSize)

                    Group {
                        Circle()
                            .stroke(Color.yellow.opacity(0.55), lineWidth: 3)
                            .blur(radius: 2)
                            .frame(width: powerSize, height: powerSize)

                        Circle()
                            .stroke(Color.orange.opacity(0.35), lineWidth: 8)
                            .blur(radius: 7)
                            .frame(width: powerSize, height: powerSize)
                            .scaleEffect(1.08)

                        Circle()
                            .stroke(Color.yellow.opacity(0.2), lineWidth: 12)
                            .blur(radius: 10)
                            .frame(width: powerSize, height: powerSize)
                            .scaleEffect(1.18)
                    }
                    .opacity(controller.isOn ? 1 : 0)

                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(controller.isOn ? .white : .gray)
                        .shadow(color: controller.isOn ? Color.yellow.opacity(0.6) : .clear, radius: 6)
                }
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 44)
                .opacity(0.4)

            VStack(alignment: .leading, spacing: 12) {
                // Color buttons row
                HStack(spacing: swatchSpacing) {
                    ForEach(LampController.LampColor.allCases, id: \.self) { color in
                        ColorButton(
                            color: color,
                            isSelected: controller.selectedColor == color,
                            action: { controller.setColor(color) }
                        )
                    }
                }

                // Brightness slider
                BrightnessSlider(
                    value: $controller.brightness,
                    width: sliderWidth,
                    selectedColor: controller.selectedColor,
                    onBegin: { controller.cancelPendingBrightnessCommit() },
                    onCommit: { controller.commitBrightness($0) }
                )
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
    let width: CGFloat
    let selectedColor: LampController.LampColor
    let onBegin: () -> Void
    let onCommit: (Double) -> Void
    @State private var isDragging = false

    private var trackColors: [Color] {
        if selectedColor == .white {
            return [
                Color.black,
                Color.gray.opacity(0.45),
                Color.white.opacity(0.85),
                Color.white
            ]
        }

        let hsv = selectedColor.hsv
        let hue = Double(hsv.h) / 180.0
        let sat = Double(hsv.s) / 100.0
        return [
            Color(hue: hue, saturation: sat * 0.25, brightness: 0.12),
            Color(hue: hue, saturation: sat * 0.45, brightness: 0.35),
            Color(hue: hue, saturation: sat * 0.7, brightness: 0.65),
            Color(hue: hue, saturation: sat * 0.9, brightness: 0.95)
        ]
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            Capsule()
                .fill(
                    LinearGradient(
                        colors: trackColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 8)

            // Thumb
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(x: thumbOffset())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                onBegin()
                            }
                            let newValue = gesture.location.x / width * 100
                            value = min(max(newValue, 0), 100)
                        }
                        .onEnded { _ in
                            isDragging = false
                            onCommit(value)
                        }
                )
        }
        .frame(width: width, height: 18)
    }

    private func thumbOffset() -> CGFloat {
        let usableWidth = width - 18
        return (value / 100) * usableWidth
    }
}

#Preview {
    LampPopoverView(controller: LampController())
        .padding()
}
