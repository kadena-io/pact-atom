module.exports =
  config:
    pactPath:
      type: 'string'
      default: 'pact'
    pactOptions:
      type: 'array'
      default: ['-r']


  activate: ->
    require('atom-package-deps').install()

  provideLinter: ->
    helpers = require('atom-linter')
    # regex = '.*:(?<line>\\d+):(?<col>\\d+): error: (?<message>.*)'
    regexW = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):Warning:(?<message>(\\s+.*\\n)+)'
    regexE = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):(?<message>(\\s+.*\\n)+)'
    provider =
      grammarScopes: ['source.pact']
      scope: 'file'
      lintOnFly: true
      lint: (textEditor) =>
        filePath = textEditor.getPath()
        command = atom.config.get('pact-atom.pactPath') or 'pact'
        prefOptions = atom.config.get('pact-atom.pactOptions') or []
        parameters = prefOptions.concat(["-r", filePath ])

        return helpers.exec(command, parameters, {stream: 'stderr'}).then (output) ->
          errors = for message in helpers.parse(output, regexE) #, {filePath: filePath})
            message.type = 'Error'
            r = message.range; s = r[0]; e = r[1]
            message.range = [ [ s[0],s[1] + 1 ] , [ e[0], e[1] + 3 ] ]
            message
          warns = for message in helpers.parse(output, regexW)
            message.type = 'Warning'
            r = message.range; s = r[0]; e = r[1]
            message.range = [ [ s[0],s[1] + 1 ] , [ e[0], e[1] + 3 ] ]
            message
          return errors.concat(warns)
