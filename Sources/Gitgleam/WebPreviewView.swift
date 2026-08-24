import AppKit
import SwiftUI
import WebKit

/// Renders Markdown (and Mermaid fences) as HTML in a `WKWebView`, using
/// vendored `marked` + `mermaid` from the app bundle. Offline; no CDN.
///
/// Change highlighting reuses `MarkdownHighlighter`'s `viewmd:mark` HTML
/// comments: the page wraps the parsed nodes between those comments rather
/// than wrapping the Markdown in a block tag before `marked` runs (CommonMark
/// would then leave the block unparsed).
struct WebPreviewView: NSViewRepresentable {
    var markdown: String
    var colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif
        context.coordinator.loadPage(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let theme = colorScheme == .dark ? "dark" : "light"
        webView.underPageBackgroundColor = colorScheme == .dark
            ? NSColor(calibratedWhite: 0.11, alpha: 1)
            : NSColor.white
        context.coordinator.enqueue(markdown: markdown, theme: theme, in: webView)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private var pendingMarkdown: String?
        private var pendingTheme: String?
        private var pageReady = false
        private var isRendering = false

        func loadPage(in webView: WKWebView) {
            guard let html = Bundle.module.url(
                forResource: "preview", withExtension: "html", subdirectory: "WebPreview"
            ) else { return }
            webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }

        func enqueue(markdown: String, theme: String, in webView: WKWebView) {
            pendingMarkdown = markdown
            pendingTheme = theme
            flush(in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageReady = true
            flush(in: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.isFileURL {
                decisionHandler(.allow)
                return
            }
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        private func flush(in webView: WKWebView) {
            guard pageReady, !isRendering else { return }
            guard let markdown = pendingMarkdown, let theme = pendingTheme else { return }
            pendingMarkdown = nil
            pendingTheme = nil
            isRendering = true
            let body = "return await gitgleamRender(markdown, theme);"
            webView.callAsyncJavaScript(
                body, arguments: ["markdown": markdown, "theme": theme],
                in: nil, in: WKContentWorld.page
            ) { [weak self] (_: Result<Any, Error>) in
                Task { @MainActor in
                    guard let self else { return }
                    self.isRendering = false
                    // A newer enqueue may have landed while we were rendering.
                    self.flush(in: webView)
                }
            }
        }
    }
}
