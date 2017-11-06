module.exports =
  config:
    pactPath:
      type: 'string'
      default: 'pact'
    pactOptions:
      type: 'array'
      default: ['-r']
    pactExcerptSize:
      type: 'integer'
      default: 80

  activate: ->
    require('atom-package-deps').install()

  provideLinter: ->
    helpers = require('atom-linter')
    # regex = '.*:(?<line>\\d+):(?<col>\\d+): error: (?<message>.*)'
    regexW = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):Warning:(?<message>(\\s+.*\\n)+)'
    regexE = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):(?<message>(\\s+.*\\n)+)'
    exSize = atom.config.get('pact-atom.pactExcerptSize') or 80

    parseToMessage = (sev, m) =>
      [[ss,sl],[es,el]] = m.range;
      ex = m.text
      if (ex.length > exSize)
        ex = ex.substring(0,exSize) + "..."
      message =
        severity: sev
        location:
          file: m.filePath
          position: [ [ ss,sl + 1 ] , [ es, el + 3 ] ]
        description: m.text
        excerpt: ex
      [ref] = helpers.parse(m.text,' at (?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):')
      if (ref)
        message.reference =
          file: ref.filePath
          position: ref.range[0]
      message

    provider =
      grammarScopes: ['source.pact']
      scope: 'project'
      lintsOnChange: true
      name: 'Pact'

      lint: (textEditor) =>
        filePath = textEditor.getPath()
        command = atom.config.get('pact-atom.pactPath') or 'pact'
        prefOptions = atom.config.get('pact-atom.pactOptions') or []
        parameters = prefOptions.concat(["-r", filePath ])

        return helpers.exec(command, parameters, {stream: 'stderr'}).then (output) ->
          errors = for m in helpers.parse(output, regexE)
            parseToMessage('error', m)
          warns = for m in helpers.parse(output, regexW)
            parseToMessage('warning', m)
          return errors.concat(warns)
        .catch (error) ->
          console.log error
          return []
