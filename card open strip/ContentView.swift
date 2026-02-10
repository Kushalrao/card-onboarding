//
//  ContentView.swift
//  card open strip
//
//  Created by Kushal Yadav on 09/02/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showGradientBg = false
    @State private var envelopeOpacity: Double = 1.0
    @State private var showCard = false
    @State private var lightFlash: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let envW = min(geo.size.width * 0.88, 370)
            let envH = min(geo.size.height * 0.72, 540)
            let cardW = envW * 0.82
            let cardH = cardW / 1.586
            let bodyH = envH * 0.72

            // Compute card's exact screen Y when fully pulled out
            let bodyTop = envH * 0.28
            let bodyCenterY = bodyTop + bodyH / 2
            let slotCenterY = bodyCenterY - bodyH * 0.06
            let lipHeight = cardH * 0.36
            let cardTravel = cardH * 1.1
            let cardCenterInGroup = slotCenterY - lipHeight * 0.35 - cardTravel
            let relToGroupCenter = cardCenterInGroup - envH / 2
            let scaledRel = relToGroupCenter * 0.79
            let cardYInEnvFrame = envH / 2 + scaledRel + 20
            let envFrameTopY = (geo.size.height - envH) / 2
            let cardScreenY = envFrameTopY + cardYInEnvFrame

            ZStack {
                Color(red: 0.96, green: 0.95, blue: 0.93)
                    .ignoresSafeArea()

                if showGradientBg {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.72, blue: 0.22),  // golden amber
                                Color(red: 0.96, green: 0.55, blue: 0.28),  // warm orange
                                Color(red: 0.95, green: 0.30, blue: 0.55),  // hot pink
                                Color(red: 0.82, green: 0.30, blue: 0.72),  // vibrant magenta
                                Color(red: 0.58, green: 0.48, blue: 0.90)   // rich purple
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        // Bright flash that fades out — makes it feel like a ray of light
                        Color.white.opacity(lightFlash)
                    }
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom))
                }

                EnvelopeView(onCardOut: {
                    showCard = true
                    withAnimation(.easeOut(duration: 0.35)) {
                        envelopeOpacity = 0
                    }
                }, onCardNearOut: {
                    lightFlash = 1.0
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showGradientBg = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.8)) {
                            lightFlash = 0
                        }
                    }
                })
                .frame(width: envW, height: envH)
                .opacity(envelopeOpacity)

                // Standalone card that persists after envelope fades
                if showCard {
                    CreditCard(width: cardW, height: cardH)
                        .scaleEffect(1.13)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                        .position(x: geo.size.width / 2, y: cardScreenY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
     }
}

// MARK: - Envelope View

struct EnvelopeView: View {

    var onCardOut: () -> Void = {}
    var onCardNearOut: () -> Void = {}

    @State private var tearProgress: CGFloat = 0     // 0 = sealed, 1 = fully torn (left→right)
    @State private var isTorn: Bool = false
    @State private var flapAngle: CGFloat = 0       // 0 = closed (flat), 180 = fully open
    @State private var isOpen: Bool = false
    @State private var lastHapticStep: Int = 0      // tracks zigzag points for haptic
    @State private var cardPullProgress: CGFloat = 0 // 0 = in pocket, 1 = fully out
    @State private var cardOut: Bool = false

    @State private var lastCardHapticStep: Int = 0
    @State private var openScale: CGFloat = 1.0
    @State private var didFireNearOut: Bool = false

    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let cardHapticGenerator = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let totalH = geo.size.height
            let bodyH = totalH * 0.72
            let flapH = bodyH * 0.62
            let stripH: CGFloat = 44
            let bodyTop = totalH - bodyH

            let envelopeScale = openScale - cardPullProgress * 0.21

            ZStack(alignment: .top) {

                // ==============================
                // ENVELOPE GROUP — scales down when card is pulled
                // ==============================
                ZStack(alignment: .top) {
                    // LAYER 1: Envelope Body
                    EnvelopeBody(width: W, height: bodyH, cardPullProgress: cardPullProgress, openScale: openScale)
                        .offset(y: bodyTop)
                        .zIndex(1)
                        .gesture(
                            isOpen && !cardOut
                            ? DragGesture()
                                .onChanged { value in
                                    let upward = -value.translation.height
                                    guard upward > 0 else { return }

                                    // Initial haptic when card drag starts
                                    if lastCardHapticStep == 0 {
                                        cardHapticGenerator.impactOccurred(intensity: 0.6)
                                    }

                                    // Flatten the flap as card is being pulled
                                    if flapAngle < 180 {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            flapAngle = 180
                                        }
                                    }

                                    let cardH = W * 0.82 / 1.586
                                    cardPullProgress = min(1.0, upward / (cardH * 1.5))

                                    // Slow, minor haptic ticks as card slides out
                                    let step = Int(cardPullProgress * 10)
                                    if step > lastCardHapticStep {
                                        lastCardHapticStep = step
                                        cardHapticGenerator.impactOccurred(intensity: 0.3)
                                    }

                                    // Start gradient before card is fully out
                                    if cardPullProgress > 0.7 && !didFireNearOut {
                                        didFireNearOut = true
                                        onCardNearOut()
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
                                            onCardOut()
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
                    EnvelopeFlap(width: W, height: flapH, angle: flapAngle, fullyOpen: isOpen)
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
                                    flapAngle = min(145, max(0, upward / flapH * 200))
                                    let scaleProgress = max(0, (flapAngle - 90) / 55.0)
                                    openScale = 1.0 + scaleProgress * 0.13
                                }
                                .onEnded { _ in
                                    if flapAngle > 60 {
                                        withAnimation(.spring(response: 0.65, dampingFraction: 0.76)) {
                                            flapAngle = 145
                                            openScale = 1.13
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                            isOpen = true
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                                            flapAngle = 0
                                            openScale = 1.0
                                        }
                                    }
                                }
                            : nil
                        )

                    // LAYER 3: Tear Strip
                    TearStripPeel(width: W, height: stripH, tearProgress: tearProgress)
                        .position(x: W / 2, y: bodyTop + flapH)
                        .zIndex(3)
                        .opacity(isTorn ? 0 : 1)
                        .allowsHitTesting(!isTorn)
                        .gesture(
                            !isTorn
                            ? DragGesture()
                                .onChanged { value in
                                    let rightward = value.translation.width
                                    guard rightward > 0 else { return }
                                    tearProgress = min(1.0, rightward / (W * 0.55))

                                    let step = Int(tearProgress * 25)
                                    if step > lastHapticStep {
                                        lastHapticStep = step
                                        hapticGenerator.impactOccurred(intensity: 0.7)
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
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                                flapAngle = 10
                                            }
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                            tearProgress = 0
                                        }
                                    }
                                }
                            : nil
                        )
                }
                .scaleEffect(envelopeScale)
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
    var openScale: CGFloat = 1.0

    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.72, blue: 0.22),  // golden amber
            Color(red: 0.96, green: 0.55, blue: 0.28),  // warm orange
            Color(red: 0.95, green: 0.30, blue: 0.55),  // hot pink
            Color(red: 0.82, green: 0.30, blue: 0.72),  // vibrant magenta
            Color(red: 0.58, green: 0.48, blue: 0.90)   // rich purple
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
                     cardPullProgress: cardPullProgress, openScale: openScale)
                .offset(y: -height * 0.06)

            // Small text
            Text("Your exclusive card is enclosed.\nHandle with care.")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .offset(y: (slotH / 2) + 20 - height * 0.06)

            // Bottom logo
            Text("Scapia Card")
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
    var openScale: CGFloat = 1.0

    private let pocketGradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.72, blue: 0.22).opacity(0.85),  // golden amber
            Color(red: 0.95, green: 0.30, blue: 0.55).opacity(0.85),  // hot pink
            Color(red: 0.82, green: 0.30, blue: 0.72).opacity(0.85),  // vibrant magenta
            Color(red: 0.58, green: 0.48, blue: 0.90).opacity(0.85)   // rich purple
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
            // Counter-scale only compensates for card-pull shrink, not the open scale
            let envelopeScale = openScale - cardPullProgress * 0.21
            let counterScale = envelopeScale > 0.01 ? openScale / envelopeScale : 1.0

            CreditCard(width: cardWidth, height: cardHeight, shimmer: cardPullProgress)
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
                .fill(Color(red: 0.85, green: 0.85, blue: 0.88).opacity(0.55))
                .background(.ultraThinMaterial)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 0
                ))
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
    var shimmer: CGFloat = 0

    var body: some View {
        let chipW = width * 0.16
        let chipH = chipW * 0.72

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.96, blue: 0.97),
                            Color(red: 0.91, green: 0.91, blue: 0.93),
                            Color(red: 0.94, green: 0.94, blue: 0.95),
                            Color(red: 0.88, green: 0.88, blue: 0.91)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )

            // EMV Chip
            ChipView(width: chipW, height: chipH, shimmer: shimmer)
                .offset(x: width * 0.12, y: height * 0.3)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - EMV Chip

struct ChipView: View {
    let width: CGFloat
    let height: CGFloat
    var shimmer: CGFloat = 0

    var body: some View {
        let chipGradient = LinearGradient(
            colors: [
                Color(red: 0.78, green: 0.74, blue: 0.65),
                Color(red: 0.85, green: 0.82, blue: 0.72),
                Color(red: 0.90, green: 0.87, blue: 0.78),
                Color(red: 0.82, green: 0.78, blue: 0.68)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        ZStack {
            // Base
            RoundedRectangle(cornerRadius: width * 0.15)
                .fill(chipGradient)

            // Shimmer overlay when card moves
            if shimmer > 0 {
                RoundedRectangle(cornerRadius: width * 0.15)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(Double(shimmer) * 0.5),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Chip line pattern
            Canvas { context, size in
                let lw: CGFloat = 0.8
                let r = size.width * 0.15
                let cx = size.width / 2
                let cy = size.height / 2

                // Vertical center line
                var vLine = Path()
                vLine.move(to: CGPoint(x: cx, y: 0))
                vLine.addLine(to: CGPoint(x: cx, y: size.height))
                context.stroke(vLine, with: .color(.white.opacity(0.55)), lineWidth: lw)

                // Horizontal center line
                var hLine = Path()
                hLine.move(to: CGPoint(x: 0, y: cy))
                hLine.addLine(to: CGPoint(x: size.width, y: cy))
                context.stroke(hLine, with: .color(.white.opacity(0.55)), lineWidth: lw)

                // Left curved lines
                var leftTop = Path()
                leftTop.move(to: CGPoint(x: 0, y: cy * 0.45))
                leftTop.addQuadCurve(to: CGPoint(x: cx * 0.55, y: 0),
                                     control: CGPoint(x: cx * 0.15, y: cy * 0.1))
                context.stroke(leftTop, with: .color(.white.opacity(0.4)), lineWidth: lw)

                var leftBot = Path()
                leftBot.move(to: CGPoint(x: 0, y: cy * 1.55))
                leftBot.addQuadCurve(to: CGPoint(x: cx * 0.55, y: size.height),
                                     control: CGPoint(x: cx * 0.15, y: cy * 1.9))
                context.stroke(leftBot, with: .color(.white.opacity(0.4)), lineWidth: lw)

                // Right curved lines
                var rightTop = Path()
                rightTop.move(to: CGPoint(x: size.width, y: cy * 0.45))
                rightTop.addQuadCurve(to: CGPoint(x: cx * 1.45, y: 0),
                                      control: CGPoint(x: cx * 1.85, y: cy * 0.1))
                context.stroke(rightTop, with: .color(.white.opacity(0.4)), lineWidth: lw)

                var rightBot = Path()
                rightBot.move(to: CGPoint(x: size.width, y: cy * 1.55))
                rightBot.addQuadCurve(to: CGPoint(x: cx * 1.45, y: size.height),
                                      control: CGPoint(x: cx * 1.85, y: cy * 1.9))
                context.stroke(rightBot, with: .color(.white.opacity(0.4)), lineWidth: lw)
            }

            // Border
            RoundedRectangle(cornerRadius: width * 0.15)
                .stroke(Color(red: 0.70, green: 0.66, blue: 0.58).opacity(0.6), lineWidth: 0.8)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Envelope Flap

struct EnvelopeFlap: View {
    let width: CGFloat
    let height: CGFloat
    let angle: CGFloat
    var fullyOpen: Bool = false

    private let outsideGradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.72, blue: 0.22),  // golden amber
            Color(red: 0.96, green: 0.55, blue: 0.28),  // warm orange
            Color(red: 0.95, green: 0.30, blue: 0.55),  // hot pink
            Color(red: 0.82, green: 0.30, blue: 0.72),  // vibrant magenta
            Color(red: 0.58, green: 0.48, blue: 0.90)   // rich purple
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(insideGradient)

                    FlapText(width: width, fullyOpen: fullyOpen)
                        .offset(y: height * 0.15)
                }
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

// MARK: - Flap Text

struct FlapText: View {
    let width: CGFloat
    var fullyOpen: Bool = false
    @State private var textOpacity: Double = 0.2
    @State private var glowAmount: Double = 0

    var body: some View {
        Text("Scapia Federal\nCredit Card")
            .font(.system(size: width * 0.124, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(textOpacity),
                        .white.opacity(textOpacity * 0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(
                    Text("Scapia Federal\nCredit Card")
                        .font(.system(size: width * 0.124, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                )
            )
            .foregroundColor(.clear)
            .shadow(color: .white.opacity(glowAmount * 0.6), radius: glowAmount * 12)
            .shadow(color: .white.opacity(glowAmount * 0.3), radius: glowAmount * 24)
            .onChange(of: fullyOpen) { _, open in
                if open {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        textOpacity = 1.0
                    }
                    withAnimation(.easeInOut(duration: 2.0).delay(2.0)) {
                        glowAmount = 1.0
                    }
                }
            }
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
            Color(red: 0.96, green: 0.95, blue: 0.92),
            Color(red: 0.94, green: 0.93, blue: 0.89),
            Color(red: 0.95, green: 0.94, blue: 0.90),
            Color(red: 0.93, green: 0.92, blue: 0.88)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(stripGradient)

            // Perforations
            stripPerforations

            // Tear hint (fades as you tear)
            if tearProgress < 0.4 {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .heavy))
                    Text("TEAR")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .tracking(2)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .heavy))
                }
                .foregroundColor(Color(red: 0.55, green: 0.52, blue: 0.48).opacity(Double(0.7 * (1.0 - tearProgress * 2.5))))
            }
        }
        .frame(width: width, height: height)
        .modifier(TearCurlModifier(progress: tearProgress, curlRadius: 0.18))
    }

    private var stripPerforations: some View {
        ZStack {
            PerforatedLine()
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                .foregroundColor(Color(red: 0.75, green: 0.73, blue: 0.70).opacity(0.5))
                .frame(height: 1)
                .offset(y: -height / 2 + 2)

            PerforatedLine()
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                .foregroundColor(Color(red: 0.75, green: 0.73, blue: 0.70).opacity(0.5))
                .frame(height: 1)
                .offset(y: height / 2 - 2)

            PerforatedLine()
                .stroke(style: StrokeStyle(lineWidth: 0.5))
                .foregroundColor(Color(red: 0.75, green: 0.73, blue: 0.70).opacity(0.2))
                .frame(height: 1)
        }
    }
}

// Jagged zigzag edge at the tear point
// MARK: - Tear Curl Modifier (Metal Shader)

struct TearCurlModifier: ViewModifier, Animatable {
    var progress: CGFloat
    var curlRadius: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            view.layerEffect(
                ShaderLibrary.tearCurl(
                    .float2(proxy.size),
                    .float(progress),
                    .float(curlRadius)
                ),
                maxSampleOffset: CGSize(width: proxy.size.width, height: proxy.size.height),
                isEnabled: progress > 0.001
            )
        }
    }
}

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
