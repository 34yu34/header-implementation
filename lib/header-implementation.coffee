{CompositeDisposable} = require 'atom'

module.exports =

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace',
      'header-implementation:generate': => @generate()
      'header-implementation:add': => @add()
      'header-implementation:update': => @update()
    # RegEx Patterns
    @HEADER = 0;
    @IMPLEMENTATION = 1;
    @FILE_NAMESPACE_END_PATTERN = /}\s*}/
    @FILE_NAME_PATTERN = /([\w]+)\.([h|cpp]+)/
    @CLASS_NAME_PATTERN = /(namespace|class)\s+(\w+)\s*{/g
    @METHOD_CPP_PATTERN = /^\s*?((?:virtual\s+|const\s+|friend\s+|volatile){0,3}\s*(?:\w+\s*::\s*)?\s*[\w]*?)\s*\w+\s*::\s*(~?[\w]+)\s*(\(.*\))\s*(const)?\s*[{|:]/gm
    @METHOD_NAMESPACE_PATTERN = /^\s*((?:const\s+|virtual\s+|friend\s+|volatile\s+){0,4}\s*?(?:\w+\s*::)?\s*[\w]+)\s+(\w+)\s*(\([\s\S]*?\))\s*(const)?\s*{/gm
    @METHOD_PATTERN = ///
    ^
    \s*
    (
      (?:
        (?:\s*const\s*)|
        (?:\s*static\s*)|
        (?:\s*virtual\s*)|
        (?:\s*volatile\s*)|
        (?:\s*friend\s*)
      ){0,5}
      \s*
      \w+
      (?:
        :{2}
        \w+
      )*
      (?:
        \s*?
        [&*]
        \s*?
      )*
    )??
    \s*
    ([\w~]+)
    \s*
    (
      \(
      .*
      \)
    )
    \s*?
    (\sconst)?
    \s*
    ;
    ///gm

  ######################################################################
  # Find the Path of the source file from the headers file
  # open in the text editor
  # return empty if nothing is found
  ######################################################################
  findPath: (work) ->
    path = work.editor.getPath()
    work.headerPath = ""
    work.implementationPath = ""
    if path.match(/\.h$/)
      work.headerPath = path
      fileName = work.editor.getTitle().replace(".h",".cpp")
    else if path.match(/\.cpp$/)
      work.implementationPath = path
      fileName = work.editor.getTitle().replace(".cpp",".h")
    else
      return
    return atom.workspace.scan @FILE_NAME_PATTERN, (file) ->
      if (file.filePath.includes(fileName))
        if work.headerPath == ""
          work.headerPath = file.filePath
        else if work.implementationPath == ""
          work.implementationPath = file.filePath
  ######################################################################
  #	Find wether it is a namespace or a classe and add its name to work
  ######################################################################
  findClassName: (work) ->
    work.buffer.scan @CLASS_NAME_PATTERN, (res) ->
      work.namespace = res.match[1] == "namespace"
      work.classname = res.match[2]
    work.editor.moveToEndOfLine()
  ######################################################################
  #	Find all the methods that match the pattern and add them
  # Add the method to headersMethods in the work object
  ######################################################################
  findAllHeaderMethods: (work) ->
    ctx = this
    work.buffer.scan @METHOD_PATTERN, (res) ->
      ctx.addHeaderMethod(work,res)
  ######################################################################
  #
  ######################################################################
  findAllCppMethods: (work) ->
    ctx = this
    if (work.namespace)
      work.buffer.scan @METHOD_NAMESPACE_PATTERN, (res) ->
        ctx.addCppMethod(work,res)
    else
      work.buffer.scan @METHOD_CPP_PATTERN, (res) ->
        ctx.addCppMethod(work,res)
  ######################################################################
  #	Find all the methods within the given range
  # Add the methods to headersMethods in the work object
  ######################################################################
  findMethodInRange: (work,range) ->
    ctx = this
    work.editor.scanInBufferRange @METHOD_PATTERN, range, (res) ->
      ctx.addHeaderMethod(work,res)
  ######################################################################
  # Create a method and return it
  ######################################################################
  createMethod: (work,res) ->
    method = []
    method.push((res.match[1]||"").replace("static ", "").replace(/\s{2,}/, " ") || "")
    method.push(res.match[2] + res.match[3] + (res.match[4]||""))
    return method
  ######################################################################
  # add a method to the cpp methods
  ######################################################################
  addCppMethod: (work,res) ->
    method = @createMethod(work,res)
    work.cppMethods.push(method)
  ######################################################################
  #	add a method to the workspace from a regex match
  ######################################################################
  addHeaderMethod: (work,res) ->
    method = @createMethod(work,res)
    work.headersMethods.push(method)
  ######################################################################
  # Compare all cpp method to .h and remove all the duplicates from th .h
  ######################################################################
  compareMethods: (work) ->
    ctx = this
    methods =[]
    work.headersMethods.forEach (hmethod) ->
      is_there = false
      work.cppMethods.forEach (cmethod) ->
        method1 = cmethod[1].replace(/\s*/,"")
        method2 = hmethod[1].replace(/\s*/,"")
        console.log(method1+"\n"+method2)
        if (method1 == method2)
          is_there = true
      if (!is_there)
        methods.push(hmethod)
    work.headersMethods = methods
  ######################################################################
  #	Find both name and methods form the headers
  ######################################################################
  readHeadersFile: (work) ->
    @findClassName(work)
    @findAllHeaderMethods(work)
  ######################################################################
  #	Return a promise toward a new .cpp file open
  ######################################################################
  openFile: (work,type) ->
    if (type == @IMPLEMENTATION)
      return atom.workspace.open(work.implementationPath)
    if (type == @HEADER)
      return atom.workspace.open(work.headerPath)
  ######################################################################
  # Write the head of a .cpp file depending on if
  # it's a namespace or a class
  ######################################################################
  createHeadOfCpp: (work) ->
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
  writeMethod: (work,method) ->
    @methodComment(work)
    @methodName(work,method)
    @methodBody(work)
  ######################################################################
  #	Create all the methods back to back
  ######################################################################
  writeAllMethods: (work) ->
    ctx = this
    work.headersMethods.forEach (method) ->
      ctx.writeMethod(work,method,ctx)
  ######################################################################
  #	Write the whole file .cpp
  ######################################################################
  writeNewCpp: (work) ->
    @createHeadOfCpp(work)
    @writeAllMethods(work)
  ######################################################################
  # move the cursor at the end of the doc to the append position
  ######################################################################
  moveCursorToAppend: (work) ->
    if (work.namespace)
      work.buffer.backwardsScan @FILE_NAMESPACE_END_PATTERN, (res) ->
        work.editor.setCursorBufferPosition(res.range.start)
        work.editor.moveRight(1)
        work.editor.insertNewline()
        res.stop()
    else
      work.editor.moveToBottom()
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
        headersMethods : []
        cppMethods : []
      }
    return work
  changeEditor: (work,editor) ->
    work.editor = editor
    work.buffer = work.editor.getBuffer()
  ######################################################################
  #	Return the range of the line in buffer coord
  ######################################################################
  lineRange: (work) ->
    position = work.editor.getCursorScreenPosition()
    work.editor.moveToBeginningOfLine()
    work.editor.selectToEndOfLine()
    range = work.editor.getSelectedBufferRange()
    work.editor.setCursorScreenPosition(position)
    return range
  ######################################################################
  #	Read the header files you are in and generate a .cpp
  # in the same path
  ######################################################################
  generate: ->
    work = @generateWork()
    work.editor.save()
    @readHeadersFile(work)
    work.headerPath = work.editor.getPath()
    work.implementationPath = work.headerPath.replace(".h",".cpp")
    ctx = this
    @openFile(work, @IMPLEMENTATION).then (editor) ->
      ctx.changeEditor(work,editor)
      ctx.writeNewCpp(work)
    return

  add: ->
    work = @generateWork()
    work.editor.save
    @findClassName(work)
    ctx = this
    @findPath(work).then ->
      range = ctx.lineRange(work)
      console.log(range)
      ctx.findMethodInRange(work,range)
      unless work.headersMethods.length
        return
      ctx.openFile(work, ctx.IMPLEMENTATION).then (editor) ->
        ctx.changeEditor(work,editor)
        ctx.moveCursorToAppend(work)
        ctx.writeMethod(work,work.headersMethods[0])
    return

  update: ->
    work = @generateWork()
    work.editor.save
    ctx = this
    @readHeadersFile(work)
    @findPath(work).then ->
      ctx.openFile(work,ctx.IMPLEMENTATION).then (editor) ->
        ctx.changeEditor(work,editor)
        ctx.findAllCppMethods(work)
        ctx.compareMethods(work)
        ctx.moveCursorToAppend(work)
        ctx.writeAllMethods(work)
    return
