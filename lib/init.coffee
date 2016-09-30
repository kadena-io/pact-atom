module.exports =
  config:
    pactPath:
      type: 'string'
      default: 'pact'

  activate: ->
    require('atom-package-deps').install()

  provideLinter: ->
    helpers = require('atom-linter')
    # regex = '.*:(?<line>\\d+):(?<col>\\d+): error: (?<message>.*)'
    regex = '[^:]*:(?<line>\\d+):(?<col>\\d+):(?<message>.+)'
    provider =
      grammarScopes: ['source.pact']
      scope: 'file'
      lintOnFly: true
      lint: (textEditor) =>
        filePath = textEditor.getPath()
        command = atom.config.get('pact-atom.pactPath') or 'pact'
        parameters = [ filePath ]

        return helpers.exec(command, parameters, {stream: 'stderr'}).then (output) ->
          errors = for message in helpers.parse(output, regex, {filePath: filePath})
            message.type = 'error'
            message

          return errors
