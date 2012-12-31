
module.exports =
    protocols:
        definitions:
            IMath: [
                ['len', ['array']]
            ]

        implementations:
            IMath: (node) ->
                len: (array) -> array.length or 0
