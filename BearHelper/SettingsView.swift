import SwiftUI

struct SettingsView: View {
    @AppStorage("homeNoteID") private var homeNoteID: String = ""
    @AppStorage("defaultAction") private var defaultAction: String = "home"
    @AppStorage("templates") private var templatesData: Data = Data()
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @State private var templates: [Template] = []
    @State private var showModal = false
    @State private var editingTemplate: Template?
    @State private var selectedTemplates = Set<UUID>()

    var setLaunchAtLogin: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Settings")
                .font(.largeTitle)
                .padding()

            Text("Home Note ID:")
                .padding(.horizontal)

            TextField("Paste the note ID here", text: $homeNoteID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Text("Left Click Action:")
                .padding(.horizontal)

            Picker("Action", selection: $defaultAction) {
                Text("Disabled").tag("disabled")
                Text("Open Home Note").tag("home")
                Text("Open Daily Note").tag("daily")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            Divider()
                .padding(.vertical)

            Text("Templates")
                .font(.title2)
                .padding(.horizontal)

            VStack {
                List(selection: $selectedTemplates) {
                    ForEach(templates) { template in
                        HStack {
                            Text(template.name)
                            Spacer()
                        }
                        .contentShape(Rectangle()) // Permite hacer clic en toda la fila
                        .onTapGesture {
                            selectedTemplates = [template.id]
                        }
                    }
                    .onDelete(perform: deleteTemplate)
                }
                .cornerRadius(10) // Agrega el borde redondeado aquí
            }
            .padding(.horizontal)

            HStack {
                Spacer()
                Button(action: {
                    let newTemplate = Template(name: "New Template", content: "", tag: "")
                    templates.append(newTemplate)
                    editingTemplate = newTemplate
                    showModal = true
                }) {
                    Image(systemName: "plus")
                }
                .padding()
                Button(action: {
                    if let editingTemplate = templates.first(where: { selectedTemplates.contains($0.id) }) {
                        self.editingTemplate = editingTemplate
                        showModal = true
                    }
                }) {
                    Image(systemName: "pencil")
                }
                .padding()
                .disabled(selectedTemplates.isEmpty) // Deshabilitar si no hay plantillas seleccionadas
                Button(action: {
                    deleteSelectedTemplates()
                }) {
                    Image(systemName: "minus")
                }
                .padding()
                .disabled(selectedTemplates.isEmpty) // Deshabilitar si no hay plantillas seleccionadas
            }

            Spacer()

            HStack {
                Spacer()
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .padding()
                    .onChange(of: launchAtLogin) { value in
                        setLaunchAtLogin(value)
                    }
            }
        }
        .onAppear {
            loadTemplates()
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(
                template: Binding(
                    get: { template },
                    set: { updatedTemplate in
                        if let index = templates.firstIndex(where: { $0.id == updatedTemplate.id }) {
                            templates[index] = updatedTemplate
                        } else {
                            templates.append(updatedTemplate)
                        }
                        saveTemplates()
                        showModal = false
                    }
                ),
                onSave: { updatedTemplate in
                    if let index = templates.firstIndex(where: { $0.id == updatedTemplate.id }) {
                        templates[index] = updatedTemplate
                    } else {
                        templates.append(updatedTemplate)
                    }
                    saveTemplates()
                    showModal = false
                }
            )
        }
        .frame(minWidth: 400, minHeight: 600) // Ajusta el tamaño de la ventana
    }

    private func loadTemplates() {
        if let loadedTemplates = try? JSONDecoder().decode([Template].self, from: templatesData) {
            templates = loadedTemplates
        }
        if templates.isEmpty {
            let defaultTemplate = Template(name: "Daily", content: "Default daily template", tag: "daily")
            templates.append(defaultTemplate)
            saveTemplates()
        }
    }

    private func saveTemplates() {
        if let encodedTemplates = try? JSONEncoder().encode(templates) {
            templatesData = encodedTemplates
        }
    }

    private func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        saveTemplates()
    }

    private func deleteSelectedTemplates() {
        templates.removeAll { template in
            selectedTemplates.contains(template.id)
        }
        selectedTemplates.removeAll()
        saveTemplates()
    }
}
