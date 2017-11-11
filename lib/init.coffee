module.exports =
  config:
    pactPath:
      type: 'string'
      default: 'pact'
    pactExcerptSize:
      type: 'integer'
      default: 80

  doTrace: false

  subscriptions: null

  toggleTrace: ->
    this.doTrace = !this.doTrace

  activate: ->
    require('atom-package-deps').install()
    {CompositeDisposable} = require 'atom'
    this.subscriptions = new CompositeDisposable()
    me = this
    this.subscriptions.add(atom.commands.add('atom-workspace',
      {'pact-atom:toggleTrace': -> me.toggleTrace()}))

  deactivate: ->
    this.subscriptions.dispose()

  provideLinter: ->
    helpers = require('atom-linter')
    # regex = '.*:(?<line>\\d+):(?<col>\\d+): error: (?<message>.*)'
    regexW = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):Warning:(?<message>(\\s+.*\\n)+)'
    regexT = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):Trace:(?<message>(\\s+.*\\n)+)'
    regexE = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):(?<message>(\\s+.*\\n)+)'
    exSize = atom.config.get('pact-atom.pactExcerptSize') or 80

    parseToMessage = (doWidth, sev, m) =>
      [[ss,sl],[es,el]] = m.range;
      ex = m.text
      if (ex.length > exSize)
        ex = ex.substring(0,exSize) + "..."
      message =
        severity: sev
        location:
          file: m.filePath
          position: if doWidth then [ [ ss,sl + 1 ] , [ es, el + 3 ] ] else m.range
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

        parameters = ["-r", filePath ]
        if (this.doTrace) then parameters = ["-t"].concat(parameters)

        return helpers.exec(command, parameters, {stream: 'both'}).then (output) ->
          { stderr: stderr } = output
          errors = for m in helpers.parse(stderr, regexE)
            parseToMessage(true,'error', m)
          warns = for m in helpers.parse(stderr, regexW)
            parseToMessage(true,'warning', m)
          traces = for m in helpers.parse(stderr, regexT)
            parseToMessage(false,'info', m)
          return errors.concat(warns).concat(traces)
        .catch (error) ->
          console.log error
          return []
