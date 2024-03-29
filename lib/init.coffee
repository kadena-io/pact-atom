module.exports =
  config:
    pactPath:
      type: 'string'
      default: 'pact'
    pactExcerptSize:
      type: 'integer'
      default: 80

  doTrace: true

  doCoverage: false

  subscriptions: null

  toggleTrace: ->
    this.doTrace = !this.doTrace
    atom.commands.dispatch(
      atom.views.getView(atom.workspace.getActiveTextEditor()),
      'linter:lint')

  toggleCoverage: ->
    this.doCoverage = !this.doCoverage
    atom.commands.dispatch(
      atom.views.getView(atom.workspace.getActiveTextEditor()),
      'linter:lint')

  activate: ->
    {CompositeDisposable} = require 'atom'
    require('atom-package-deps').install('language-pact')
    this.subscriptions = new CompositeDisposable()
    me = this
    this.subscriptions.add(atom.commands.add('atom-workspace',
      {'pact-atom:toggleTrace': -> me.toggleTrace()}))
    this.subscriptions.add(atom.commands.add('atom-workspace',
      {'pact-atom:toggleCoverage': -> me.toggleCoverage()}))

  deactivate: ->
    this.subscriptions.dispose()

  provideLinter: ->

    helpers = require('atom-linter')
    # regex = '.*:(?<line>\\d+):(?<col>\\d+): error: (?<message>.*)'
    regexAll = '(?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):((?<type>[^:]+):)?(?<message>(\\s+.*\\n)+)'

    widenRange = (r) =>
      [[ss,sl],[es,el]] = r;
      [[ss,sl+1],[es,el+3]]

    parseToMessage = (m) =>
      #console.log(m)
      excerpt = m.text
      messageLines = m.text.split('\n')
      description = m.text
      multiline = false
      exSize = atom.config.get('language-pact.pactExcerptSize') or 80

      sev = 'error'
      doWidth = true
      if m.type == "Trace"
        sev = 'info'
        doWidth = false
      else
        if m.type == "Warning"
          sev = 'warning'

      # the message is already multiple lines
      if (messageLines.length > 1)
        excerpt = messageLines[0]

        # this is our slightly hacky way to format as markdown. if a line has
        # exactly two leading spaces it's a header, otherwise it'll have at
        # least four and it's already a code block.
        messageLines = messageLines.map((line) ->
          if /^  \S/.test(line) then '######' + line else line
        )
        description = messageLines.slice(1).join('\n')

        multiline = true

      # the message is too long to fit in the excerpt
      else if (excerpt.length > exSize)
        excerpt = excerpt.substring(0,exSize) + "..."

      message =
        severity: sev
        location:
          file: m.filePath
          position: if doWidth then widenRange(m.range) else m.range
        description: description
        excerpt: excerpt
        multiline: multiline
      refs = helpers.parse(m.text,' at (?<file>[^:\\n]*):(?<line>\\d+):(?<col>\\d+):')
      if (refs.length > 0)
        ref = refs.slice(-1)[0]
        if (ref.filePath == m.filePath)
          [message]
        else
          message.reference =
            file: ref.filePath
            position: ref.range[0]
          msg2 =
            severity: sev
            location:
              file: ref.filePath
              position: widenRange(ref.range)
            description: description
            excerpt: excerpt
            multiline: false
            reference:
              file: m.filePath
              position: m.range[0]
          [message, msg2]
      else
        [message]

    parseErrs = (stderr, re) =>
      es = for m in helpers.parse(stderr,re)
             parseToMessage(m)
      [].concat.apply([],es).sort(cmpSev)

    cmpSev = (e,f) =>
      es = ordSev e
      fs = ordSev f
      if (es < fs)
        return -1
      else if (es > fs)
        return 1
      else
        return 0

    ordSev = (e) =>
      if (e.severity == 'warning')
        return 1
      else if (e.severity == 'info')
        return 2
      else
        return 0


    provider =
      grammarScopes: ['source.pact']
      scope: 'project'
      lintsOnChange: true
      name: 'Pact'

      lint: (textEditor) =>
        filePath = textEditor.getPath()
        command = atom.config.get('language-pact.pactPath') or 'pact'

        parameters = ["-r", filePath ]
        if (this.doTrace) then parameters = ["-t"].concat(parameters)
        if (this.doCoverage) then parameters = ["-c"].concat(parameters)
        #console.log(parameters)

        return helpers.exec(command, parameters, {stream: 'both', timeout: Infinity }).then (output) ->
          { stderr: stderr } = output
          parseErrs(stderr,regexAll)
        .catch (error) ->
          if (error.toString().indexOf("ENOENT") != -1)
            error = error + " [pact tool not installed?]"

          atom.notifications.addError('Error in pact linting',
            { detail: error + "\n" +
               "Command: " + command + " " + parameters.join(' ')
            , dismissable: true });
          #console.log error
          return []
