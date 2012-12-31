DEBUG = true

DA_EXTEND = 'extend'
DA_SUBSCRIBE = 'subscribe'
THIS = 'this'
DNA_DATATYPES = ['string', 'number', 'vector', 'hashmap']

say = (a...) -> console.log a...

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

default_handlers_cont = (args...) -> say "DNA monadic sequence finished with results:", args

is_data = (method) -> method.type in DNA_DATATYPES

is_handler = (method) -> not (is_data method)

lift = (h) ->
    if h.async
        lift_async h.arity, h
    else
        lift_sync h.arity, h    
        
compose2 = (f, g) ->
    (args...) -> f g args...

partial = (f, partial_args...) ->
    (args...) ->
        f (partial_args.concat args)...

is_array = (a) -> Array.isArray a
    
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

    # Protocols must be unique. This must be validated on the registration step.
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

dispatch_handler_fn = (ns, method, cell) ->
    switch method.type
        when 'string'
            impl: -> method.value

        when 'number'
            impl: -> method.value

        when 'vector'
            impl: (idx, lastidx) ->
                # FIXME
                if idx and not isNaN idx
                    method.value[idx].value
                else if idx and lastidx and not (isNaN idx) and not (isNaN lastidx)
                    (i.value for i in method.value[idx...lastidx])
                else
                    (i.value for i in method.value)

        when 'hashmap'
            impl: (key) -> if key then method.value[key] else method.value

        else dispatch_handler ns?.name, method.name, cell

parse_ast_handler_node = (handler, current_cell, dom_parser) ->
    {ns, method, scope} = if is_array handler then handler[0] else handler

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

    handler_fn = (dispatch_handler_fn ns, method, cell).impl

    real_handler = if is_array handler
        partial handler_fn, (handler[1...].map (i) -> i.method.value)...
    else
        handler_fn

    real_handler.async = if handler_is_async then true else false
    real_handler.arity = handler_arity

    {impl: real_handler}

make_extended_node = (dom_parser, node) ->
    protocols = ((dom_parser.getData DA_EXTEND, node).split " ").filter (i) -> !!i
    say "Protocols found for", node, ":", protocols

    save_cell (synthesize_cell node, protocols, dom_parser)

make_monadized_handler = (dom_parser, cell, handlr) ->
    handlers_ast_list = if is_array handlr then handlr else [handlr]
    ast_parser = (h) -> (parse_ast_handler_node h, cell, dom_parser).impl
    lifted_handlers_chain = handlers_ast_list.map (compose2 lift, ast_parser)
    wrapper_monad = cont_t (maybe_m {is_error: is_null})

    (init_val) ->
        say "Starting DNA monadic sequence with arguments:", init_val
        (domonad wrapper_monad, lifted_handlers_chain, init_val) default_handlers_cont

interpose_handlers_with_events = (dom_parser, cell, handlers, evs_args) ->
    [{ns, event, scope}, raw_args...] = if is_array evs_args then evs_args else [evs_args, []]
    args = (raw_args.filter (a) -> a.event.type in DNA_DATATYPES).map (a) -> a.event.value

    handlers.map (handlr) ->
        # TBD delegate this later
        (dispatch_handler ns?.name,
                          event.name,
                          (find_cell (scope?.name or THIS), cell, dom_parser)).impl (args.concat [handlr])...

make_subscribed_node = (dom_parser, node) ->
    cell = get_create_cell node.id, node, dom_parser

    dna_sequences = parse_genome (dom_parser.getData DA_SUBSCRIBE, cell.node)
    say "DNA AST for", cell, ":", dna_sequences


    dna_sequences.map (dna_seq) ->
        dna_seq.events.map (partial interpose_handlers_with_events,
                                    dom_parser,
                                    cell,
                                    (dna_seq.handlers.map (partial make_monadized_handler,
                                                                   dom_parser,
                                                                   cell)))

synthesize_node = (dom_parser) ->
    START_TIME = new Date

    root_node = dom_parser.get_root_node()
    say 'Cells synthesis started for node', root_node

    extended_nodes = dom_parser.get_by_attr "[data-#{DA_EXTEND}]"
    subscribed_nodes = dom_parser.get_by_attr "[data-#{DA_SUBSCRIBE}]"

    extended_nodes.map (partial make_extended_node, dom_parser)
    subscribed_nodes.map (partial make_subscribed_node, dom_parser)

    say "Cells synthesis completed in #{new Date - START_TIME}ms."

module.exports =
    # Entry point
    start_synthesis: ({root_node}={}) ->
        root_idom = dispatch_impl 'IDom', root_node

        root_idom.add_event_listener "DOMNodeInserted", (event) ->
            synthesize_node (dispatch_impl 'IDom', event.target)

        synthesize_node root_idom

    dump_cells: ->
        say 'Cells synthesized for this document:', CELLS
