say = (a...) -> console.log.apply console, a

IDom = [
    ['setContent',    ['new_content']]
    ['setValue',      ['new_value']]
    ['setText',       ['new_text']]
    ['getValue',      []]
    ['getValueAsync',      ['cont'], 'async']
    ['alert',         ['msg']]
    ['click',         ['handler']]
    ['keyDown',       ['handler']]
    ['say',           ['msgs']]
    ['appendContent', ['content']]
    ['kill',          []]
    ['stop_event',    ['e']]
    ['setAttr',       ['attr']]
    ['dbclick',       ['e']]
    ['focusout',      ['e']]
    ['focus',         []]
    ['get_by_attr',   ['attr']]
    ['get_by_id',     ['id']]
    ['getData',       ['attr', 'node']]
    ['get_id',        ['node']]
    ['on_dom_ready',  ['f']]
    ['one',           ['sel']]
    ['document',      []]
    ['get_root_node', []]
    ['add_event_listener', ['event_name', 'handler']]
    ['on_change',     ['f']]
]

jqidom = (node) ->
    node or= document.body
    jnode = jQuery node

    {
        setContent: (args...) ->
            jnode.html (args.join '')

        setValue: (args...) ->
            jnode.val (args.join '')

        setText: (args...) ->
            jnode.text (args.join '')

        getValue: ->
            jnode.val()

        getValueAsync: (cont) ->
            setTimeout(
                -> cont jnode.val()
                1000
            )


        setAttr: (attr) ->
            say 'setattr'

        appendContent: (content) ->
            jnode.append "<div>#{content}</div>"

        alert: (args...) ->
            alert args...

        click: (handler) ->
            jnode.on 'click', handler

        say: (args...) ->
            say args...

        proxylog: (args...) ->
            say args...
            args

        kill: ->
            say 'kill'
            jnode.remove()

        stop_event: (e) ->
          jQuery.Event(e).stopPropagation()

        keyDown: (handler) ->
          jnode.on 'keydown', handler

        dbclick: (handler) ->
          jnode.dblclick handler

        focusout: (handler) ->
            jnode.blur handler

        focus: ->
            jnode.focus()

        get_by_attr: (attr) ->
            (jnode.find attr).toArray()

        get_by_id: (id) -> jQuery "##{id}"

        getData: (attr, node=jnode) -> (jQuery node).data()[attr]

        get_id: (node=jnode) -> (jQuery node).attr 'id'

        on_dom_ready: (f) ->  ($ document).ready f

        one: (sel) -> ($ sel)

        document: -> window.document

        get_root_node: -> node

        add_event_listener: (event_name, handler) ->
            node.addEventListener event_name, handler

        on_change: (f) ->
            jnode.change f

    }

module.exports =
    protocols:
        definitions:
            IDom: IDom
        implementations:
            IDom: jqidom
