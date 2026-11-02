import SwiftUI
import UIKit

/// The team's choices, one per topic, ready to share.
struct PlaybookView: View {
    @Environment(DecisionStore.self) private var decisions
    @Environment(AppRouter.self) private var router
    @State private var editing: LabID?
    @State private var confirmsClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your choices for the team. Add a short reason to any of them, then share the list.")
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(decisions.decidedCount), total: Double(LabID.allCases.count)) {
                            Text("\(decisions.decidedCount) of \(LabID.allCases.count) chosen")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    ForEach(LabID.allCases) { lab in
                        Button {
                            if decisions.decision(for: lab) != nil { editing = lab } else { router.openTopic(lab) }
                        } label: {
                            PlaybookRow(lab: lab)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Playbook")
            .toolbar {
                ToolbarItem {
                    ShareLink(item: decisions.markdown(), subject: Text("iPhone Duo playbook")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem {
                    Menu("More", systemImage: "ellipsis") {
                        Button("Copy as text", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = decisions.markdown()
                        }
                        Button("Clear all choices", systemImage: "trash", role: .destructive) { confirmsClear = true }
                            .disabled(decisions.decidedCount == 0)
                    }
                }
            }
            .confirmationDialog("Clear all \(decisions.decidedCount) choices?", isPresented: $confirmsClear, titleVisibility: .visible) {
                Button("Clear all", role: .destructive) { decisions.clearAll() }
            }
            .sheet(item: $editing) { lab in ChoiceEditor(lab: lab) }
        }
    }
}

struct PlaybookRow: View {
    let lab: LabID
    @Environment(DecisionStore.self) private var decisions

    var body: some View {
        let decision = decisions.decision(for: lab)
        let option = decision.flatMap { lab.option($0.optionID) }
        HStack(alignment: .center, spacing: 14) {
            Group {
                if let option {
                    OptionThumbnail(lab: lab, option: option, pose: .open, tweaks: decision?.tweaks ?? [:])
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                        .aspectRatio(951 / 669, contentMode: .fit)
                        .overlay { Image(systemName: lab.symbol).font(.title3).foregroundStyle(.secondary) }
                }
            }
            .frame(width: 104)
            VStack(alignment: .leading, spacing: 3) {
                Text(lab.title).font(.subheadline).foregroundStyle(.secondary)
                if let option {
                    Text(option.title).font(.headline)
                    if let why = decision?.rationale, !why.isEmpty {
                        Text(why).font(.subheadline)
                    } else {
                        Text("Add a reason").font(.subheadline).foregroundStyle(.tint)
                    }
                } else {
                    Text("Not chosen yet").font(.headline).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

/// The reason for one choice, plus ways to revisit or drop it.
private struct ChoiceEditor: View {
    let lab: LabID
    @Environment(DecisionStore.self) private var decisions
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""

    var body: some View {
        let option = decisions.chosenOption(for: lab)
        NavigationStack {
            Form {
                if let option {
                    Section {
                        OptionThumbnail(lab: lab, option: option, pose: .open,
                                        tweaks: decisions.decision(for: lab)?.tweaks ?? [:])
                            .listRowInsets(EdgeInsets())
                    }
                    Section {
                        TextField("Why this one?", text: $reason, axis: .vertical)
                            .lineLimit(2...5)
                    } header: {
                        Text("Reason")
                    } footer: {
                        Text("Shown next to the choice when you share the playbook.")
                    }
                    Section {
                        Button("Try it again", systemImage: "play.rectangle") {
                            dismiss()
                            router.tab = .topics
                            router.preview = PreviewTarget(lab: lab, optionID: option.id,
                                                           knobs: decisions.decision(for: lab)?.tweaks ?? [:])
                        }
                        Button("Remove this choice", systemImage: "xmark.circle", role: .destructive) {
                            decisions.clear(lab)
                            dismiss()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(option?.title ?? lab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        decisions.setRationale(reason.trimmingCharacters(in: .whitespacesAndNewlines), for: lab)
                        dismiss()
                    }
                }
            }
        }
        .onAppear { reason = decisions.decision(for: lab)?.rationale ?? "" }
    }
}
