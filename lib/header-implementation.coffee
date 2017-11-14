
{CompositeDisposable} = require 'atom'

module.exports =

  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'header-implementation:generate': => @generate()
    @METHOD_PATTERN = /^\s*((?:const|static|virtual|volatile|friend){0,5}\s*[a-zA-Z]+(?::{2}[a-zA-Z_]+)?\s*\**&?)?\s+([~a-zA-Z_]+)\s*\((.*)\)\s*(const)?/

  findName: (work) ->
    work.buffer.scan new RegExp("namespace"), (res) ->
      work.editor.setCursorBufferPosition(res.range.end)
      work.editor.moveRight(1)
      work.editor.moveToEndOfWord()
      work.editor.moveToBeginningOfWord()
      work.editor.selectToEndOfWord()
      work.classname = editor.getSelectedText()
      res.stop()
    work.editor.moveToEndOfLine()

  @nextMethod: (work) ->
    work.buffer.scan new RegExp(@METHOD_PATTERN), (res) ->
      res.match


  readFile: (work) ->
    @findName(work)
    while @nextMethod(work)
    {

    }



  createFile: (work) ->
    return atom.workspace.open(work.implementationPath)

  writeInEditor: (work) ->
    @createHead(work)
    @createMethods(work)

  createHead: (work) ->
    work.editor.insertText("#include \"#{work.classname}.h\"")
    work.editor.insertNewline()

  createMethods: (editor) ->
    work

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
    @readFile
    @findName(work)
    ctx = this
    @createFile(work).then (editor) ->
      work.editor = editor
      work.buffer = work.editor.getBuffer()
      ctx.writeInEditor(work)
    return
