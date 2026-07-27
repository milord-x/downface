import SwiftUI

struct WorkoutView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @Namespace private var namespace
    @State private var showCancelConfirm = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            DFColor.background.ignoresSafeArea()

            switch bridge.workoutState {
            case .ready(let supported):
                ReadyStateView(supported: supported, namespace: namespace) {
                    bridge.startWorkoutSet()
                }
            case .tracking(let reps):
                TrackingStateView(reps: reps, namespace: namespace) {
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
            case .finished(let totalReps, let sets):
                FinishedStateView(totalReps: totalReps, sets: sets, namespace: namespace) {
                    dismiss()
                }
            }

            if !isFinishedState {
                CloseButton {
                    if isReadyState {
                        dismiss()
                    } else {
                        showCancelConfirm = true
                    }
                }
                .padding(.top, 8)
                .padding(.leading, DFSpacing.screenPadding)
            }
        }
        .animation(.smooth, value: isTrackingState)
        .alert("Discard this workout?", isPresented: $showCancelConfirm) {
            Button("Keep going", role: .cancel) {}
            Button("Discard", role: .destructive) {
                bridge.cancelWorkout()
                dismiss()
            }
        } message: {
            Text("Your progress in this session won't be saved.")
        }
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
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
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
                GlassEffectContainer(spacing: 16) {
                    Button {
                        onStart()
                    } label: {
                        Text("begin set")
                            .font(DFType.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .glassEffectID("primary", in: namespace)
                }
                .padding(.horizontal, DFSpacing.screenPadding)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct TrackingStateView: View {
    let reps: Int
    let namespace: Namespace.ID
    let onEndSet: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Text("\(reps)")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(DFColor.textPrimary)
                .contentTransition(.numericText())

            Text("reps")
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)

            Spacer()

            GlassEffectContainer(spacing: 16) {
                Button {
                    onEndSet()
                } label: {
                    Text("end set")
                        .font(DFType.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .glassEffectID("primary", in: namespace)
            }
            .padding(.horizontal, DFSpacing.screenPadding)
            .padding(.bottom, 24)
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

            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 12) {
                    Button {
                        onNext()
                    } label: {
                        Text("next set")
                            .font(DFType.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .glassEffectID("primary", in: namespace)

                    Button {
                        onFinish()
                    } label: {
                        Text("finish workout")
                            .font(DFType.body)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("secondary", in: namespace)
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
    let namespace: Namespace.ID
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DFColor.textPrimary)
                .padding(.bottom, 12)

            Text("\(totalReps) reps")
                .font(DFType.number)
                .foregroundStyle(DFColor.textPrimary)

            Text("\(sets) sets logged")
                .font(DFType.caption)
                .foregroundStyle(DFColor.textSecondary)

            Spacer()

            GlassEffectContainer(spacing: 16) {
                Button {
                    onDone()
                } label: {
                    Text("done")
                        .font(DFType.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .glassEffectID("primary", in: namespace)
            }
            .padding(.horizontal, DFSpacing.screenPadding)
            .padding(.bottom, 24)
        }
    }
}
