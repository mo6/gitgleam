/* global marked, mermaid */
(function () {
  "use strict";

  function setTheme(theme) {
    document.documentElement.dataset.theme = theme === "dark" ? "dark" : "light";
  }

  // Strip the easy script-injection vectors from marked's HTML before we
  // assign it. Repo Markdown can contain raw HTML; this is a local viewer,
  // not a full sanitizer.
  function sanitize(root) {
    root.querySelectorAll("script, iframe, object, embed, link[href], meta").forEach(function (el) {
      el.remove();
    });
    root.querySelectorAll("*").forEach(function (el) {
      for (var i = el.attributes.length - 1; i >= 0; i--) {
        var attr = el.attributes[i];
        var name = attr.name.toLowerCase();
        if (name.startsWith("on")) {
          el.removeAttribute(attr.name);
          continue;
        }
        if ((name === "href" || name === "src" || name === "xlink:href") &&
            /^\s*javascript:/i.test(attr.value)) {
          el.removeAttribute(attr.name);
        }
      }
    });
  }

  // Wrap nodes between `<!-- viewmd:mark start kind=… -->` and
  // `<!-- viewmd:mark end -->` in a highlight div. Do this *after* marked
  // parses: wrapping the Markdown in a block HTML tag first would stop
  // CommonMark from parsing the block's contents.
  function wrapMarks(root) {
    var comments = [];
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_COMMENT);
    var node;
    while ((node = walker.nextNode())) comments.push(node);

    var starts = [];
    comments.forEach(function (comment) {
      var text = comment.data.trim();
      var start = /^viewmd:mark start kind=(\w+)$/.exec(text);
      if (start) {
        starts.push({ node: comment, kind: start[1] });
        return;
      }
      if (text !== "viewmd:mark end") return;
      var info = starts.pop();
      if (info) wrapRange(info.node, comment, info.kind);
    });
  }

  function wrapRange(startComment, endComment, kind) {
    if (!startComment.parentNode || startComment.parentNode !== endComment.parentNode) return;
    var wrap = document.createElement("div");
    wrap.className = "gg-mark gg-mark-" + (kind === "added" ? "added" : "changed");
    var toMove = [];
    var n = startComment.nextSibling;
    while (n && n !== endComment) {
      toMove.push(n);
      n = n.nextSibling;
    }
    startComment.parentNode.insertBefore(wrap, startComment);
    wrap.appendChild(startComment);
    toMove.forEach(function (el) { wrap.appendChild(el); });
    wrap.appendChild(endComment);
  }

  function replaceMermaid(root) {
    root.querySelectorAll("pre > code.language-mermaid, pre > code.lang-mermaid").forEach(function (code) {
      var pre = code.parentElement;
      if (!pre) return;
      var div = document.createElement("div");
      div.className = "mermaid";
      div.textContent = code.textContent;
      pre.replaceWith(div);
    });
  }

  async function gitgleamRender(markdown, theme) {
    setTheme(theme);
    var content = document.getElementById("content");
    var html = marked.parse(markdown || "", { gfm: true, breaks: false, async: false });
    if (html && typeof html.then === "function") html = await html;
    content.innerHTML = typeof html === "string" ? html : "";
    sanitize(content);
    wrapMarks(content);
    replaceMermaid(content);
    if (window.mermaid) {
      mermaid.initialize({
        startOnLoad: false,
        theme: theme === "dark" ? "dark" : "default",
        securityLevel: "strict",
      });
      var nodes = content.querySelectorAll(".mermaid");
      if (nodes.length) {
        try {
          await mermaid.run({ nodes: nodes });
        } catch (err) {
          // Leave the source text in place if a diagram fails to render.
        }
      }
    }
    return true;
  }

  window.gitgleamRender = gitgleamRender;
})();
