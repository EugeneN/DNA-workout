DEBUG = true

DA_EXTEND = 'extend'
DA_SUBSCRIBE = 'subscribe'
THIS = 'this'
DNA_DATATYPES = ['string', 'number', 'vector', 'hashmap']

say = (a...) -> console.log.apply console, a

parse_genome = (require 'genome-parser').parse

{
    register_protocol_impl
    dispatch_impl
    get_protocol
    get_default_protocols
    is_async
    get_arity
} = require 'libprotocol'

{cont_t, cont_m, maybe_m, domonad, is_null, lift_sync, lift_async} = require 'libmonad'

CELLS = {}

cont = (args...) -> say "DNA monadic sequence finished with results:", args

is_data = (method) -> method.type in DNA_DATATYPES

is_handler = (method) -> not (is_data method)

get_method_ns = (name, cell) ->
    method_invariants = cell.receptors[name]

    if method_invariants?.length > 0
        method_invariants[0].ns

    else
        say "No such method: #{name} in the cell:", cell
        throw "Method missing in cell"

dispatch_handler = (ns, name, cell) ->
    method_invariants = cell.receptors[name]

    if method_invariants
        if method_invariants.length is 1 and not ns
            handler =  method_invariants[0]
        else
            handler = (cell.receptors[name].filter (m) -> m.ns is ns)[0]

        if handler
            handler
        else
            say "Handler missing", {ns, name, cell}
            throw "Handler missing"
    else
        say "Handler missing", {ns, name, cell}
        throw "Handler missing"

synthesize_cell = (node, protocols, dom_parser) ->
    unless node.id
        node.id = (dom_parser.get_id node) or Math.uuid()

    proto_cell =
        id: node.id
        node: node
        receptors: {}
        impls: {}

    # TODO:FIX: protocols must be unique !!! this must be validated on registering phase.

    all_the_protocols = _.uniq (protocols.concat get_default_protocols())

    all_the_protocols.map (protocol) ->
        p = get_protocol protocol
        proto_cell.impls[protocol] = dispatch_impl protocol, node

        if p and proto_cell.impls[protocol]
            p.map ([method, args]) ->
                m =
                    name: method
                    ns: protocol
                    impl: proto_cell.impls[protocol][method]

                if proto_cell.receptors[method]
                    proto_cell.receptors[method].push m
                else
                    proto_cell.receptors[method] = [m]

    proto_cell

save_cell = (cell) -> CELLS[cell.id] = cell

get_cell = (id) -> CELLS[id]

find_cell = (scope_id, this_cell, dom_parser) ->
    if (scope_id is THIS or not scope_id) and this_cell
        this_cell
    else if cell = get_cell scope_id
        cell
    else if cell = get_create_cell_by_id scope_id, dom_parser
        cell
    else
        null

get_create_cell = (id, node, dom_parser) ->
    if cell = get_cell id
        cell
    else
        cell = synthesize_cell node, get_default_protocols(), dom_parser
        save_cell cell
        cell

get_create_cell_by_id = (id, dom_parser) ->
    if node = dom_parser.get_by_id id
        get_create_cell id, node, dom_parser
    else
        null

parse_ast_handler_node = (handler, current_cell, dom_parser) ->
    if Array.isArray handler
        {ns, method, scope} = handler[0]
    else
        {ns, method, scope} = handler

    cell_id = scope?.name or THIS
    cell = find_cell cell_id, current_cell, dom_parser

    handler_ns = if is_handler method
        ns?.name or (get_method_ns method.name, cell)
    else
        ns?.name

    handler_is_async = if is_handler method
        is_async handler_ns, method.name
    else
        null

    handler_arity = if is_handler method
        get_arity handler_ns, method.name
    else
        null

    unless cell
        say "Unknown cell referenced in handler", cell_id, handler
        throw "Unknown cell referenced in handler"

    handler_fn = switch method.type
        when 'string'
            impl: -> method.value
        when 'number'
            impl: -> method.value
        when 'vector'
            impl: (idx, lastidx) ->
                if idx and not isNaN idx
                    method.value[idx].value
                else if idx and lastidx and not (isNaN idx) and not (isNaN lastidx)
                    (i.value for i in method.value[idx...lastidx])
                else
                    (i.value for i in method.value)
        when 'hashmap'
            impl: (key) ->
                if key
                    method.value[key]
                else
                    method.value

        else dispatch_handler ns?.name, method.name, cell

    if Array.isArray handler
        partial_args = handler[1...].map (i) -> i.method.value
        partially_applied_handler = (args...) ->
            handler_fn.impl.apply null, (partial_args.concat args)

        partially_applied_handler.async = true if handler_is_async
        partially_applied_handler.arity = handler_arity

        {impl: partially_applied_handler}

    else
        handler_fn.impl.async = true if handler_is_async
        handler_fn.impl.arity = handler_arity
        handler_fn


# Entry point
lab = (dom_parser) ->
    window.dom_parser = dom_parser if DEBUG

    root_node = dom_parser.get_root_node()

    say 'Cells synthesis started for node', root_node
    START_TIME = new Date

    cell_matrices = dom_parser.get_by_attr "[data-#{DA_EXTEND}]"
    proto_cells = dom_parser.get_by_attr "[data-#{DA_SUBSCRIBE}]"

    for node in cell_matrices
        protocols = ((dom_parser.getData DA_EXTEND, node).split " ").filter (i) -> !!i
        say "Protocols found for", node, ":", protocols

        cell = synthesize_cell node, protocols, dom_parser
        save_cell cell

    for node in proto_cells
        cell = get_create_cell node.id, node, dom_parser

        dna_sequences = parse_genome (dom_parser.getData(DA_SUBSCRIBE, cell.node))
        say "DNA AST for", cell, ":", dna_sequences

        dna_sequences.map (dna_seq) ->
            handlers = dna_seq.handlers.map (handlr) ->
                handlers_ast_list = if Array.isArray handlr then handlr else [handlr]
                ast_parser = (h) ->
                    m = parse_ast_handler_node h, cell, dom_parser
                    m.impl

                handlers_chain = handlers_ast_list.map ast_parser

                lifted_handlers_chain = handlers_chain.map (h) ->
                    if h.async
                        lift_async h.arity, h
                    else
                        lift_sync h.arity, h

                cont_maybe_m = cont_t (maybe_m {is_error: is_null})

                (init_val) ->
                    say "Starting SNA monadic sequence with arguments:", init_val
                    (domonad cont_maybe_m, lifted_handlers_chain, init_val) cont

#                _.compose(handler_chain.reverse()...)

            dna_seq.events.map (events) ->
                [{ns, event, scope}, raw_args...] = if Array.isArray events
                    events
                else
                    [events, []]

                args = (raw_args.filter (a) ->
                          a.event.type in ['number', 'string', 'vector']).map (a) ->
                                                                           a.event.value
                say 'event args', args

                handlers.map (handlr) ->
                    # TBD delegate this later
                    event_scope_cell = find_cell (scope?.name or THIS), cell, dom_parser

                    h = dispatch_handler ns?.name, event.name, event_scope_cell
                    if args.length > 0
                        h.impl (args.concat [handlr])
                    else
                        h.impl handlr


        say "Cells synthesis completed in #{new Date - START_TIME}ms."

module.exports =
    start_synthesis: ({idom, root_node}={}) ->
        root_idom = idom or (dispatch_impl 'IDom', document.body)

        root_idom.document().addEventListener "DOMNodeInserted", (event) ->
            lab (dispatch_impl 'IDom', event.target)

        lab root_idom

    dump_cells: ->
        say 'Cells synthesized for this document:', CELLS



