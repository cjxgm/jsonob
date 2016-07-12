
## JSON / Object mapper
## ====================
##
## Serialize nim objects to JSON and vice versa, without human labor.

import options
import json

const should_check_exhaustive =
    not defined(release) and
    not defined(jsonob_no_exhaustive)

when should_check_exhaustive:
    import sets

## to_json: convert values to json without human labor
## ---------------------------------------------------

proc to_json*(x: int|float|string|bool): Json_node =
    ## Convert primitive types to corresponding JSON value
    %x

proc to_json*(x: object): Json_node =
    ## Convert ``object`` to JSON object
    result = new_j_object()
    for name, value in x.field_pairs:
        result[name] = value.to_json

proc to_json*(x: tuple): Json_node =
    ## ``tuple`` is converted to JSON array
    result = new_j_array()
    for _, value in x.field_pairs:
        result.add(value.to_json)

proc to_json*[T](x: open_array[T]): Json_node =
    ## Convert array to JSON array
    result = new_j_array()
    for value in x:
        result.add(value.to_json)

proc to_json*[T](x: Option[T]): Json_node =
    ## Option type provide a safe way to handle ``nil`` (or JSON ``null``)
    if x.is_none: new_j_null()
    else: x.unsafe_get.to_json

proc `$$`*[T](x: T): string =
    ## Convert ``x`` to JSON ``string``
    $x.to_json


## from_json: convert json to value without human labor
## ----------------------------------------------------

template throw(T: typedesc, msg: string) =
    raise T.new_exception msg

proc not_nil_and_is(root: Json_node, kind: Json_node_kind) =
    if root.is_nil: Access_violation_error.throw "got nil"
    if root.kind != kind: Access_violation_error.throw "got " & $root.kind & ", but expect " & $kind

proc to*(root: Json_node, x: var int) =
    root.not_nil_and_is J_int
    x = root.num.int

proc to*(root: Json_node, x: var float) =
    root.not_nil_and_is J_float
    x = root.num.float

proc to*(root: Json_node, x: var string) =
    root.not_nil_and_is J_string
    x = root.str

proc to*(root: Json_node, x: var bool) =
    root.not_nil_and_is J_bool
    x = root.bval

# x may be nil
proc to*[T](root: Json_node, x: var seq[T]) =
    root.not_nil_and_is J_array
    x.new_seq root.len
    for i, value in x.mpairs:
        root[i].to value

# x won't be seq, so it must be arrays, thus it won't be nil (really?)
proc to*[T](root: Json_node, x: var open_array[T]) =
    root.not_nil_and_is J_array
    if x.len != root.len:
        Access_violation_error.throw "array length (" & $x.len & ") and JSON array length (" & $root.len &  ") must be the same"
    for i, value in x.mpairs:
        root[i].to value

proc to*(root: Json_node, x: var object) =
    root.not_nil_and_is J_object

    when should_check_exhaustive:
        var obj_fields = init_set[string]()

    for name, value in x.field_pairs:
        root.get_or_default(name).to value
        when should_check_exhaustive:
            obj_fields.incl(name)

    when should_check_exhaustive:
        for name, _ in root:
            if not obj_fields.contains name:
                stderr.writeline "WARNING: field not in object: ", name

proc len(x: tuple): int =
    for _, _ in x.field_pairs:
        result.inc

proc to*(root: Json_node, x: var tuple) =
    root.not_nil_and_is J_array

    let xlen = x.len
    if xlen != root.len:
        Access_violation_error.throw "tuple size (" & $xlen & ") and JSON array length (" & $root.len &  ") must be the same"

    var i = 0
    for _, value in x.field_pairs:
        root[i].to value
        i.inc

proc to*[T](root: Json_node, x: var Option[T]) =
    if root.is_nil or root.kind == J_null:
        x = none(T)
    else:
        var value: T
        root.to(value)
        x = some(value)

template to*[T](json: Json_node, _: typedesc[T]): T =
    var result: T
    json.to result
    result


when is_main_module:
    type Foo = object
        hello: int
        world: string
        yes: Option[int]
        no: Option[string]

    let a: string = nil
    echo a.to_json.to Option[string]
    echo $$123
    echo $$"123"
    echo 123.to_json.to int
    echo "123".to_json.to string

    type Bar = object
        hello: int
        yes: Option[int]

    let opt = none(int)
    echo $$opt

    let foo = Foo(hello: 32, world: "yes", yes: some(16), no: none(string))
    echo $$foo

    let bar = foo.to_json.to Bar
    echo bar

    let test: tuple[hello: string, world: int] = ("hello", 1)
    echo $$test

    echo $$[1, 2, 3]
    echo $$(@["hello", "world"])
    echo $${"hello": "1", "world": "2"}

    let s = @[1, 2, 3].to_json.to array[3, int]
    echo s[0], s[1], s[2]

    type Yes = tuple[name: int, hi: string, world: Option[array[3, int]]]
    let tt: string = nil
    let t = (2, "hello", [1, 4, 3]).to_json.to Yes
    echo $t

