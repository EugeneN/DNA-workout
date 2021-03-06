%lex
%%

\s+                    /* skip whitespace */
[0-9]+                 return 'NUMBER'
\"(\\.|[^\\"]*?)\"     return 'STRING'
"NaN"                  return 'NAN'
"null"                 return 'NULL'
[A-Za-z_][A-Za-z0-9_]* return 'IDENTIFIER'
\"                     return 'DBLQUOTE'
"("                    return '('
")"                    return ')'
"["                    return '['
"]"                    return ']'
"^"                    return '^'
":"                    return ':'
"@"                    return '@'
"|"                    return '|'
","                    return ','
"/"                    return '/'
";"                    return ';'
<<EOF>>                return 'EOF'
.                      return 'INVALID'

/lex

/* operator associations and precedence */
%left ',' '|' ';' '/'
%right ':'

%start program

%%

program
    :
    | text EOF
        {{
           //console.log($1);
           return $1;
        }}
    ;

text
    : statement
        %{ $$ = [$1]; %}
    | text ';' statement
        %{
           $$ = ($1).concat($3);
        %}
    ;

statement
    : ';'
    | event_binding_def
        {{ $$ = $1; }}
    ;

event_binding_def
    : events ':' handlers
        %{ $$ = {events: $1, handlers: $3}; %}
    ;

events
    : event_expression
        %{ $$ = [$1]; %}
    | events ',' event_expression
        %{ $$ = ($1).concat([$3]); %}
    ;

event_expression
    : event
        {{ $$ = [$1]; }}
    | event_expression event
        {{ $$ = Array.isArray($1) ? ($1).concat([$2]) : [$1, $2]; }}
    ;

event
    : symbol
        %{ $$ = {ns: undefined, event: $1, scope: undefined}; %}
    | symbol '/' symbol
        %{ $$ = {ns: $1, event: $2, scope: undefined}; %}
    | symbol '@' symbol
        %{ $$ = {ns: undefined, event: $1, scope: $3}; %}
    | symbol '/' symbol '@' symbol
        %{ $$ = {ns: $1, event: $3, scope: $5}; %}
    ;

handlers
    : handler
        %{ $$ = [$1]; %}
    | handlers ',' handler
        %{ $$ = ($1).concat([$3]); %}
    ;

handler
    : handler_expression
        {{ $$ = $1; }}
    | handler '|' handler_expression
        {{ $$ = Array.isArray($1) ? ($1).concat([$3]) : [$1, $3]; }}
    ;

handler_expression
    : partially_applied_handler
        {{ $$ = [$1]; }}
    | handler_expression partially_applied_handler
        {{ $$ = Array.isArray($1) ? ($1).concat([$2]) : [$1, $2]; }}
    ;

partially_applied_handler
    : symbol
        {{ $$ = {ns: undefined, method: $1, scope: undefined}; }}
    | symbol '/' symbol
        {{ $$ = {ns: $1, method: $3, scope: undefined}; }}
    | symbol '@' symbol
        {{ $$ = {ns: undefined, method: $1, scope: $3}; }}
    | symbol '/' symbol '@' symbol
        {{ $$ = {ns: $1, method: $3, scope: $5}; }}
    ;

symbol
    : NAN
        {{ $$ = { type: "NaN", value: NaN }; }}
    | NULL
        {{ $$ = { type: "null", value: null }; }}
    | IDENTIFIER
        {{ $$ = { type: "symbol", name: $1 }; }}
    | NUMBER
        {{ $$ = { type: "number", value: parseInt($1, 10)}; }}
    | STRING
        {{ $$ = { type: "string", value: ($1).match('\"(\\.|[^\\"]*?)\"')[1] }; }}
    | '[' vec_items_list ']'
        {{ $$ = { type: "vector", value: $2}; }}
    ;

vec_items_list
    :
        {{ $$ = []; }}
    | vec_item vec_items_list
        {{ $$ = $1.concat($2) }}
    ;

vec_item
    : partially_applied_handler
        {{ $$ = [$1] }}
    | symbol
        {{ $$ = [$1]; }}
    ;


