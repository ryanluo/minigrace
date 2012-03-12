import io
import sys
import ast
import util

var tmp
var verbosity := 30
var pad1 := 1
var auto_count := 0
var constants := []
var output := []
var usedvars := []
var declaredvars := []
var bblock := "entry"
var linenum := 0
var modules := []
var staticmodules := []
var values := []
var outfile
var modname := "main"
var runmode := "build"
var buildtype := "bc"
var gracelibPath := "gracelib.o"
var inBlock := false
var compilationDepth := 0

method out(s) {
    output.push(s)
}
method outprint(s) {
    util.outprint(s)
}
method log_verbose(s) {
    util.log_verbose(s)
}
method escapeident(vn) {
    var nm := ""
    for (vn) do {c->
        var o := c.ord
        if (((o >= 97 ) & (o <= 122)) | ((o >= 65) & (o <= 90))
            | ((o >= 48) & (o <= 57))) then {
            nm := nm ++ c
        } else {
            nm := nm ++ "__" ++ o ++ "__"
        }
    }
    nm
}
method varf(vn) {
    "var_" ++ escapeident(vn)
}
method beginblock(s) {
    bblock := "%" ++ s
    out(s ++ ":")
}
method compilearray(o) {
    var myc := auto_count
    auto_count := auto_count + 1
    var r
    var vals := []
    for (o.value) do {a ->
        r := compilenode(a)
        vals.push(r)
    }
    out("  var array" ++ myc ++ " = new GraceList([")
    for (vals) do {v->
        out(v ++ ",")
    }
    out("]);\n")
    o.register := "array" ++ myc
}
method compilemember(o) {
    // Member in value position is actually a nullary method call.
    var l := []
    var c := ast.astcall(o, l)
    var r := compilenode(c)
    o.register := r
}
method compileobjouter(selfr, outerRef) {
    var myc := auto_count
    auto_count := auto_count + 1
    var nm := escapestring("outer")
    var nmi := escapeident("outer")
    out("  " ++ selfr ++ ".outer = " ++ outerRef ++ ";")
    out("    var reader_" ++ modname ++ "_" ++ nmi ++ myc ++ " = function() \{")
    out("    return this.outer;")
    out("  \}")
    out("  " ++ selfr ++ ".methods[\"" ++ nm ++ "\"] = reader_" ++ modname ++
        "_" ++ nmi ++ myc ++ ";")
}
method compileobjdefdec(o, selfr, pos) {
    var val := "undefined"
    if (false != o.value) then {
        if (o.value.kind == "object") then {
            compileobject(o.value, selfr)
            val := o.value.register
        } else {
            val := compilenode(o.value)
        }
    }
    var myc := auto_count
    auto_count := auto_count + 1
    var nm := escapestring(o.name.value)
    var nmi := escapeident(o.name.value)
    out("  " ++ selfr ++ ".data[\"" ++ nm ++ "\"] = " ++ val ++ ";")
    out("    var reader_" ++ modname ++ "_" ++ nmi ++ myc ++ " = function() \{")
    out("    return this.data[\"" ++ nm ++ "\"];")
    out("  \}")
    out("  " ++ selfr ++ ".methods[\"" ++ nm ++ "\"] = reader_" ++ modname ++
        "_" ++ nmi ++ myc ++ ";")
}
method compileobjvardec(o, selfr, pos) {
    var val := "undefined"
    if (false != o.value) then {
        val := compilenode(o.value)
    }
    var myc := auto_count
    auto_count := auto_count + 1
    var nm := escapestring(o.name.value)
    var nmi := escapeident(o.name.value)
    out("  " ++ selfr ++ ".data[\"" ++ nm ++ "\"] = " ++ val ++ ";")
    out("    var reader_" ++ modname ++ "_" ++ nmi ++ myc ++ " = function() \{")
    out("    return this.data[\"" ++ nm ++ "\"];")
    out("  \}")
    out("  " ++ selfr ++ ".methods[\"" ++ nm ++ "\"] = reader_" ++ modname ++
        "_" ++ nmi ++ myc ++ ";")
    out("  " ++ selfr ++ ".data[\"" ++ nm ++ "\"] = " ++ val ++ ";")
    out("  var writer_" ++ modname ++ "_" ++ nmi ++ myc ++ " = function(o) \{")
    out("    this.data[\"" ++ nm ++ "\"] = o;")
    out("  \}")
    out("  " ++ selfr ++ ".methods[\"" ++ nm ++ ":=\"] = writer_" ++ modname ++
        "_" ++ nmi ++ myc ++ ";")
}
method compileclass(o) {
    var params := o.params
    var mbody := [ast.astobject(o.value, o.superclass)]
    var newmeth := ast.astmethod(ast.astidentifier("new", false), params, mbody,
        false)
    var obody := [newmeth]
    var cobj := ast.astobject(obody, false)
    var con := ast.astdefdec(o.name, cobj, false)
    if ((compilationDepth == 1) && {o.name.kind != "generic"}) then {
        def meth = ast.astmethod(o.name, [], [o.name], false)
        compilenode(meth)
    }
    o.register := compilenode(con)
}
method compileobject(o, outerRef) {
    var origInBlock := inBlock
    inBlock := false
    var myc := auto_count
    auto_count := auto_count + 1
    var selfr := "obj" ++ myc
    var superobj := false
    for (o.value) do {e->
        if (e.kind == "inherits") then {
            superobj := e.value
        }
    }
    if (superobj /= false) then {
        var sup := compilenode(superobj)
        out("  var {selfr} = Grace_allocObject();")
        out("  {selfr}.superobj = {sup};")
        out("  {selfr}.data = {sup}.data;")
    } else {
        out("  var " ++ selfr ++ " = Grace_allocObject();")
    }
    compileobjouter(selfr, outerRef)
    out("function obj_init_{myc}() \{")
    out("  var origSuperDepth = superDepth;")
    out("  superDepth = this;")
    var pos := 0
    for (o.value) do { e ->
        if (e.kind == "method") then {
            compilemethod(e, selfr)
        } elseif (e.kind == "vardec") then {
            compileobjvardec(e, selfr, pos)
            pos := pos + 1
        } elseif (e.kind == "defdec") then {
            compileobjdefdec(e, selfr, pos)
            pos := pos + 1
        } elseif (e.kind == "object") then {
            compileobject(e, selfr)
        } else {
            compilenode(e)
        }
    }
    out("  superDepth = origSuperDepth;")
    out("\}")
    out("obj_init_{myc}.apply({selfr}, []);")
    o.register := selfr
    inBlock := origInBlock
}
method compileblock(o) {
    var origInBlock := inBlock
    inBlock := true
    var myc := auto_count
    auto_count := auto_count + 1
    out("  var block" ++ myc ++ " = Grace_allocObject();")
    out("  block" ++ myc ++ ".methods[\"apply\"] = function() \{")
    out("    return this.real.apply(this.receiver, arguments);")
    out("  \}")
    out("  block" ++ myc ++ ".methods[\"applyIndirectly\"] = function(a) \{")
    out("    return this.real.apply(this.receiver, a._value);")
    out("  \}")
    out("  block" ++ myc ++ ".receiver = this;")
    out("  block" ++ myc ++ ".real = function(")
    var first := true
    for (o.params) do {p->
        if (first.not) then {
            out(",")
        }
        first := false
        out(varf(p.value))
    }
    out(") \{")
    var ret := "undefined"
    for (o.body) do {l->
        ret := compilenode(l)
    }
    out("  return " ++ ret ++ ";")
    out("\};")
    o.register := "block" ++ myc
    inBlock := origInBlock
}
method compilefor(o) {
    var myc := auto_count
    auto_count := auto_count + 1
    var over := compilenode(o.value)
    var blk := o.body
    var blko := compilenode(blk)
    out("  var it" ++ myc ++ " = " ++ over ++ ".methods[\"iterator\"].call("
        ++ over ++ ");")
    out("while (Grace_isTrue(it" ++ myc ++ ".methods[\"havemore\"].call("
        ++ "it" ++ myc ++ "))) \{")
    out("    var fv" ++ myc ++ " = it" ++ myc ++ ".methods[\"next\"].call("
        ++ "it" ++ myc ++ ");")
    out("    "++blko++".methods[\"apply\"].call("++blko++", fv" ++ myc ++ ");")
    out("  \}")
    o.register := over
}
method compilemethod(o, selfobj) {
    var oldusedvars := usedvars
    var olddeclaredvars := declaredvars
    usedvars := []
    declaredvars := []
    var myc := auto_count
    auto_count := auto_count + 1
    var name := escapestring(o.value.value)
    var nm := name ++ myc
    var closurevars := []
    out("var func" ++ myc ++ " = function(")
    var first := true
    for (o.params) do { p ->
        if (first.not) then {
            out(",")
        }
        out(varf(p.value))
        first := false
    }
    out(") \{")
    if (o.varargs) then {
        out("  var {varf(o.vararg.value)} = new GraceList(Array.prototype.slice"
            ++ ".call(arguments, {o.params.size}));")
    }
    out("  var returnTarget = invocationCount;")
    out("  invocationCount++;")
    out("  try \{")
    var ret := "undefined"
    for (o.body) do { l ->
        ret := compilenode(l)
    }
    out("  return " ++ ret)
    out("  \} catch(e) \{")
    out("    if ((e.exctype == 'return') && (e.target == returnTarget)) \{")
    out("      return e.returnvalue;")
    out("    \} else \{")
    out("      throw e;")
    out("    \}")
    out("  \}")
    out("\}")
    usedvars := oldusedvars
    declaredvars := olddeclaredvars
    out("  " ++ selfobj ++ ".methods[\"" ++ name ++ "\"] = func" ++ myc ++ ";")
}
method compilewhile(o) {
    var myc := auto_count
    auto_count := auto_count + 1
    var cond := compilenode(o.value)
    out("  var wcond" ++ myc ++ " = Grace_isTrue(" ++ cond ++ ");")
    out("  while (wcond" ++ myc ++ ") \{")
    var tret := "null"
    for (o.body) do { l->
        tret := compilenode(l)
    }
    cond := compilenode(o.value)
    out("  wcond" ++ myc ++ " = Grace_isTrue(" ++ cond ++ ");")
    out("  \}")
    o.register := cond // "%while" ++ myc
}
method compileif(o) {
    var myc := auto_count
    auto_count := auto_count + 1
    out("  if (Grace_isTrue(" ++ compilenode(o.value) ++ ")) \{")
    var tret := "undefined"
    var fret := "undefined"
    for (o.thenblock) do { l->
        tret := compilenode(l)
    }
    out("  var if" ++ myc ++ " = " ++ tret ++ ";")
    if (o.elseblock.size > 0) then {
        out("  \} else \{")
        for (o.elseblock) do { l->
            fret := compilenode(l)
        }
        out("  var if" ++ myc ++ " = " ++ fret ++ ";")
    }
    out("\}")
    o.register := "if" ++ myc
}
method compileidentifier(o) {
    var name := o.value
    if (name == "self") then {
        o.register := "this"
    } else {
        if (modules.contains(name)) then {
            out("  // WARNING: module support not implemented in JS backend")
            out("  \"var_val_" ++ name ++ auto_count
                ++ "\" = load %object** @.module." ++ name)
        } else {
            usedvars.push(name)
            o.register := varf(name)
        }
    }
}
method compilebind(o) {
    var dest := o.dest
    var val := ""
    var c := ""
    var r := ""
    if (dest.kind == "identifier") then {
        val := o.value
        val := compilenode(val)
        var nm := escapestring(dest.value)
        usedvars.push(nm)
        out("  " ++ varf(nm) ++ " = " ++ val ++ ";")
        o.register := val
    } elseif (dest.kind == "member") then {
        dest.value := dest.value ++ ":="
        c := ast.astcall(dest, [o.value])
        r := compilenode(c)
        o.register := r
    } elseif (dest.kind == "index") then {
        var imem := ast.astmember("[]:=", dest.value)
        c := ast.astcall(imem, [dest.index, o.value])
        r := compilenode(c)
        o.register := r
    }
}
method compiledefdec(o) {
    var nm
    if (o.name.kind == "generic") then {
        nm := escapestring(o.name.value.value)
    } else {
        nm := escapestring(o.name.value)
    }
    declaredvars.push(nm)
    var val := o.value
    if (val) then {
        val := compilenode(val)
    } else {
        util.syntax_error("const must have value bound.")
    }
    out("  var " ++ varf(nm) ++ " = " ++ val ++ ";")
    if (compilationDepth == 1) then {
        compilenode(ast.astmethod(o.name, [], [o.name], false))
    }
    o.register := val
}
method compilevardec(o) {
    var nm := escapestring(o.name.value)
    declaredvars.push(nm)
    var val := o.value
    if (val) then {
        val := compilenode(val)
        out("  var " ++ varf(nm) ++ " = " ++ val ++ ";")
    } else {
        out("  var " ++ varf(nm) ++ ";")
        val := "false"
    }
    if (compilationDepth == 1) then {
        compilenode(ast.astmethod(o.name, [], [o.name], false))
        def assignID = ast.astidentifier(o.name.value ++ ":=", false)
        def tmpID = ast.astidentifier("_var_assign_tmp", false)
        compilenode(ast.astmethod(assignID, [tmpID],
            [ast.astbind(o.name, tmpID)], false))
    }
    o.register := val
}
method compileindex(o) {
    var of := compilenode(o.value)
    var index := compilenode(o.index)
    out("  var idxres" ++ auto_count ++ " = " ++ of ++ ".methods[\"[]\"]"
        ++ ".call(" ++ of ++ ", " ++ index ++ ");")
    o.register := "idxres" ++ auto_count
    auto_count := auto_count + 1
}
method compilematchcase(o) {
    def myc = auto_count
    auto_count := auto_count + 1
    def cases = o.cases
    def matchee = compilenode(o.value)
    out("  var cases{myc} = [];")
    for (cases) do {c->
        def e = compilenode(c)
        out("  cases{myc}.push({e});")
    }
    var elsecase := "false"
    if (false != o.elsecase) then {
        elsecase := compilenode(o.elsecase)
    }
    out("  var matchres{myc} = matchCase({matchee},cases{myc},{elsecase});")
    o.register := "matchres" ++ myc
}
method compileop(o) {
    var left := compilenode(o.left)
    var right := compilenode(o.right)
    auto_count := auto_count + 1
    var rnm := "opresult"
    if (o.value == "*") then {
        rnm := "prod"
    }
    if (o.value == "/") then {
        rnm := "quotient"
    }
    if (o.value == "-") then {
        rnm := "diff"
    }
    if (o.value == "%") then {
        rnm := "modulus"
    }
    out("  var " ++ rnm ++ auto_count ++ " = callmethod(" ++ left
        ++ ", \"" ++ o.value ++ "\", "
        ++ right ++ ");")
    o.register := rnm ++ auto_count
    auto_count := auto_count + 1
}
method compilecall(o) {
    var args := []
    var obj := ""
    var len := 0
    var con := ""
    for (o.with) do { p ->
        var r := compilenode(p)
        args.push(r)
    }
    if ((o.value.kind == "member") && {(o.value.in.kind == "identifier")
        & (o.value.in.value == "super")}) then {
        out("  var call" ++ auto_count ++ " = callmethodsuper(this"
            ++ ",\"" ++ escapestring(o.value.value) ++ "\"")
        for (args) do { arg ->
            out(", " ++ arg)
        }
        out(");")
    } elseif ((o.value.kind == "member") && {(o.value.in.kind == "identifier")
        & (o.value.in.value == "self") & (o.value.value == "outer")}
        ) then {
        out("  var call{auto_count} = callmethod(superDepth, "
            ++ "\"outer\");")
    } elseif (o.value.kind == "member") then {
        obj := compilenode(o.value.in)
        out("  var call" ++ auto_count ++ " = callmethod(" ++ obj
            ++ ",\"" ++ escapestring(o.value.value) ++ "\"")
        for (args) do { arg ->
            out(", " ++ arg)
        }
        out(");")
    } else {
        obj := "this"
        out("  var call" ++ auto_count ++ " = callmethod(this,"
            ++ "\"" ++ escapestring(o.value.value) ++ "\"")
        for (args) do { arg->
            out(", " ++ arg)
        }
        out(");")
    }
    o.register := "call" ++ auto_count
    auto_count := auto_count + 1
}
method compileoctets(o) {
    var escval := ""
    var l := length(o.value) / 2
    var i := 0
    for (o.value) do {c->
        if ((i % 2) == 0) then {
            escval := escval ++ "\\"
        }
        escval := escval ++ c
        i := i + 1
    }
    out("  %tmp" ++ auto_count ++ " = load %object** @.octlit"
        ++ auto_count)
    out("  %cmp" ++ auto_count ++ " = icmp ne %object* %tmp"
        ++ auto_count ++ ", null")
    out("  br i1 %cmp" ++ auto_count ++ ", label %octlit"
        ++ auto_count ++ ".already, label %octlit"
        ++ auto_count ++ ".define")
    beginblock("octlit" ++ auto_count ++ ".already")
    out("  %alreadyoctets" ++ auto_count ++ " = load %object** @.octlit"
        ++ auto_count)
    out("  br label %octlit" ++ auto_count ++ ".end")
    beginblock("octlit" ++ auto_count ++ ".define")
    out("  %oct" ++ auto_count ++ " = getelementptr [" ++ l ++ " x i8]* @.oct" ++ constants.size ++ ", i32 0, i32 0")
    out("  %defoctets" ++ auto_count ++ " = call %object* "
        ++ "@alloc_Octets(i8* "
          ++ "%oct" ++ auto_count ++ ", i32 " ++ l ++ ")")
    out("  store %object* %defoctets" ++ auto_count ++ ", %object** "
        ++ "@.octlit" ++ auto_count)
    out("br label %octlit" ++ auto_count ++ ".end")
    beginblock("octlit" ++ auto_count ++ ".end")
    out(" %octets" ++ auto_count ++ " = phi %object* [%alreadyoctets"
        ++ auto_count ++ ", %octlit" ++ auto_count ++ ".already], "
        ++ "[%defoctets" ++ auto_count ++ ", %octlit" ++ auto_count
        ++ ".define]")
    var con := "@.oct" ++ constants.size ++ " = private unnamed_addr "
        ++ "constant [" ++ l ++ " x i8] c\"" ++ escval ++ "\""
    constants.push(con)
    con := ("@.octlit" ++ auto_count
        ++ " = private global %object* null")
    constants.push(con)
    o.register := "%octets" ++ auto_count
    auto_count := auto_count + 1
}
method compileimport(o) {
    out("// Import of " ++ o.value.value)
    var con
    var nm := escapestring(o.value.value)
    out("  var " ++ varf(nm) ++ " = do_import(\"{nm}\", gracecode_{nm});")
    o.register := "undefined"
}
method compilereturn(o) {
    var reg := compilenode(o.value)
    if (inBlock) then {
        out("  throw new ReturnException(" ++ reg ++ ", returnTarget);")
    } else {
        out("  return " ++ reg)
    }
    o.register := "undefined"
}
method compilenode(o) {
    compilationDepth := compilationDepth + 1
    if (linenum /= o.line) then {
        linenum := o.line
        out("  lineNumber = " ++ linenum);
    }
    if (o.kind == "num") then {
        o.register := "new GraceNum(" ++ o.value ++ ")"
    }
    var l := ""
    if (o.kind == "string") then {
        l := length(o.value)
        l := l + 1
        var os := ""
        // Escape characters that may not be legal in string literals
        for (o.value) do {c->
            if (c == "\"") then {
                os := os ++ "\\\""
            } elseif (c == "\\") then {
                os := os ++ "\\\\"
            } elseif (c == "\n") then {
                os := os ++ "\\n"
            } elseif ((c.ord < 32) | (c.ord > 126)) then {
                var uh := util.hex(c.ord)
                while {uh.size < 4} do {
                    uh := "0" ++ uh
                }
                os := os ++ "\\u" ++ uh
            } else {
                os := os ++ c
            }
        }
        var sval := o.value.replace("\\")with("\\\\")
        sval := sval.replace("\"")with("\\\"")
        sval := sval.replace("\n")with("\\n")
        out("  var string" ++ auto_count ++ " = new GraceString(\""
            ++ os ++ "\");")
        o.register := "string" ++ auto_count
        auto_count := auto_count + 1
    }
    if (o.kind == "index") then {
        compileindex(o)
    }
    if (o.kind == "octets") then {
        compileoctets(o)
    }
    if (o.kind == "import") then {
        compileimport(o)
    }
    if (o.kind == "return") then {
        compilereturn(o)
    }
    if (o.kind == "generic") then {
        o.register := compilenode(o.value)
    }
    if ((o.kind == "identifier")
        & ((o.value == "true") | (o.value == "false"))) then {
        var val := 0
        if (o.value == "true") then {
            val := 1
        }
        out("  var bool" ++ auto_count ++ " = new GraceBoolean(" ++ o.value ++ ")")
        o.register := "bool" ++ auto_count
        auto_count := auto_count + 1
    } elseif (o.kind == "identifier") then {
        compileidentifier(o)
    }
    if (o.kind == "defdec") then {
        compiledefdec(o)
    }
    if (o.kind == "vardec") then {
        compilevardec(o)
    }
    if (o.kind == "block") then {
        compileblock(o)
    }
    if (o.kind == "method") then {
        compilemethod(o, "this")
    }
    if (o.kind == "array") then {
        compilearray(o)
    }
    if (o.kind == "bind") then {
        compilebind(o)
    }
    if (o.kind == "while") then {
        compilewhile(o)
    }
    if (o.kind == "if") then {
        compileif(o)
    }
    if (o.kind == "matchcase") then {
        compilematchcase(o)
    }
    if (o.kind == "class") then {
        compileclass(o)
    }
    if (o.kind == "object") then {
        compileobject(o, "this")
    }
    if (o.kind == "member") then {
        compilemember(o)
    }
    if (o.kind == "for") then {
        compilefor(o)
    }
    if ((o.kind == "call")) then {
        if (o.value.value == "print") then {
            var args := []
            for (o.with) do { prm ->
                var r := compilenode(prm)
                args.push(r)
            }
            out("  var call" ++ auto_count ++ " = Grace_print(" ++ args.first ++ ");")
            o.register := "call" ++ auto_count
            auto_count := auto_count + 1
        } elseif ((o.value.kind == "identifier")
                & (o.value.value == "length")) then {
            tmp := compilenode(o.with.first)
            out("  var call" ++ auto_count ++ " = Grace_length(" ++ tmp ++ ");")
            o.register := "call" ++ auto_count
            auto_count := auto_count + 1
        } elseif ((o.value.kind == "identifier")
                & (o.value.value == "escapestring")) then {
            tmp := o.with.first
            tmp := ast.astmember("_escape", tmp)
            tmp := ast.astcall(tmp, [])
            o.register := compilenode(tmp)
        } else {
            compilecall(o)
        }
    }
    if (o.kind == "op") then {
        compileop(o)
    }
    compilationDepth := compilationDepth - 1
    o.register
}
method compile(vl, of, mn, rm, bt, glpath) {
    var argv := sys.argv
    var cmd
    values := vl
    outfile := of
    modname := mn
    runmode := rm
    buildtype := bt
    gracelibPath := glpath
    util.log_verbose("generating ECMAScript code.")
    util.setline(1)
    out("function gracecode_" ++ modname ++ "() \{")
    for (values) do { o ->
        compilenode(o)
    }
    out("  return this;")
    out("\}")
    var lineOut := false
    for (output) do { o ->
        if ("  lineNumber =" == o.substringFrom(0)to(14)) then {
            lineOut := o
        } else {
            if (false /= lineOut) then {
                outprint(lineOut)
                lineOut := false
            }
            outprint(o)
        }
    }
    log_verbose("done.")
}
