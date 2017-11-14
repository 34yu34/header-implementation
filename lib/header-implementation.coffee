
{CompositeDisposable} = require 'atom'

module.exports =

  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'header-implementation:generate': => @generate()

    # RegEx Patterns
    @CLASS_NAME_PATTERN = /(?:namescape|class)\s+(\w+)/
    @METHOD_PATTERN = /^\s*((?:const|static|virtual|volatile|friend){0,5}\s*\w+(?::{2}\w+){0,}\s*\**&?)?\s+([\w~]+)\s*(\(.*\))\s*?( const)?;/gm

  findName: (work) ->
    work.buffer.scan @CLASS_NAME_PATTERN, (res) ->
      work.classname = res.match[1]
    work.editor.moveToEndOfLine()

  findMethod: (work) ->
    work.buffer.scan @METHOD_PATTERN, (res) ->
      method = []
      method.push((res.match[1]||"").replace("static ", "").replace(/\s{2,}/, " ") || "")
      method.push(res.match[2] + res.match[3] + (res.match[4]||""))
      work.methods.push(method)

  readFile: (work) ->
    @findName(work)
    @findMethod(work)

  createFile: (work) ->
    return atom.workspace.open(work.implementationPath)

  createHead: (work) ->
    work.editor.insertText("#include \"#{work.classname}.h\"")
    work.editor.insertNewline()
    work.editor.insertNewline()
    work.editor.insertNewline()

  createMethods: (work) ->
    work.methods.forEach (method) ->
      work.editor.insertText("/*" + "*".repeat(68))
      work.editor.insertNewline()
      work.editor.insertText("* Comment")
      work.editor.insertNewline()
      work.editor.insertText( "*".repeat(68)+ "*/")
      work.editor.insertNewline()
      if (method[0])
        work.editor.insertText("#{method[0]} ")
      work.editor.insertText("#{work.classname}::#{method[1]}" )
      work.editor.insertNewline()
      work.editor.insertText("{")
      work.editor.insertNewline()
      work.editor.moveDown(1)
      work.editor.insertNewline()

  writeInEditor: (work) ->
    @createHead(work)
    @createMethods(work)


  generate: ->
    editor = atom.workspace.getActiveTextEditor()
    buffer = editor.getBuffer()
    headerPath = editor.getPath()
    implementationPath = headerPath.replace(".h",".cpp")
    work =
      {
        editor,
        buffer,
        headerPath,
        implementationPath,
        classname : ""
        methods : []
      }
    work.editor.save()
    @readFile(work)
    ctx = this
    @createFile(work).then (editor) ->
      work.editor = editor
      work.buffer = work.editor.getBuffer()
      ctx.writeInEditor(work)
    return
