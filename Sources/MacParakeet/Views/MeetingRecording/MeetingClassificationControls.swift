import MacParakeetCore
import MacParakeetViewModels
import SwiftUI

struct MeetingRecordingTypePicker: View {
    @Bindable var viewModel: MeetingsWorkspaceViewModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Label(
                viewModel.hasActiveRecording ? "Meeting type" : "Type for next meeting",
                systemImage: "person.2"
            )
            .font(DesignSystem.Typography.caption.weight(.medium))
            .foregroundStyle(DesignSystem.Colors.textSecondary)

            Picker("Meeting type", selection: $viewModel.recordingMeetingTypeID) {
                Text("Unclassified").tag(UUID?.none)
                ForEach(viewModel.meetingClassificationViewModel.meetingTypes) { meetingType in
                    Text(meetingType.name).tag(Optional(meetingType.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 260)
            .accessibilityLabel(
                viewModel.hasActiveRecording ? "Current meeting type" : "Type for next meeting"
            )

            Spacer(minLength: 0)
        }
    }
}

struct MeetingClassificationBadges: View {
    let classification: MeetingClassification?
    var maximumLabels = 2

    var body: some View {
        if let classification,
            classification.meetingType != nil || !classification.labels.isEmpty
        {
            HStack(spacing: 5) {
                if let meetingType = classification.meetingType {
                    badge(
                        meetingType.name,
                        icon: meetingType.iconName ?? "person.2",
                        tint: MeetingClassificationTint.color(for: meetingType.colorToken, fallback: 0),
                        isPrimary: true
                    )
                }

                ForEach(Array(classification.labels.prefix(maximumLabels).enumerated()), id: \.element.id) {
                    index, label in
                    badge(
                        label.name,
                        icon: nil,
                        tint: MeetingClassificationTint.color(for: label.colorToken, fallback: index + 1),
                        isPrimary: false
                    )
                }

                let hiddenCount = classification.labels.count - maximumLabels
                if hiddenCount > 0 {
                    Text("+\(hiddenCount)")
                        .font(DesignSystem.Typography.micro.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .accessibilityLabel("\(hiddenCount) more labels")
                }
            }
        }
    }

    private func badge(_ text: String, icon: String?, tint: Color, isPrimary: Bool) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(DesignSystem.Typography.micro.weight(isPrimary ? .semibold : .medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(tint.opacity(0.11)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 0.5))
        .fixedSize()
    }
}

struct MeetingClassificationFilterBar: View {
    @Bindable var libraryViewModel: TranscriptionLibraryViewModel

    private var classificationViewModel: MeetingClassificationViewModel {
        libraryViewModel.meetingClassificationViewModel
    }

    var body: some View {
        HStack(spacing: 7) {
            typeMenu
            labelMenu

            if libraryViewModel.hasMeetingClassificationFilter {
                Button("Clear") {
                    libraryViewModel.clearMeetingClassificationFilters()
                }
                .buttonStyle(.plain)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .help("Clear meeting type and label filters")
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meeting classification filters")
    }

    private var typeMenu: some View {
        Menu {
            Button {
                libraryViewModel.setUnclassifiedMeetingsFilter(
                    !libraryViewModel.unclassifiedMeetingsOnly
                )
            } label: {
                filterMenuLabel(
                    "Unclassified",
                    selected: libraryViewModel.unclassifiedMeetingsOnly
                )
            }

            if !classificationViewModel.meetingTypes.isEmpty {
                Divider()
                ForEach(classificationViewModel.meetingTypes) { meetingType in
                    Button {
                        libraryViewModel.toggleMeetingTypeFilter(meetingType.id)
                    } label: {
                        filterMenuLabel(
                            meetingType.name,
                            selected: libraryViewModel.selectedMeetingTypeIDs.contains(meetingType.id)
                        )
                    }
                }
            }
        } label: {
            filterButtonLabel(
                title: typeFilterTitle,
                icon: "person.2"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var labelMenu: some View {
        Menu {
            if classificationViewModel.meetingLabels.isEmpty {
                Text("No labels yet")
            } else {
                ForEach(classificationViewModel.meetingLabels) { label in
                    Button {
                        libraryViewModel.toggleMeetingLabelFilter(label.id)
                    } label: {
                        filterMenuLabel(
                            label.name,
                            selected: libraryViewModel.selectedMeetingLabelIDs.contains(label.id)
                        )
                    }
                }
            }
        } label: {
            filterButtonLabel(
                title: labelFilterTitle,
                icon: "tag"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var typeFilterTitle: String {
        if libraryViewModel.unclassifiedMeetingsOnly { return "Unclassified" }
        let count = libraryViewModel.selectedMeetingTypeIDs.count
        return count == 0 ? "All types" : "Types · \(count)"
    }

    private var labelFilterTitle: String {
        let count = libraryViewModel.selectedMeetingLabelIDs.count
        return count == 0 ? "All labels" : "Labels · \(count)"
    }

    private func filterButtonLabel(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(DesignSystem.Typography.caption.weight(.medium))
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.surfaceElevated)
                    .overlay(Capsule().strokeBorder(DesignSystem.Colors.border, lineWidth: 0.5))
            )
    }

    private func filterMenuLabel(_ text: String, selected: Bool) -> some View {
        Label(text, systemImage: selected ? "checkmark" : "circle")
    }
}

struct MeetingClassificationEditor: View {
    let transcription: Transcription
    @Bindable var viewModel: MeetingClassificationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newTypeName = ""
    @State private var newLabelName = ""

    private var classification: MeetingClassification {
        viewModel.classification(for: transcription.id)
            ?? MeetingClassification(meetingType: nil, labels: [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Classify Meeting")
                        .font(DesignSystem.Typography.sectionTitle)
                    Text(transcription.effectiveDisplayTitle)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .parakeetAction(.secondary)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Meeting type")
                    .font(DesignSystem.Typography.bodySmall.weight(.semibold))

                Picker("Meeting type", selection: meetingTypeBinding) {
                    Text("Unclassified").tag(UUID?.none)
                    if let assignedType = classification.meetingType,
                        !viewModel.meetingTypes.contains(where: { $0.id == assignedType.id })
                    {
                        Text("\(assignedType.name) (Archived)").tag(Optional(assignedType.id))
                    }
                    ForEach(viewModel.meetingTypes) { meetingType in
                        Text(meetingType.name).tag(Optional(meetingType.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                if !viewModel.meetingTypes.isEmpty {
                    Menu("Manage types") {
                        ForEach(viewModel.meetingTypes) { meetingType in
                            Button(role: .destructive) {
                                viewModel.archiveMeetingType(meetingType.id)
                            } label: {
                                Label("Archive \(meetingType.name)", systemImage: "archivebox")
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Archive types without changing historical meetings")
                }

                HStack {
                    TextField("New meeting type", text: $newTypeName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(createType)
                    Button("Add", action: createType)
                        .parakeetAction(.secondary)
                        .disabled(newTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Labels")
                    .font(DesignSystem.Typography.bodySmall.weight(.semibold))

                if displayedLabels.isEmpty {
                    Text("Add a label to organize this meeting.")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                } else {
                    FlowLayout(spacing: 7) {
                        ForEach(Array(displayedLabels.enumerated()), id: \.element.id) { index, label in
                            labelToken(label, index: index)
                        }
                    }
                }

                HStack {
                    TextField("New label", text: $newLabelName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(createLabel)
                    Button("Add", action: createLabel)
                        .parakeetAction(.secondary)
                        .disabled(newLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if viewModel.updatingTranscriptionIDs.contains(transcription.id) {
                HStack(spacing: 7) {
                    ParakeetSpinner(.inline)
                    Text("Saving classification…")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.errorRed)
            }

            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(width: 440, height: 430)
        .background(DesignSystem.Colors.contentBackground)
        .onAppear {
            viewModel.loadOptions()
            viewModel.loadClassification(for: transcription.id)
        }
    }

    private var meetingTypeBinding: Binding<UUID?> {
        Binding(
            get: { classification.meetingType?.id },
            set: { viewModel.setMeetingType($0, for: transcription.id) }
        )
    }

    private var displayedLabels: [MeetingLabel] {
        let availableIDs = Set(viewModel.meetingLabels.map(\.id))
        let assignedArchived = classification.labels.filter { !availableIDs.contains($0.id) }
        return viewModel.meetingLabels + assignedArchived
    }

    private func labelToken(_ label: MeetingLabel, index: Int) -> some View {
        let selected = classification.labels.contains { $0.id == label.id }
        let tint = MeetingClassificationTint.color(for: label.colorToken, fallback: index + 1)
        return Button {
            viewModel.toggleLabel(label.id, for: transcription.id)
        } label: {
            HStack(spacing: 5) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label.name)
            }
            .font(DesignSystem.Typography.caption.weight(.medium))
            .foregroundStyle(selected ? tint : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(selected ? tint.opacity(0.13) : DesignSystem.Colors.surfaceElevated))
            .overlay(Capsule().strokeBorder(selected ? tint.opacity(0.35) : DesignSystem.Colors.border, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.name)
        .accessibilityValue(selected ? "Assigned" : "Not assigned")
        .accessibilityHint(selected ? "Removes this label" : "Assigns this label")
        .contextMenu {
            Button(role: .destructive) {
                viewModel.archiveMeetingLabel(label.id)
            } label: {
                Label("Archive Label", systemImage: "archivebox")
            }
        }
    }

    private func createType() {
        let name = newTypeName
        newTypeName = ""
        viewModel.createMeetingType(named: name, assigningTo: transcription.id)
    }

    private func createLabel() {
        let name = newLabelName
        newLabelName = ""
        viewModel.createMeetingLabel(named: name, assigningTo: transcription.id)
    }
}

struct MeetingPromptPolicyEditor: View {
    @Bindable var viewModel: MeetingsWorkspaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeetingTypeID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prompts by Meeting Type")
                        .font(DesignSystem.Typography.sectionTitle)
                    Text("Choose which prompts are available and run automatically for each type.")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .parakeetAction(.secondary)
            }

            Picker("Policy scope", selection: $selectedMeetingTypeID) {
                Text("All meetings (default)").tag(UUID?.none)
                ForEach(viewModel.meetingClassificationViewModel.meetingTypes) { meetingType in
                    Text(meetingType.name).tag(Optional(meetingType.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300, alignment: .leading)

            if hiddenPromptCount > 0 {
                Text(
                    "\(hiddenPromptCount) hidden prompt\(hiddenPromptCount == 1 ? " is" : "s are") not shown. Make them visible in the Prompt Library before assigning meeting policies."
                )
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            if visiblePrompts.isEmpty {
                Text(
                    viewModel.promptsViewModel.prompts.isEmpty
                        ? "No result prompts yet."
                        : "All result prompts are hidden. Make a prompt visible in the Prompt Library to configure it here."
                )
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visiblePrompts) { prompt in
                            policyRow(prompt)
                            Divider()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cardCornerRadius)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                }
            }

            if let errorMessage = viewModel.meetingPolicyErrorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.errorRed)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(width: 640, height: 560)
        .background(DesignSystem.Colors.contentBackground)
        .onAppear { viewModel.refreshAutoNotes() }
    }

    private var visiblePrompts: [Prompt] {
        viewModel.promptsViewModel.prompts.filter(\.isVisible)
    }

    private var hiddenPromptCount: Int {
        viewModel.promptsViewModel.prompts.count - visiblePrompts.count
    }

    private func policyRow(_ prompt: Prompt) -> some View {
        let resolution = viewModel.meetingPolicyResolution(
            for: prompt,
            meetingTypeID: selectedMeetingTypeID
        )
        let hasExactPolicy = viewModel.hasExactMeetingPolicy(
            for: prompt,
            meetingTypeID: selectedMeetingTypeID
        )

        return HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.name)
                    .font(DesignSystem.Typography.bodySmall.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                if selectedMeetingTypeID != nil, !hasExactPolicy {
                    Text("Inherits the All meetings default")
                        .font(DesignSystem.Typography.micro)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(
                "Available",
                isOn: Binding(
                    get: { resolution.isAvailable },
                    set: { isAvailable in
                        viewModel.setMeetingPolicy(
                            prompt: prompt,
                            meetingTypeID: selectedMeetingTypeID,
                            isAvailable: isAvailable,
                            isAutoRun: isAvailable && resolution.isAutoRun
                        )
                    }
                )
            )
            .toggleStyle(.switch)
            .fixedSize()

            Toggle(
                "Auto-run",
                isOn: Binding(
                    get: { resolution.isAutoRun },
                    set: { isAutoRun in
                        viewModel.setMeetingPolicy(
                            prompt: prompt,
                            meetingTypeID: selectedMeetingTypeID,
                            isAvailable: resolution.isAvailable,
                            isAutoRun: isAutoRun
                        )
                    }
                )
            )
            .toggleStyle(.switch)
            .fixedSize()
            .disabled(!resolution.isAvailable)

            if let selectedMeetingTypeID, hasExactPolicy {
                Button {
                    viewModel.resetMeetingTypePolicy(
                        prompt: prompt,
                        meetingTypeID: selectedMeetingTypeID
                    )
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.plain)
                .help("Reset to All meetings default")
                .accessibilityLabel("Reset \(prompt.name) policy to default")
            } else {
                Color.clear.frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, 11)
    }
}

private enum MeetingClassificationTint {
    static func color(for token: String?, fallback: Int) -> Color {
        switch token?.lowercased() {
        case "coral", "orange": return DesignSystem.Colors.accent
        case "green": return DesignSystem.Colors.successGreen
        case "amber", "yellow": return DesignSystem.Colors.warningAmber
        case "red": return DesignSystem.Colors.errorRed
        case "purple": return DesignSystem.Colors.podcastPurple
        default: return DesignSystem.Colors.speakerColor(for: fallback)
        }
    }
}
