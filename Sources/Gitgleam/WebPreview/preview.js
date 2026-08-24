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

  // --- Front matter (mirrors viewmd's split/parse/flatten, not a full YAML parser) ---

  function isFenceLine(line) {
    return line.trim() === "---";
  }

  // Returns { raw, body } or null when there is no terminated leading --- block.
  function splitFrontMatter(text) {
    var lines = (text || "").split(/\r?\n/);
    if (!lines.length || !isFenceLine(lines[0])) return null;
    for (var i = 1; i < lines.length; i++) {
      if (isFenceLine(lines[i])) {
        return {
          raw: lines.slice(1, i).join("\n"),
          body: lines.slice(i + 1).join("\n"),
        };
      }
    }
    return null;
  }

  function indentOf(line) {
    return line.length - line.replace(/^ +/, "").length;
  }

  function stripQuotes(value) {
    var s = value.trim();
    if ((s.charAt(0) === '"' && s.charAt(s.length - 1) === '"') ||
        (s.charAt(0) === "'" && s.charAt(s.length - 1) === "'")) {
      return s.slice(1, -1);
    }
    return s;
  }

  function partitionColon(text) {
    var idx = text.indexOf(":");
    if (idx < 0) return { key: text, sep: "", value: "" };
    return { key: text.slice(0, idx), sep: ":", value: text.slice(idx + 1) };
  }

  function parseMapping(lines, idx, indent) {
    var result = {};
    while (
      idx < lines.length &&
      indentOf(lines[idx]) === indent &&
      !lines[idx].trim().startsWith("- ")
    ) {
      var parts = partitionColon(lines[idx].trim());
      idx += 1;
      if (!parts.sep) continue;
      var key = parts.key.trim();
      var value = parts.value.trim();
      if (value === "|" || value === ">") {
        var content = [];
        while (idx < lines.length && indentOf(lines[idx]) > indent) {
          content.push(lines[idx].trim());
          idx += 1;
        }
        result[key] = content.join(value === "|" ? "\n" : " ");
      } else if (value.charAt(0) === "[" && value.charAt(value.length - 1) === "]") {
        var inner = value.slice(1, -1).trim();
        result[key] = inner
          ? inner.split(",").map(function (v) { return stripQuotes(v); }).filter(Boolean)
          : [];
      } else if (value) {
        result[key] = stripQuotes(value);
      } else if (idx < lines.length && indentOf(lines[idx]) > indent) {
        var childIndent = indentOf(lines[idx]);
        if (lines[idx].trim().startsWith("- ")) {
          var listParsed = parseList(lines, idx, childIndent);
          result[key] = listParsed.node;
          idx = listParsed.idx;
        } else {
          var mapParsed = parseMapping(lines, idx, childIndent);
          result[key] = mapParsed.node;
          idx = mapParsed.idx;
        }
      } else {
        result[key] = "";
      }
    }
    return { node: result, idx: idx };
  }

  function parseList(lines, idx, indent) {
    var items = [];
    while (
      idx < lines.length &&
      indentOf(lines[idx]) === indent &&
      lines[idx].trim().startsWith("- ")
    ) {
      var itemText = lines[idx].trim().slice(2).trim();
      idx += 1;
      var parts = partitionColon(itemText);
      if (!parts.sep) {
        items.push(stripQuotes(itemText));
        continue;
      }
      var obj = {};
      var value = parts.value.trim();
      if (value) obj[parts.key.trim()] = stripQuotes(value);
      while (
        idx < lines.length &&
        indentOf(lines[idx]) > indent &&
        !lines[idx].trim().startsWith("- ")
      ) {
        var sub = partitionColon(lines[idx].trim());
        if (sub.sep && sub.value.trim()) {
          obj[sub.key.trim()] = stripQuotes(sub.value);
        }
        idx += 1;
      }
      items.push(obj);
    }
    return { node: items, idx: idx };
  }

  function flatten(node, prefix, out) {
    if (node && typeof node === "object" && !Array.isArray(node)) {
      Object.keys(node).forEach(function (key) {
        flatten(node[key], prefix ? prefix + "." + key : key, out);
      });
      return;
    }
    if (Array.isArray(node)) {
      if (node.every(function (item) { return typeof item === "string"; })) {
        out[prefix] = node.join(", ");
        return;
      }
      out[prefix] = node.map(function (item) {
        if (item && typeof item === "object" && !Array.isArray(item)) {
          return Object.keys(item).map(function (k) { return k + ": " + item[k]; }).join(", ");
        }
        return String(item);
      }).join("; ");
      return;
    }
    out[prefix] = node == null ? "" : String(node);
  }

  function parseFrontMatter(raw) {
    var lines = (raw || "").split(/\r?\n/).filter(function (line) {
      var t = line.trim();
      return t && !t.startsWith("#");
    });
    if (!lines.length) return {};
    var tree = parseMapping(lines, 0, indentOf(lines[0])).node;
    var data = {};
    flatten(tree, "", data);
    return data;
  }

  function dropEmpty(data) {
    var out = {};
    Object.keys(data).forEach(function (key) {
      if (String(data[key]).trim()) out[key] = data[key];
    });
    return out;
  }

  function frontMatterPairs(markdown) {
    var split = splitFrontMatter(markdown);
    if (!split) return null;
    var data = dropEmpty(parseFrontMatter(split.raw));
    var keys = Object.keys(data);
    if (!keys.length) return null;
    return { pairs: keys.map(function (key) { return [key, data[key]]; }), body: split.body };
  }

  function appendFrontMatterTable(root, pairs, fieldLabel, valueLabel) {
    var wrap = document.createElement("div");
    wrap.className = "gg-front-matter-wrap";
    var table = document.createElement("table");
    table.className = "gg-front-matter";
    var thead = document.createElement("thead");
    var headRow = document.createElement("tr");
    var thField = document.createElement("th");
    thField.textContent = fieldLabel || "Field";
    var thValue = document.createElement("th");
    thValue.textContent = valueLabel || "Value";
    headRow.appendChild(thField);
    headRow.appendChild(thValue);
    thead.appendChild(headRow);
    table.appendChild(thead);
    var tbody = document.createElement("tbody");
    pairs.forEach(function (pair) {
      var tr = document.createElement("tr");
      var tdKey = document.createElement("td");
      tdKey.textContent = pair[0];
      var tdVal = document.createElement("td");
      tdVal.textContent = pair[1];
      tr.appendChild(tdKey);
      tr.appendChild(tdVal);
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    wrap.appendChild(table);
    root.insertBefore(wrap, root.firstChild);
  }

  async function gitgleamRender(markdown, theme, fieldLabel, valueLabel) {
    setTheme(theme);
    var extracted = frontMatterPairs(markdown);
    var body = extracted ? extracted.body : (markdown || "");
    var content = document.getElementById("content");
    var html = marked.parse(body, { gfm: true, breaks: false, async: false });
    if (html && typeof html.then === "function") html = await html;
    content.innerHTML = typeof html === "string" ? html : "";
    sanitize(content);
    if (extracted) appendFrontMatterTable(content, extracted.pairs, fieldLabel, valueLabel);
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
