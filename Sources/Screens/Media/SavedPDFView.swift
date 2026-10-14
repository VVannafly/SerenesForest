import SwiftUI
import PDFKit

struct SavedPDFView {
    let data: Data
}

#if os(iOS)
extension SavedPDFView: UIViewRepresentable {
    func makeUIView(context: Context) -> PDFView { PDFView() }
    func updateUIView(_ view: PDFView, context: Context) { view.document = PDFDocument(data: data); view.autoScales = true }
}
#elseif os(macOS)
extension SavedPDFView: NSViewRepresentable {
    func makeNSView(context: Context) -> PDFView { PDFView() }
    func updateNSView(_ view: PDFView, context: Context) { view.document = PDFDocument(data: data); view.autoScales = true }
}
#endif
