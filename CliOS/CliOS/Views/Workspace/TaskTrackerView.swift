import SwiftUI

struct TaskTrackerView: View {
    @StateObject private var vm = TaskTrackerViewModel()
    @State private var viewMode: ViewMode = .list
    @State private var showNewTask = false
    @State private var showNewBoard = false
    @State private var newBoardName = ""

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case board = "Board"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: board picker + view toggle + add button
            toolbar
                .padding(.horizontal, Theme.paddingM)
                .padding(.vertical, Theme.paddingS)
                .background(Theme.bg)

            if let error = vm.error, vm.boards.isEmpty {
                errorView(error)
            } else if vm.boards.isEmpty && !vm.isLoading {
                emptyBoardsView
            } else {
                switch viewMode {
                case .list:
                    TaskListView(vm: vm)
                case .board:
                    TaskBoardView(vm: vm)
                }
            }
        }
        .background(Theme.bg)
        .task { await vm.loadIndex() }
        .sheet(isPresented: $showNewTask) {
            NewTaskSheet(vm: vm)
        }
        .alert("New Board", isPresented: $showNewBoard) {
            TextField("Board name", text: $newBoardName)
            Button("Create") {
                let id = newBoardName
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                guard !id.isEmpty else { return }
                Task { await vm.createBoard(id: id, name: newBoardName) }
                newBoardName = ""
            }
            Button("Cancel", role: .cancel) { newBoardName = "" }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Board picker
            if vm.boards.count > 1 {
                Menu {
                    ForEach(vm.boards) { entry in
                        Button(entry.name) {
                            Task { await vm.selectBoard(entry.id) }
                        }
                    }
                    Divider()
                    Button("New Board...") { showNewBoard = true }
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.boards.first(where: { $0.id == vm.selectedBoardId })?.name ?? "Board")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                }
            } else if vm.boards.count == 1 {
                Text(vm.boards[0].name)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()

            // View mode toggle
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 130)

            // Add task
            Button {
                showNewTask = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(Theme.accent)
            }
        }
    }

    // MARK: - Empty / Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Theme.paddingM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(Theme.warning)
            Text(message)
                .font(Theme.fontCaption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await vm.loadIndex() }
            }
            .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyBoardsView: some View {
        VStack(spacing: Theme.paddingM) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundColor(Theme.textMuted)
            Text("No task boards")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
            Button("Create Board") {
                showNewBoard = true
            }
            .font(.system(.body, weight: .medium))
            .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
