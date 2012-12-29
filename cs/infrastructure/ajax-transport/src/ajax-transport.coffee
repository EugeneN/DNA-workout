{register_protocol_impl, register_protocol} = require 'libprotocol'

$ = jQuery

ITransport = [
  ['GET',     ['url', 'data', 'cb'], 'async']
  ['POST',    ['url', 'data', 'cb'], 'async']
  ['PUT',     ['url', 'data', 'cb'], 'async']
  ['DELETE',  ['url', 'data', 'cb'], 'async']
]

Transport = (node) ->

    GET: (url, data, cb) ->
      $.ajax(
        url
        data
        cb
      )

    POST: (url, data, cb) ->
      console.error 'Not implemented'
      throw 'Not implemented'

    PUT: (url, data, cb) ->
      console.error 'Not implemented'
      throw 'Not implemented'

    DELETE: (url, data, cb) ->
      console.error 'Not implemented'
      throw 'Not implemented'


register_protocol 'ITransport', ITransport
register_protocol_impl 'ITransport', Transport
