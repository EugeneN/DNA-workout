
ITodoList = [
    ['add_item',         ['item']]
    ['get_items',        []]
    ['get_undone_items', []]
    ['get_items_view',   []]
    ['clear_completed',  []]
    ['onModelChanged',   ['f']]
    ['remove_item',      ['item_id']]
    ['toggle_done',      ['item_id']]
    ['edit_item',        ['item_id']]
    ['set_item_val',     ['val', 'item_id']]
    ['reset_editing',    []]
]


List = (node) ->
    model = []
    event_handlers =
        onModelChanged: []

    model_changed = ->
        event_handlers.onModelChanged.map (h) ->
            h model

    add_item: (value) ->
        model.push {value: value, id: Math.uuid(), done: false, edit: false}
        model_changed()

    get_items: ->
        model

    toggle_done: (item_id) ->
        model = model.map (item) ->
            if item.id is item_id
                item.done = !item.done
            item
        model_changed()

    get_items_view: ->
        (model.map (item) ->
            require('views/list_item')(item)).reverse().join ''

    get_undone_items: ->
        (item for item in model when not item.done)

    clear_completed: ->
        model = (item for item in model when not item.done)
        model_changed()

    remove_item: (item_id) ->
        model = model.filter ({id}) -> id isnt item_id
        model_changed()

    edit_item: (item_id) ->
        model = model.map (item) ->
            if item.id is item_id
                item.edit = true
            item
        model_changed()

    set_item_val: (item_id, val) ->
        model = model.map (item) ->
            if item.id is item_id
                item.value = val
                item.edit = false
            item
        model_changed()

    onModelChanged: (f) ->
        event_handlers.onModelChanged.push f

    reset_editing: ->
        model = model.map (item) ->
            item.edit = false
            item
        model_changed()


module.exports =
    protocols:
        definitions:
            ITodoList: ITodoList
        implementations:
            ITodoList: List
