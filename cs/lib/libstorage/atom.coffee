

IWatchable = [
  ['notify', ['?']]
  ['add_watch', ['?']]
  ['remove_watch', ['?']]
]

IPersistent = [
  ['push', ['?']]
  ['fetch', ['?']]
]

IDataStorage = [
  ['init', ['value']]
  ['swap', ['mutator']]
  ['reset', []]
]

extend_with_protocol = (type, protocol, impl) ->
  type::[k] = v for k, v of impl
  type::protocols or= {}
  type::protocols[protocol] = impl

# ------------------

class Atom
    @proto = {}

extend_with_protocol(Atom, 'IDataStorage', {
    init: (refval) ->
      @proto.IDataStorage =
        refval: refval
        storage: [refval]
      @proto.IWatchable?.notify 'data_changed'

    swap: (mutator) ->
      @proto.IDataStorage.storage.push mutator @proto.IDataStorage.storage
      @proto.IWatchable?.notify 'data_changed'

    reset: ->
      @proto.IDataStorage.storage = @proto.IDataStorage.refval
      @proto.IWatchable?.notify 'data_changed'

    read: ->
      @proto.IDataStorage?.storage[-1]
  })

extend_with_protocol(Atom, 'IWatchable', {
      notify: (key) ->
        @proto.IWatchable?.watchers?[key].map (h) ->
          h @proto.IDataStorage?.storage[-2...]...

      add_watch: (key, watch_fns...) ->
        @proto.IWatchable or= {watchers: {}}
        @proto.IWatchable.watchers[key] or= []
        @proto.IWatchable.watchers[key] = @proto.IWatchable.watchers[key].concat watch_fns

      remove_watch: (key, watch_fns...) ->
        if @proto.IWatchable?.watchers?[key]
          @proto.IWatchable.watchers[key] = \
            @proto.IWatchable.watchers[key].filter (f) -> f not in watch_fns
  })

atom = (refval) ->
  a = new Atom
  a.init refval
  a

read = (IDataStorageable) ->
  IDataStorageable.read()

swap = (IDataStorageable, mutator_fn) ->
  IDataStorageable.swap mutator_fn

reset = (IDataStorageable) ->
  IDataStorageable.reset()

add_watch = (IWatchable_inst, key, fns...) ->
  IWatchable_inst.add_watch key, fns...

remove_watch = (IWatchable_inst, key, fns...) ->
  IWatchable_inst.remove_watch key, fns...

module.exports = {atom, read, swap, reset, add_watch, remove_watch}
