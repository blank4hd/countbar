import SwiftUI
import SwiftData

struct CounterListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Counter.createdAt) private var counters: [Counter]
    @AppStorage("activeCounterID") private var activeCounterID: String = ""

    @State private var newCounterName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if counters.isEmpty {
                Text("No counters yet")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(counters) { counter in
                            CounterRow(
                                counter: counter,
                                isActive: counter.id.uuidString == activeCounterID,
                                onSetActive: { activeCounterID = counter.id.uuidString },
                                onDelete: {
                                    if counter.id.uuidString == activeCounterID {
                                        activeCounterID = ""
                                    }
                                    context.delete(counter)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
                .frame(maxHeight: 320)
            }

            Divider()

            HStack {
                TextField("New counter", text: $newCounterName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCounter)

                Button {
                    addCounter()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newCounterName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)

            Divider()
            
            Button("Open Dashboard") {
                AppDelegate.shared?.showDashboard()
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("d", modifiers: [.command])
            
            
            Button("Quit CountBar") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q", modifiers: [.command])
            .padding(.vertical, 6)
        }
        .frame(width: 280)
    }

    private func addCounter() {
        let trimmed = newCounterName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let new = Counter(name: trimmed)
        context.insert(new)
        // First counter created becomes active automatically
        if activeCounterID.isEmpty {
            activeCounterID = new.id.uuidString
        }
        newCounterName = ""
    }
}

struct CounterRow: View {
    @Bindable var counter: Counter
    let isActive: Bool
    let onSetActive: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context

    @State private var showingGoalEditor = false
    @State private var showingResetEditor = false
    @State private var resetTimeInput: Date = Counter.defaultResetTime()
    @State private var goalInput: String = ""

    private var store: CounterStore { CounterStore(context: context) }
    private var displayValue: Int { store.displayValue(for: counter) }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)

            Button {
                store.decrement(counter)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)

            Text("\(displayValue)")
                .monospacedDigit()
                .frame(minWidth: 36)
                .font(.system(.body, design: .rounded).weight(.semibold))

            Button {
                store.increment(counter)
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 2) {
                EditableName(name: $counter.name)
                if counter.goal > 0 {
                    Text("\(displayValue) / \(counter.goal)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                Button(isActive ? "✓ Showing in Menu Bar" : "Show in Menu Bar") {
                    onSetActive()
                }
                .disabled(isActive)
                Divider()
                Button("Set Goal…") {
                    goalInput = counter.goal > 0 ? "\(counter.goal)" : ""
                    showingGoalEditor = true
                }
                if counter.goal > 0 {
                    Button("Clear Goal") { counter.goal = 0 }
                }
                Divider()
                Menu("Reset Schedule") {
                    Button(counter.resetTime != nil ? "Daily Reset…" : "Set Daily Reset…") {
                        resetTimeInput = counter.resetTime ?? Counter.defaultResetTime()
                        showingResetEditor = true
                    }
                    Button("Never Reset (Accumulate)") {
                        counter.resetTime = nil
                    }
                    .disabled(counter.resetTime == nil)
                }
                Divider()
                Button("Reset to 0") { store.reset(counter) }
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.04))
        )
        .popover(isPresented: $showingGoalEditor) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily goal for \(counter.name)")
                    .font(.headline)
                TextField("e.g. 100", text: $goalInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit(saveGoal)
                HStack {
                    Spacer()
                    Button("Cancel") { showingGoalEditor = false }
                    Button("Save") { saveGoal() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
        }
        .popover(isPresented: $showingResetEditor) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily reset for \(counter.name)")
                    .font(.headline)

                DatePicker(
                    "Resets at",
                    selection: $resetTimeInput,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)

                Text(currentSchedule)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("Cancel") { showingResetEditor = false }
                    Button("Save") {
                        counter.resetTime = resetTimeInput
                        showingResetEditor = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
            .frame(width: 240)
        }
    }

    private func saveGoal() {
        if let n = Int(goalInput.trimmingCharacters(in: .whitespaces)), n >= 0 {
            counter.goal = n
        }
        showingGoalEditor = false
    }

    private var currentSchedule: String {
        if let reset = counter.resetTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Counter resets daily at \(formatter.string(from: reset))"
        } else {
            return "Counter never resets"
        }
    }
}

struct EditableName: View {
    @Binding var name: String

    @State private var isEditing = false
    @State private var draft = ""
    @State private var isHovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("Name", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit(commit)
                    .onExitCommand { cancel() }   // Esc to cancel
                    .onChange(of: focused) { _, nowFocused in
                        if !nowFocused { commit() }   // commit on blur
                    }
            } else {
                HStack(spacing: 4) {
                    Text(name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(isHovering ? 0.6 : 0)
                }
                .onHover { isHovering = $0 }
                .onTapGesture(count: 2) { startEditing() }
            }
        }
    }

    private func startEditing() {
        draft = name
        isEditing = true
        // Defer focus until after the TextField is actually in the view tree.
        DispatchQueue.main.async { focused = true }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            name = trimmed
        }
        isEditing = false
    }

    private func cancel() {
        isEditing = false
    }
}
