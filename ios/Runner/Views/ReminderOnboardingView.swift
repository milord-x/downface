import SwiftUI

struct ReminderOnboardingView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DFColor.cardFillStrong)
                    .frame(width: 96, height: 96)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(DFColor.textPrimary)
            }

            VStack(spacing: 8) {
                Text("stay on your streak")
                    .font(DFType.title)
                    .foregroundStyle(DFColor.textPrimary)

                Text("DownUp can send you one gentle reminder a day if you haven't done a set yet. No spam, easy to turn off anytime.")
                    .multilineTextAlignment(.center)
                    .font(DFType.caption)
                    .foregroundStyle(DFColor.textSecondary)
                    .padding(.horizontal, 32)
            }

            Spacer()

            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 12) {
                    Button {
                        bridge.setRemindersEnabled(true, minutes: bridge.snapshot.reminderMinutes)
                        dismiss()
                    } label: {
                        Text("enable reminders")
                            .font(DFType.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .glassEffectID("primary", in: namespace)

                    Button {
                        bridge.declineReminders()
                        dismiss()
                    } label: {
                        Text("not now")
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
        .background(DFColor.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}
