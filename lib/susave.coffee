{CompositeDisposable} = require 'atom'
{spawnSync} = require 'child_process'
fs = require 'fs'
shellescape = require 'shell-escape'
tmp = require 'tmp'

module.exports = Susave =
  config: require './config'
  subscriptions: null

  isMac: process.platform == 'darwin'

  activate: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'susave:save': => @cmdSave()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'susave:save-as': => @cmdSaveAs()

  deactivate: ->
    @subscriptions.dispose()

  cmdSave: ->
    if editor = atom.workspace.getActiveTextEditor()
      editor = atom.workspace.getActiveTextEditor()

      if path = editor.getPath()
        return unless editor.isModified()
        @save editor, path
      else
        @cmdSaveAs()
    else
      atom.workspace.getActivePaneItem()?.save?()

  cmdSaveAs: ->
    if editor = atom.workspace.getActiveTextEditor()
      editor = atom.workspace.getActiveTextEditor()
      item = atom.workspace.getActivePaneItem()

      params = item.getSaveDialogOptions?() ? {}
      params.defaultPath ?= item.getPath()
      if path = atom.applicationDelegate.showSaveDialog(params)
        editor.getBuffer().setPath(path)
        @save editor, path
    else
      atom.workspace.getActivePaneItem()?.save?()

  save: (editor, path) ->
    if !atom.config.get('susave.tryDefaultSave') || !@tryDefaultSave(editor)
      text = editor.getText()

      tempfile = tmp.fileSync()
      fs.writeSync tempfile.fd, text
      cmd = "cat " + shellescape([tempfile.name]) +
        " | tee " + shellescape([path])
      if @isMac
        # I don't know if this works.
        res = spawnSync 'osascript',
          [ '-e', 'do shell script "' + cmd +
            '" with administrator privileges']
      else
        res = spawnSync atom.config.get('susave.sudoGui'),
          [ '--', 'sh', '-c', cmd ]
      tempfile.removeCallback

      if res?.status != 0
        atom.notifications.addError(
          'Failed to save as supuer user',
          detail: 'status=' + res.status)
      else
        if res.error?
          atom.notifications.addError(
            'Failed to save as supuer user',
            detail: res.error)
        else
          buffer = editor.getBuffer()
          buffer.cachedDiskContents = text
          buffer.emitModifiedStatusChanged(false)
          buffer.emitter.emit 'did-save', {path: path}

  tryDefaultSave: (editor) ->
    try
      editor.save()
      return true
    catch error
      return false if error.code == 'EACCES' # permission denied
      throw error
