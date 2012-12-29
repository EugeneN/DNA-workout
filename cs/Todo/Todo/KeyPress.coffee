
IKeyFilter = [
    ['get_key',   ['key_event', 'cont'], 'async']
    ['onKeyPass', ['key']]
    ['onKeyFail', ['key']]
    ['check_key', ['key', 'allowed_keys']]
]

JQueryKeyFilter = (node) ->
    event_handlers =
        onKeyPass: []

    fire_onPpass = (key) ->
        event_handlers.onKeyPass.map (h) ->
            h key

    get_key: (ev, cont) ->
        setTimeout(
            -> cont ev.keyCode
            1234
        )
        #ev.keyCode

    check_key: (allowed_keys, key) ->
        fire_onPpass(key) if key in (allowed_keys.map (i) -> i.value)

    onKeyPass: ([keycode, f]) ->
        event_handlers.onKeyPass.push (key) -> f() if key is keycode


module.exports =
    protocols:
        definitions:
            IKeyFilter: IKeyFilter
        implementations:
            IKeyFilter: JQueryKeyFilter
