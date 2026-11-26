.pragma library

// Split fenced code without interpreting its contents as Markdown.
function split(markdown) {
    var lines = markdown.split("\n")
    var blocks = []
    var prose = []
    var code = []
    var fence = ""
    var language = ""

    function flushProse() {
        var text = prose.join("\n")
        if (text.trim().length)
            blocks.push({ kind: "markdown", text: text, language: "" })
        prose = []
    }

    for (var i = 0; i < lines.length; ++i) {
        var line = lines[i]
        if (!fence) {
            var opening = line.match(/^ {0,3}(`{3,}|~{3,})([^\r]*)$/)
            if (opening && !(opening[1][0] === "`" && opening[2].indexOf("`") !== -1)) {
                flushProse()
                fence = opening[1]
                language = opening[2].trim().split(/\s+/)[0].slice(0, 40)
                code = []
            } else {
                prose.push(line)
            }
        } else {
            var closing = line.match(/^ {0,3}(`+|~+)\s*$/)
            if (closing && closing[1][0] === fence[0] && closing[1].length >= fence.length) {
                blocks.push({ kind: "code", text: code.join("\n"), language: language })
                fence = ""
            } else {
                code.push(line)
            }
        }
    }
    if (fence)
        blocks.push({ kind: "code", text: code.join("\n"), language: language })
    flushProse()
    return blocks
}

// Keep arbitrary HTML and image URLs out of the Qt rich-text renderer.
function safeMarkdown(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
               .replace(/!\[([^\]]*)\]\([^\n)]*\)/g, "[$1]")
}
