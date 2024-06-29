import SwiftUI
import Carbon.HIToolbox.Events

struct TemplateEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var template: Template
    @State private var newName: String
    @State private var newContent: String
    @State private var newTag: String
    @FocusState private var focusedField: Field?
    var onSave: (Template) -> Void

    enum Field: Hashable {
        case name
        case content
        case tag
    }

    init(template: Binding<Template>, onSave: @escaping (Template) -> Void) {
        self._template = template
        self.onSave = onSave
        self._newName = State(initialValue: template.wrappedValue.name)
        self._newContent = State(initialValue: template.wrappedValue.content)
        self._newTag = State(initialValue: template.wrappedValue.tag)
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Template Name")) {
                    TextField("Name", text: $newName)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            focusedField = .content
                        }
                }
                Section(header: Text("Content")) {
                    TextEditorWithTabSupport(text: $newContent, focusedField: $focusedField)
                        .focused($focusedField, equals: .content)
                }
                Section(header: Text("Tag")) {
                    TextField("Tag", text: $newTag)
                        .focused($focusedField, equals: .tag)
                        .onSubmit {
                            focusedField = nil
                        }
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Button("Save") {
                    var updatedTemplate = template
                    updatedTemplate.name = newName
                    updatedTemplate.content = newContent
                    updatedTemplate.tag = newTag
                    onSave(updatedTemplate)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}

struct TextEditorWithTabSupport: NSViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var focusedField: TemplateEditorView.Field?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextViewWrapper()
        scrollView.textView.delegate = context.coordinator
        scrollView.textView.string = text
        scrollView.textView.isEditable = true
        scrollView.textView.isRichText = false
        scrollView.textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let scrollView = nsView as? NSTextViewWrapper {
            scrollView.textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorWithTabSupport

        init(_ parent: TextEditorWithTabSupport) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.focusedField = .tag
                return true
            }
            return false
        }
    }
}

class NSTextViewWrapper: NSScrollView {
    let textView = NSTextView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.documentView = textView
        self.hasVerticalScroller = true
        self.autohidesScrollers = true
        self.borderType = .bezelBorder

        textView.minSize = NSSize(width: 0.0, height: 0.0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
