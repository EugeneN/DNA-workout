{dispatch_impl} = require 'libprotocol'
{info, warn, error, debug} = dispatch_impl 'ILogger'

_isNaN = (v) -> v isnt v

module.exports =
    protocols:
        definitions:
            INucleus: [
                ['len', ['array']]
                ['add', ['vector']]
                ['drop', ['items_vec', 'cur_item']]
                ['swap', ['items_vec', 'cur_item']]
            ]

        implementations:
            INucleus: (node) ->
                len: (array) -> array.length or 0

                add: (vec) ->
                    vec.reduce (a, b) -> (parseInt a, 10) + (parseInt b, 10)

                drop: (items, item) ->
                    item_is_in_items = if _isNaN item
                        !!(items.filter (i) -> _isNaN i).length
                    else
                        item in items

                    if item_is_in_items then null else item

                swap: ([from, to], item) ->
                    if ((_isNaN item) and (_isNaN from)) or (item is from)
                        to
                    else
                        item