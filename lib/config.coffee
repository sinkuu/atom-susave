module.exports =
  sudoGui:
    order: 1
    type: 'string'
    description: 'Graphical frondend for sudo'
    default: 'gksudo'
    enum: [ 'gksudo', 'kdesu' ]

  tryDefaultSave:
    order: 2
    type: 'boolean'
    description:
      'suave:save/save-as will try executing core:save/save-as before sudo'
    default: true
