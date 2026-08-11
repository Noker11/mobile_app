import SwiftUI

struct ContentView: View {
    @StateObject private var store = TodoListStore()
    @State private var newTitle: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(store.items) { item in
                        HStack {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? .green : .secondary)
                                .onTapGesture {
                                    store.toggle(item)
                                }
                            Text(item.title)
                                .strikethrough(item.isDone)
                                .foregroundStyle(item.isDone ? .secondary : .primary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.toggle(item)
                        }
                    }
                    .onDelete(perform: store.delete)
                    .onMove(perform: store.move)
                }
                .listStyle(.plain)

                HStack {
                    TextField("Nová úloha", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addItem)

                    Menu {
                        Button(action: addItem) {
                            Label("Pridať", systemImage: "plus")
                        }
                        .tint(.green)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(role: .destructive, action: store.deleteCheckedItems) {
                            Label("Odmazať zaškrtnuté úlohy", systemImage: "trash")
                        }
                        .disabled(!store.items.contains { $0.isDone })
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                    }
                }
                .padding()
            }
            .navigationTitle("To-Do List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func addItem() {
        store.add(title: newTitle)
        newTitle = ""
    }
}

#Preview {
    ContentView()
}
