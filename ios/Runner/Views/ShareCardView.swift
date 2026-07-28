import SwiftUI

struct ShareCardView: View {
    @ObservedObject var bridge = NativeUIBridge.shared
    @Environment(\.dismiss) private var dismiss
    @State private var cardFileURL: URL?

    private var snapshot: AppSnapshot { bridge.snapshot }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                StatCard(
                    reps: snapshot.repsAllTime,
                    streak: snapshot.streak.current,
                    workouts: snapshot.workouts.count
                )
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, DFSpacing.screenPadding)

                Spacer()

                if let cardFileURL {
                    ShareLink(
                        items: [cardFileURL],
                        subject: Text("My DownUp stats"),
                        message: Text("\(snapshot.repsAllTime) push-ups tracked with DownUp \u{2014} the offline push-up counter that watches your face, not a sensor."),
                        preview: { url in
                            SharePreview("DownUp stats", image: Image(uiImage: UIImage(contentsOfFile: url.path) ?? UIImage()))
                        }
                    ) {
                        Text("share")
                            .font(DFType.body.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .padding(.horizontal, DFSpacing.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .background(DFColor.background.ignoresSafeArea())
            .navigationTitle("share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear(perform: renderCard)
        }
    }

    @MainActor
    private func renderCard() {
        let renderer = ImageRenderer(content:
            StatCard(reps: snapshot.repsAllTime, streak: snapshot.streak.current, workouts: snapshot.workouts.count)
                .frame(width: 400, height: 400)
        )
        renderer.scale = 3
        guard let uiImage = renderer.uiImage, let pngData = uiImage.pngData() else { return }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("downface_stats.png")
        try? pngData.write(to: url)
        cardFileURL = url
    }
}

private struct StatCard: View {
    let reps: Int
    let streak: Int
    let workouts: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DOWNUP")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .kerning(2)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(reps)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("total push-ups")
                    .font(DFType.caption)
                    .foregroundStyle(DFColor.textSecondary)
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak) d")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("streak")
                        .font(DFType.caption)
                        .foregroundStyle(DFColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(workouts)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("workouts")
                        .font(DFType.caption)
                        .foregroundStyle(DFColor.textSecondary)
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
