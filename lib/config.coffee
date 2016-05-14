if process.platform == 'darwin'
  module.exports =
    tryDefaultSave:
      order: 1
      type: 'boolean'
      description:
        'susave:save/save-as will try executing core:save/save-as before sudo'
      default: true
else if process.platform != 'win32'
  module.exports =
    sudoGui:
      order: 1
      type: 'string'
      description: 'Graphical frondend for sudo'
      default: 'gksudo'
      enum: [ 'gksudo', 'kdesu', 'pkexec' ]

    tryDefaultSave:
      order: 2
      type: 'boolean'
      description:
        'susave:save/save-as will try executing core:save/save-as before sudo'
      default: true
