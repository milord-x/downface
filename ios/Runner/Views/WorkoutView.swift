import SwiftUI
import UIKit

struct WorkoutView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @Namespace private var namespace
    @State private var showCancelConfirm = false
    @State private var lightBoostOn = false
    @State private var savedBrightness: CGFloat = Self.currentScreen?.brightness ?? 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            DFColor.background.ignoresSafeArea()

            if lightBoostOn {
                FaceLightBoost()
                    .transition(.opacity)
            }

            switch bridge.workoutState {
            case .ready(let supported):
                ReadyStateView(supported: supported, namespace: namespace) {
                    bridge.startWorkoutSet()
                }
            case .tracking(let reps, let fatigued):
                TrackingStateView(reps: reps, fatigued: fatigued, namespace: namespace) {
                    bridge.endWorkoutSet()
                }
            case .resting(let seconds, let setsSoFar):
                RestingStateView(
                    seconds: seconds,
                    setsSoFar: setsSoFar,
                    namespace: namespace,
                    onNext: { bridge.startWorkoutSet() },
                    onFinish: { bridge.finishWorkout() }
                )
            case .finished(let totalReps, let sets, let newBestSet, let newBestDay):
                FinishedStateView(totalReps: totalReps, sets: sets, newBestSet: newBestSet, newBestDay: newBestDay, namespace: namespace) {
                    dismiss()
                }
            }

            if !isFinishedState {
                HStack {
                    CloseButton {
                        if isReadyState {
                            dismiss()
                        } else {
                            showCancelConfirm = true
                        }
                    }

                    Spacer()

                    LightBoostButton(isOn: lightBoostOn) {
                        toggleLightBoost()
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, DFSpacing.screenPadding)
            }
        }
        .animation(.smooth, value: isTrackingState)
        .animation(.smooth, value: lightBoostOn)
        .alert("Discard this workout?", isPresented: $showCancelConfirm) {
            Button("Keep going", role: .cancel) {}
            Button("Discard", role: .destructive) {
                bridge.cancelWorkout()
                dismiss()
            }
        } message: {
            Text("Your progress in this session won't be saved.")
        }
        .onDisappear {
            if lightBoostOn {
                Self.currentScreen?.brightness = savedBrightness
            }
        }
    }

    /// UIScreen.main is deprecated in favor of reading the screen off the
    /// active window scene.
    private static var currentScreen: UIScreen? {
        (UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)?.screen
    }

    private func toggleLightBoost() {
        guard let screen = Self.currentScreen else { return }
        if lightBoostOn {
            screen.brightness = savedBrightness
        } else {
            savedBrightness = screen.brightness
            screen.brightness = 1.0
        }
        lightBoostOn.toggle()
    }

    private var isReadyState: Bool {
        if case .ready = bridge.workoutState { return true }
        return false
    }

    private var isFinishedState: Bool {
        if case .finished = bridge.workoutState { return true }
        return false
    }

    private var isTrackingState: Int {
        switch bridge.workoutState {
        case .ready: return 0
        case .tracking: return 1
        case .resting: return 2
        case .finished: return 3
        }
    }
}

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DFColor.textPrimary)
                .frame(width: 40, height: 40)
        }
        .dfCircleButtonStyle()
    }
}

private struct LightBoostButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        let label = Image(systemName: isOn ? "sun.max.fill" : "sun.max")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isOn ? .black : DFColor.textPrimary)
            .frame(width: 40, height: 40)

        Button(action: action) { label }
            .dfCircleButtonStyle(prominent: isOn)
    }
}

/// A soft white glow hugging the screen's own rounded-corner contour,
/// standing in for a ring light so the TrueDepth camera's low-light face
/// tracking has more to work with. A single stroked, blurred outline
/// follows the screen shape continuously – no seams at the corners, no
/// flat rectangle cutting across a rounded display – fading to nothing a
/// short distance in so it never washes out the UI in the center.
private struct FaceLightBoost: View {
    var body: some View {
        GeometryReader { geo in
            let shape = RoundedRectangle(cornerRadius: 55, style: .continuous)

            ZStack {
                shape
                    .stroke(Color.white, lineWidth: 90)
                    .blur(radius: 40)
                    .opacity(0.85)

                shape
                    .stroke(Color.white, lineWidth: 30)
                    .blur(radius: 16)
                    .opacity(0.6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .compositingGroup()
            .clipShape(shape)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct ReadyStateView: View {
    let supported: Bool
    let namespace: Namespace.ID
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "iphone.gen3")
                .font(.system(size: 64))
                .foregroundStyle(DFColor.textPrimary)

            VStack(spacing: 8) {
                Text("place your phone on the floor\nscreen facing you")
                    .multilineTextAlignment(.center)
                    .font(DFType.title)
                    .foregroundStyle(DFColor.textPrimary)

                Text("Downface tracks your head with the TrueDepth camera")
                    .multilineTextAlignment(.center)
                    .font(DFType.caption)
                    .foregroundStyle(DFColor.textSecondary)
            }

            Spacer()

            if !supported {
                Text("This device has no TrueDepth camera")
                    .foregroundStyle(DFColor.textSecondary)
                    .padding(.bottom, 40)
            } else {
                DFButtonGroup(spacing: 16) {
                    Button {
                        onStart()
                    } label: {
                        Text("begin set")
                            .font(DFType.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .dfPrimaryButtonStyle()
                    .dfGlassID("primary", in: namespace)
                }
                .padding(.horizontal, DFSpacing.screenPadding)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct TrackingStateView: View {
    let reps: Int
    let fatigued: Bool
    let namespace: Namespace.ID
    let onEndSet: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            ReflectedRepCounter(reps: reps)
            Text("reps")
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)
            Spacer()

            DFButtonGroup(spacing: 16) {
                Button {
                    onEndSet()
                } label: {
                    Text("end set")
                        .font(DFType.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .dfPrimaryButtonStyle()
                .dfGlassID("primary", in: namespace)
            }
            .padding(.horizontal, DFSpacing.screenPadding)
            .padding(.bottom, 24)
        }
        // FatigueNotice floats in its own overlay, anchored to the bottom
        // independent of the VStack's own Spacer-driven layout – sitting it
        // inline between the two Spacers (the previous approach) let the
        // VStack redistribute space around it the moment it appeared,
        // visibly shoving the rep counter upward every time fatigue
        // triggered.
        .overlay(alignment: .bottom) {
            FatigueNotice(fatigued: fatigued)
                .padding(.bottom, 100)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: fatigued)
    }
}

/// The rep count with a faded, flipped duplicate underneath it – like a
/// number standing at the edge of still water – plus a spring-driven pop
/// on every change instead of the flat digit-roll `.numericText()` gives
/// on its own.
private struct ReflectedRepCounter: View {
    let reps: Int
    @State private var popped = false

    var body: some View {
        VStack(spacing: 0) {
            digit
            digit
                .scaleEffect(y: -1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
                .opacity(0.25)
                .offset(y: -8)
        }
        .animation(.default, value: reps)
        .onChange(of: reps) {
            popped = true
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { popped = false }
        }
    }

    private var digit: some View {
        Text("\(reps)")
            .font(.system(size: 96, weight: .heavy, design: .rounded))
            .foregroundStyle(DFColor.textPrimary)
            .contentTransition(.numericText(value: Double(reps)))
            .scaleEffect(popped ? 1.12 : 1)
    }
}

/// Sits inline between the rep count and the "end set" button – never over
/// another control – and reserves no space until fatigue actually
/// triggers, at which point it grows in with the surrounding spring
/// animation on `fatigued` (declared on the parent VStack) rather than a
/// separate opacity/offset transition of its own. Once fatigue is flagged
/// it stays visible for the rest of the set (RepCounter never clears it
/// early), so this never flickers in and out – dismissing it is a single,
/// deliberate action, not something that gets undone by the algorithm.
private struct FatigueNotice: View {
    let fatigued: Bool
    @State private var dismissed = false
    @State private var message = Self.messages.randomElement() ?? Self.messages[0]

    private static let messages = [
        NSLocalizedString("looking tired, take it easy", comment: ""),
        NSLocalizedString("slowing down, maybe rest? \u{1F494}", comment: ""),
        NSLocalizedString("form's slipping, breathe", comment: ""),
        NSLocalizedString("you've earned a break", comment: ""),
        NSLocalizedString("easy now, no rush \u{1FAF6}", comment: ""),
        NSLocalizedString("your pace says you're tired", comment: ""),
        NSLocalizedString("a short rest won't hurt \u{1F49B}", comment: ""),
        NSLocalizedString("listen to your body", comment: ""),
        NSLocalizedString("nice effort, ease up a little \u{2728}", comment: ""),
        NSLocalizedString("getting slower, take your time", comment: ""),
    ]

    var body: some View {
        if fatigued && !dismissed {
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DFColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(DFColor.cardFillStrong, in: Capsule())
                .padding(.horizontal, DFSpacing.screenPadding)
                .padding(.bottom, 16)
                .onTapGesture { dismissed = true }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
}

private struct RestingStateView: View {
    let seconds: Int
    let setsSoFar: Int
    let namespace: Namespace.ID
    let onNext: () -> Void
    let onFinish: () -> Void

    private var setsDoneText: String {
        let key = setsSoFar == 1 ? "%lld set done" : "%lld sets done"
        return String(format: NSLocalizedString(key, comment: ""), setsSoFar)
    }

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Text("\(seconds)s")
                .font(DFType.number)
                .foregroundStyle(DFColor.textPrimary)
                .contentTransition(.numericText())

            Text("\(NSLocalizedString("rest", comment: "")) · \(setsDoneText)")
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)

            Spacer()

            DFButtonGroup(spacing: 16) {
                VStack(spacing: 12) {
                    Button {
                        onNext()
                    } label: {
                        Text("next set")
                            .font(DFType.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .dfPrimaryButtonStyle()
                    .dfGlassID("primary", in: namespace)

                    Button {
                        onFinish()
                    } label: {
                        Text("finish workout")
                            .font(DFType.body)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .dfSecondaryButtonStyle()
                    .dfGlassID("secondary", in: namespace)
                }
            }
            .padding(.horizontal, DFSpacing.screenPadding)
            .padding(.bottom, 24)
        }
    }
}

private struct FinishedStateView: View {
    let totalReps: Int
    let sets: Int
    let newBestSet: Bool
    let newBestDay: Bool
    let namespace: Namespace.ID
    let onDone: () -> Void

    @State private var badgeVisible = false

    private var totalRepsText: String {
        let key = totalReps == 1 ? "%lld rep" : "%lld reps"
        return String(format: NSLocalizedString(key, comment: ""), totalReps)
    }

    private var setsLoggedText: String {
        let key = sets == 1 ? "%lld set logged" : "%lld sets logged"
        return String(format: NSLocalizedString(key, comment: ""), sets)
    }

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            if newBestSet || newBestDay {
                PersonalRecordBadge(newBestSet: newBestSet, newBestDay: newBestDay)
                    .scaleEffect(badgeVisible ? 1 : 0.6)
                    .opacity(badgeVisible ? 1 : 0)
                    .padding(.bottom, 8)
                    .onAppear {
                        withAnimation(.bouncy.delay(0.2)) { badgeVisible = true }
                    }
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DFColor.textPrimary)
                .padding(.bottom, 12)

            Text(totalRepsText)
                .font(DFType.number)
                .foregroundStyle(DFColor.textPrimary)

            Text(setsLoggedText)
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)

            Spacer()

            DFButtonGroup(spacing: 16) {
                Button {
                    NativeUIBridge.shared.pendingRepsFlight = PendingRepsFlight(reps: totalReps)
                    onDone()
                } label: {
                    Text("done")
                        .font(DFType.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .dfPrimaryButtonStyle()
                .dfGlassID("primary", in: namespace)
            }
            .padding(.horizontal, DFSpacing.screenPadding)
            .padding(.bottom, 24)
        }
    }
}

private struct PersonalRecordBadge: View {
    let newBestSet: Bool
    let newBestDay: Bool

    private var text: LocalizedStringKey {
        if newBestSet && newBestDay {
            return "new personal best \u{2013} set and day"
        }
        return newBestSet ? "new personal best \u{2013} single set" : "new personal best \u{2013} single day"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(DFColor.background)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(DFColor.textPrimary, in: Capsule())
    }
}
