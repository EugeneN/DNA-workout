
module.exports =
    protocols:
        definitions:
            IMath: [
                ['len', ['array']]
                ['add', ['vector']]
            ]

        implementations:
            IMath: (node) ->
                len: (array) -> array.length or 0

                add: (vec) ->
                    vec.reduce (a, b) -> (parseInt a, 10) + (parseInt b, 10)