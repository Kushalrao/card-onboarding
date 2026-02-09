//
//  ContentView.swift
//  card open strip
//
//  Created by Kushal Yadav on 09/02/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.96, green: 0.95, blue: 0.93)
                    .ignoresSafeArea()

                EnvelopeView()
                    .frame(
                        width: min(geo.size.width * 0.88, 370),
                        height: min(geo.size.height * 0.72, 540)
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
     }
}

// MARK: - Envelope View

struct EnvelopeView: View {

    @State private var tearProgress: CGFloat = 0     // 0 = sealed, 1 = fully torn (left→right)
    @State private var isTorn: Bool = false
    @State private var flapAngle: CGFloat = 0       // 0 = closed (flat), 180 = fully open
    @State private var isOpen: Bool = false
    @State private var lastHapticStep: Int = 0      // tracks zigzag points for haptic
    @State private var cardPullProgress: CGFloat = 0 // 0 = in pocket, 1 = fully out
    @State private var cardOut: Bool = false

    @State private var lastCardHapticStep: Int = 0

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    private let cardHapticGenerator = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let totalH = geo.size.height
            let bodyH = totalH * 0.72
            let flapH = bodyH * 0.62
            let stripH: CGFloat = 22
            let bodyTop = totalH - bodyH

            let envelopeScale = 1.0 - cardPullProgress * 0.21

            ZStack(alignment: .top) {

                // ==============================
                // ENVELOPE GROUP — scales down when card is pulled
                // ==============================
                ZStack(alignment: .top) {
                    // LAYER 1: Envelope Body
                    EnvelopeBody(width: W, height: bodyH, cardPullProgress: cardPullProgress)
                        .offset(y: bodyTop)
                        .zIndex(1)
                        .gesture(
                            isOpen && !cardOut
                            ? DragGesture()
                                .onChanged { value in
                                    let upward = -value.translation.height
                                    guard upward > 0 else { return }
                                    let cardH = W * 0.82 / 1.586
                                    cardPullProgress = min(1.0, upward / (cardH * 1.5))

                                    // Slow, minor haptic ticks as card slides out
                                    let step = Int(cardPullProgress * 10)
                                    if step > lastCardHapticStep {
                                        lastCardHapticStep = step
                                        cardHapticGenerator.impactOccurred(intensity: 0.3)
                                    }
                                }
                                .onEnded { _ in
                                    lastCardHapticStep = 0
                                    if cardPullProgress > 0.45 {
                                        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                                            cardPullProgress = 1.0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            cardOut = true
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                                            cardPullProgress = 0
                                        }
                                    }
                                }
                            : nil
                        )

                    // LAYER 2: Envelope Flap
                    EnvelopeFlap(width: W, height: flapH, angle: flapAngle)
                        .rotation3DEffect(
                            .degrees(flapAngle),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .top,
                            anchorZ: 0,
                            perspective: 0.35
                        )
                        .offset(y: bodyTop)
                        .zIndex(flapAngle > 90 ? -1 : 2)
                        .gesture(
                            isTorn && !isOpen
                            ? DragGesture()
                                .onChanged { value in
                                    let upward = -value.translation.height
                                    guard upward > 0 else { return }
                                    flapAngle = min(180, max(0, upward / flapH * 200))
                                }
                                .onEnded { _ in
                                    if flapAngle > 75 {
                                        withAnimation(.spring(response: 0.65, dampingFraction: 0.76)) {
                                            flapAngle = 180
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                            isOpen = true
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                                            flapAngle = 0
                                        }
                                    }
                                }
                            : nil
                        )

                    // LAYER 3: Tear Strip
                    if !isTorn {
                        TearStripPeel(width: W, height: stripH, tearProgress: tearProgress)
                            .position(x: W / 2, y: bodyTop + flapH)
                            .zIndex(3)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let rightward = value.translation.width
                                        guard rightward > 0 else { return }
                                        tearProgress = min(1.0, rightward / (W * 0.55))

                                        let step = Int(tearProgress * 25)
                                        if step > lastHapticStep {
                                            lastHapticStep = step
                                            hapticGenerator.impactOccurred(intensity: 0.4)
                                        }
                                    }
                                    .onEnded { _ in
                                        lastHapticStep = 0
                                        if tearProgress > 0.5 {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                                tearProgress = 1.0
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                withAnimation(.easeOut(duration: 0.15)) {
                                                    isTorn = true
                                                }
                                            }
                                        } else {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                                tearProgress = 0
                                            }
                                        }
                                    }
                            )
                    }
                }
                .scaleEffect(envelopeScale)
                .offset(y: cardPullProgress * 20)
                .shadow(color: .black.opacity(0.12), radius: 28, x: 0, y: 14)
            }
            .frame(width: W, height: totalH)
        }
    }
}

// MARK: - Envelope Body

struct EnvelopeBody: View {
    let width: CGFloat
    let height: CGFloat
    var cardPullProgress: CGFloat = 0

    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.55, blue: 0.30),  // warm orange
            Color(red: 0.95, green: 0.40, blue: 0.45),  // coral/red
            Color(red: 0.85, green: 0.35, blue: 0.62),  // pink
            Color(red: 0.62, green: 0.40, blue: 0.78),  // purple
            Color(red: 0.45, green: 0.50, blue: 0.85)   // blue
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    var body: some View {
        // Credit card standard ratio: 85.6mm × 53.98mm = 1.586:1
        let cardW = width * 0.82
        let cardH = cardW / 1.586      // proper credit card height
        let slotW = cardW + 24         // slot is slightly larger than card
        let slotH = cardH + 20

        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(gradient)
                .frame(width: width, height: height)

            // Card slot with proper credit card proportions
            CardSlot(width: slotW, height: slotH, cardWidth: cardW, cardHeight: cardH,
                     cardPullProgress: cardPullProgress)
                .offset(y: -height * 0.06)

            // Small text
            Text("Your exclusive card is enclosed.\nHandle with care.")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .offset(y: (slotH / 2) + 20 - height * 0.06)

            // Bottom logo
            Text("Premium Card")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .italic()
                .offset(y: height * 0.40)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Card Slot

struct CardSlot: View {
    let width: CGFloat
    let height: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var cardPullProgress: CGFloat = 0

    private let pocketGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.55, blue: 0.30).opacity(0.85),
            Color(red: 0.92, green: 0.40, blue: 0.50).opacity(0.85),
            Color(red: 0.72, green: 0.38, blue: 0.70).opacity(0.85),
            Color(red: 0.50, green: 0.45, blue: 0.82).opacity(0.85)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        let lipHeight: CGFloat = cardHeight * 0.36
        let cardTravel = cardHeight * 1.1  // travels to roughly screen center

        ZStack {
            // Pocket inset background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                )
                .frame(width: width, height: height)

            // Card — slides upward as cardPullProgress increases
            // Counter-scale so card stays full size while envelope shrinks
            let envelopeScale = 1.0 - cardPullProgress * 0.21
            let counterScale = envelopeScale > 0.01 ? 1.0 / envelopeScale : 1.0

            CreditCard(width: cardWidth, height: cardHeight)
                .scaleEffect(counterScale)
                .shadow(
                    color: .black.opacity(Double(cardPullProgress * 0.25)),
                    radius: cardPullProgress * 20,
                    x: 0,
                    y: cardPullProgress * 10
                )
                .offset(y: -lipHeight * 0.35 - cardPullProgress * cardTravel)

            // Pocket lip — overlaps the card's bottom edge
            VStack {
                Spacer()
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 0
                )
                .fill(pocketGradient)
                .frame(width: width, height: lipHeight)
                .shadow(color: .black.opacity(0.08), radius: 3, y: -2)
            }
            .frame(width: width, height: height)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Credit Card (85.6 × 53.98mm ratio, clean white/silver)

struct CreditCard: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.96, blue: 0.97),  // near-white
                        Color(red: 0.91, green: 0.91, blue: 0.93),  // light silver
                        Color(red: 0.94, green: 0.94, blue: 0.95),  // silver highlight
                        Color(red: 0.88, green: 0.88, blue: 0.91)   // slightly darker silver
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Subtle inner shine
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - Envelope Flap

struct EnvelopeFlap: View {
    let width: CGFloat
    let height: CGFloat
    let angle: CGFloat

    private let outsideGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.55, blue: 0.30),
            Color(red: 0.95, green: 0.40, blue: 0.45),
            Color(red: 0.85, green: 0.35, blue: 0.62),
            Color(red: 0.62, green: 0.40, blue: 0.78),
            Color(red: 0.45, green: 0.50, blue: 0.85)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    private let insideGradient = LinearGradient(
        colors: [
            Color(red: 0.30, green: 0.82, blue: 0.42),
            Color(red: 0.40, green: 0.75, blue: 0.55),
            Color(red: 0.55, green: 0.60, blue: 0.75),
            Color(red: 0.50, green: 0.48, blue: 0.88),
            Color(red: 0.78, green: 0.78, blue: 0.92)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    var body: some View {
        ZStack {
            if angle <= 90 {
                // Outside face — same gradient as body, seamless when closed
                RoundedRectangle(cornerRadius: 2)
                    .fill(outsideGradient)
            } else {
                // Inside face — green/blue, visible when flap is open
                RoundedRectangle(cornerRadius: 2)
                    .fill(insideGradient)
                    .scaleEffect(y: -1)
            }
        }
        .frame(width: width, height: height)
        .shadow(
            color: .black.opacity(angle > 3 ? 0.10 : 0),
            radius: 5,
            y: 3
        )
    }
}

// MARK: - Tear Strip (Progressive Peel)

/// Two-part strip: stuck portion (right of tear line, stays flat)
/// and peeling curl (at tear line, lifting up). Like the banknote fold
/// from the reference project but horizontal.
struct TearStripPeel: View {
    let width: CGFloat
    let height: CGFloat
    let tearProgress: CGFloat

    private let stripGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.55, blue: 0.38),
            Color(red: 0.92, green: 0.42, blue: 0.52),
            Color(red: 0.78, green: 0.38, blue: 0.68),
            Color(red: 0.55, green: 0.45, blue: 0.82)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        let tearX = tearProgress * width

        ZStack(alignment: .leading) {

            // ---- Stuck portion: right of tear line, stays flat ----
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(stripGradient)

                // Perforations
                stripPerforations

                // Pull hint (fades as you tear)
                if tearProgress < 0.4 {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .heavy))
                        Text("PULL")
                            .font(.system(size: 7, weight: .heavy, design: .rounded))
                            .tracking(2)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .heavy))
                    }
                    .foregroundColor(.white.opacity(Double(0.55 * (1.0 - tearProgress * 2.5))))
                }
            }
            .frame(width: width, height: height)
            .mask(
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: max(0, tearX))
                    Color.white
                }
                .frame(width: width)
            )

            // ---- Peeling curl: at the tear line, lifting and curling ----
            if tearProgress > 0.01 {
                let curlWidth: CGFloat = min(tearX + 8, 38)
                let liftAmount = min(tearProgress * 18, 14.0)
                let curlAngle = min(Double(tearProgress) * 100, 60.0)

                RoundedRectangle(cornerRadius: 2)
                    .fill(stripGradient)
                    .overlay(
                        // Slight highlight on the curl for 3D feel
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    )
                    .frame(width: curlWidth, height: height)
                    .shadow(
                        color: .black.opacity(Double(min(tearProgress * 0.3, 0.2))),
                        radius: tearProgress * 5,
                        x: -tearProgress * 2,
                        y: tearProgress * 4
                    )
                    .rotation3DEffect(
                        .degrees(-curlAngle),
                        axis: (x: 0.12, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.5
                    )
                    .offset(
                        x: max(0, tearX - curlWidth + 4),
                        y: -liftAmount
                    )
                    .opacity(tearProgress > 0.85 ? Double(1.0 - (tearProgress - 0.85) * 6.7) : 1.0)
            }

            // ---- Jagged tear edge at the peel line ----
            if tearProgress > 0.03 && tearProgress < 0.95 {
                TearEdge(height: height)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 4, height: height)
                    .offset(x: tearX - 2)
            }
        }
        .frame(width: width, height: height)
    }

    private var stripPerforations: some View {
        ZStack {
            PerforatedLine()
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                .foregroundColor(.white.opacity(0.45))
                .frame(height: 1)
                .offset(y: -height / 2 + 2)

            PerforatedLine()
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                .foregroundColor(.white.opacity(0.45))
                .frame(height: 1)
                .offset(y: height / 2 - 2)

            PerforatedLine()
                .stroke(style: StrokeStyle(lineWidth: 0.5))
                .foregroundColor(.white.opacity(0.15))
                .frame(height: 1)
        }
    }
}

// Jagged zigzag edge at the tear point
struct TearEdge: Shape {
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 3
        let segments = Int(height / step)
        path.move(to: CGPoint(x: rect.midX, y: 0))

        for i in 0..<segments {
            let y = CGFloat(i) * step
            let x: CGFloat = (i % 2 == 0) ? rect.maxX : 0
            path.addLine(to: CGPoint(x: x, y: y + step / 2))
            path.addLine(to: CGPoint(x: rect.midX, y: y + step))
        }
        return path
    }
}

// MARK: - Helpers

struct PerforatedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#Preview {
    ContentView()
}
