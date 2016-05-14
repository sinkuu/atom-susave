{CompositeDisposable} = require 'atom'
{spawnSync} = require 'child_process'
fs = require 'fs'
shellescape = require 'shell-escape'
tmp = require 'tmp'

module.exports = Susave =
  config: require './config'
  subscriptions: null

  isMac: process.platform == 'darwin'
  isWin: process.platform == 'win32' # platform is win32 on x64 Windows systems as well

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

      if @isWin
        escape = (s) -> s.replace(/'/g, '\'\'')
        command = "copy, /y, '\"#{escape(tempfile.name)}\"', '\"#{escape(path)}\"'"
        runasCommand = '$proc = start-process \"$env:windir\\system32\\cmd.exe\" /c,' +
          command +
          ' -verb RunAs -WindowStyle Hidden -WorkingDirectory $env:windir -Passthru;' +
          ' do {start-sleep -Milliseconds 100} until ($proc.HasExited)'
        psCommand = ['-command', runasCommand ]
        res = spawnSync 'powershell', psCommand
      else
        cmd = "cat " + shellescape([tempfile.name]) +
          " | tee " + shellescape([path])
        if @isMac
          # I don't know if this works.
          res = spawnSync 'osascript',
            [ '-e', 'do shell script "' + cmd +
              '" with administrator privileges']
        else
          sucmd = [ '--', 'sh', '-c', cmd ]
          if atom.config.get('susave.sudoGui') == 'pkexec'
            sucmd = [ 'sh', '-c', cmd ]
          res = spawnSync atom.config.get('susave.sudoGui'),
            sucmd
      tempfile.removeCallback

      if res.status != 0
        atom.notifications.addError(
          'Failed to save as super user',
          detail: 'status=' + res.status)
      else
        if res.error?
          atom.notifications.addError(
            'Failed to save as super user',
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
      return false if error.code == 'EACCES' || error.code == 'EPERM' # permission denied 'EPERM' on Windows
      throw error
