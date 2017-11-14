{CompositeDisposable} = require 'atom'

module.exports =

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'header-implementation:generate': => @generate()
    # RegEx Patterns
    @CLASS_NAME_PATTERN = /((?:namespace|class))+\s+([\w_]+)+\s*{/g
    @METHOD_PATTERN = /^\s*((?:const|static|virtual|volatile|friend){0,5}\s*\w+(?::{2}\w+){0,}\s*\**&?)?\s+([\w~]+)\s*(\(.*\))\s*?( const)?;/gm
    @FILE_NAME_PATTERN = /([\w]+)\.([h|cpp]+)/

  ######################################################################
  #
  ######################################################################
  findPath: (work) ->
    atom.workspace.scan @FILE_NAME_PATTERN, (file) ->
      if (file.filePath.includes("#{work.classname}.h"))
        work.headerPath = file.filePath
      if (file.filePath.includes("#{work.classname}.cpp"))
        work.implementationPath = file.filePath

  ######################################################################
  #	Find wether it is a namespace or a classe and add its name to work
  ######################################################################
  findName: (work) ->
    work.buffer.scan @CLASS_NAME_PATTERN, (res) ->
      work.namespace = res.match[1] == "namespace"
      work.classname = res.match[2]
    work.editor.moveToEndOfLine()
  ######################################################################
  #	find all the methods in the headers file
  ######################################################################
  findMethod: (work) ->
    work.buffer.scan @METHOD_PATTERN, (res) ->
      method = []
      method.push((res.match[1]||"").replace("static ", "").replace(/\s{2,}/, " ") || "")
      method.push(res.match[2] + res.match[3] + (res.match[4]||""))
      work.methods.push(method)
  ######################################################################
  #	Find both name and methods
  ######################################################################
  readFile: (work) ->
    @findName(work)
    @findMethod(work)
  ######################################################################
  #	Return a promise toward a new .cpp file open
  ######################################################################
  createFile: (work) ->
    return atom.workspace.open(work.implementationPath)
  ######################################################################
  # Write the head of a .cpp file depending on if
  # it's a namespace or a class
  ######################################################################
  createHead: (work) ->
    work.editor.insertText("#include \"#{work.classname}.h\"")
    work.editor.insertNewline()
    work.editor.insertNewline()
    work.editor.insertNewline()
    if (work.namespace)
      work.editor.insertText("namespace #{work.classname}")
      work.editor.insertNewline()
      work.editor.insertText("{")
      work.editor.insertNewline()
  ######################################################################
  # Insert a comment line on top of a method
  ######################################################################
  methodComment: (work) ->
    work.editor.insertText("/*" + "*".repeat(68))
    work.editor.insertNewline()
    work.editor.insertText("* Comment")
    work.editor.insertNewline()
    work.editor.insertText( "*".repeat(68)+ "*/")
    work.editor.insertNewline()
  ######################################################################
  #	Write the method name
  ######################################################################
  methodName: (work,method) ->
    if (method[0])
      work.editor.insertText("#{method[0]} ")
    if (work.namespace)
      work.editor.insertText("#{method[1]}" )
    else
      work.editor.insertText("#{work.classname}::#{method[1]}")
    work.editor.insertNewline()
  ######################################################################
  #	Write the body of the implementation of a method
  ######################################################################
  methodBody: (work) ->
    work.editor.insertText("{")
    work.editor.insertNewline()
    work.editor.moveDown(1)
    work.editor.insertNewline()
  ######################################################################
  #	Add a method at the cursor position
  ######################################################################
  addMethod: (work,method) ->
    @methodComment(work)
    @methodName(work,method)
    @methodBody(work)
  ######################################################################
  #	Create all the methods back to back
  ######################################################################
  createMethods: (work) ->
    ctx = this
    work.methods.forEach (method) ->
      ctx.addMethod(work,method,ctx)
  ######################################################################
  #	Write the whole file .cpp
  ######################################################################
  writeInEditor: (work) ->
    @createHead(work)
    @createMethods(work)
  ######################################################################
  #	generate a work object
  ######################################################################
  generateWork: ->
    editor = atom.workspace.getActiveTextEditor()
    buffer = editor.getBuffer()
    work =
      {
        editor,
        buffer,
        headerPath : ""
        implementationPath : ""
        classname : ""
        namespace : false
        methods : []
      }
    return work
  ######################################################################
  #	Read the header files you are in and generate a .cpp
  # in the same path
  ######################################################################
  generate: ->
    work = @generateWork()
    work.editor.save()
    @readFile(work)
    @findPath(work)
    work.headerPath = work.editor.getPath()
    work.implementationPath = work.headerPath.replace(".h",".cpp")
    ctx = this
    @createFile(work).then (editor) ->
      work.editor = editor
      work.buffer = work.editor.getBuffer()
      ctx.writeInEditor(work)
    return
