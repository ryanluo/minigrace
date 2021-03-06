#pragma NativePrelude
#pragma DefaultVisibility=public

var isStandardPrelude := true

def ProgrammingError = _prelude.RuntimeError.refine "fake programming error"
    // this can be replaced by _prelude.ProgrammingError once the built-in
    // ProgrammingError has propagated to the known-good compiler.

def BoundsError = ProgrammingError.refine "index out of bounds"
def Exhausted = ProgrammingError.refine "iterator Exhausted"
def SubobjectResponsibility = ProgrammingError.refine "a subobject should have overridden this method"
def NoSuchObject = ProgrammingError.refine "no such object"
def RequestError = ProgrammingError.refine "inapproriate argument in method request"

type Block0<R> = type {
    apply -> R
}

type Block1<T,R> = type {
    apply(a:T) -> R
}

type Block2<S,T,R> = type {
    apply(a:S, b:T) -> R
}

type IndexableCollection<T> = {
    size -> Number
    at -> T
}

type Collection<T> = {
    size -> Number
    contains(e:Object) -> Boolean
    iterator -> Iterator<T>
}

type Sequence<T> = {
    size -> Number
    at(n: Number) -> T
    [](n: Number) -> T
    indices -> Collection<T>   // range type?
    first -> T 
    second -> T
    third -> T
    fourth -> T 
    last -> T 
    ++(o: Sequence<T>) -> Sequence<T>
    asString -> String
    contains(element) -> Boolean
    do(block1: Block1<T,Done>) -> Done
    ==(other: Object) -> Boolean
    iterator -> Iterator<T>
}

type List<T> = {  
    size -> Number
    at(n: Number) -> T
    [](n: Number) -> T
    at(n: Number)put(x: T) -> List<T>
    []:=(n: Number,x: T) -> List<T> 
    add(x: T) -> List<T>
    push(x: T) -> List<T>
    addLast(x: T) -> List<T>    // compatibility
    removeLast -> T 
    addFirst(x: T) -> List<T> 
    removeFirst -> T 
    removeAt(n: Number) -> T
    pop -> T
    indices -> Collection<T>   // range type?
    first -> T 
    second -> T
    third -> T
    fourth -> T 
    last -> T 
    ++(o: List<T>) -> List<T>
    asString -> String
    addAll(l: List<T>) -> List<T>
    extend(l: List<T>) -> Done
    contains(element) -> Boolean
    do(block1: Block1<T,Done>) -> Done
    ==(other: Object) -> Boolean
    iterator -> Iterator<T>
    copy -> List<T>
}

type Set<T> = {
    size -> Number
    add(*elements:T) -> Set<T>
    remove(*elements: T) -> Set<T>
    remove(*elements: T) ifAbsent(block: Block0<Done>) -> Set<T>
    contains(x: T) -> Boolean
    includes(booleanBlock: Block1<T,Boolean>) -> Boolean
    find(booleanBlock: Block1<T,Boolean>) ifNone(notFoundBlock: Block0<T>) -> T
    asString -> String
    -(o: T) -> Set<T>
    extend(l: Collection<T>) -> Set<T>
    do(block1: Block1<T,Done>) -> Done
    iterator -> Iterator<T>
    ==(other: Object) -> Boolean
    iterator -> Iterator<T>
    copy -> Set<T>
}

type Dictionary<K,T> = {
    size -> Number
    containsKey(k:K) -> Boolean
    containsValue(v:T) -> Boolean
    at(key:K)ifAbsent(action:Block0<Unknown>) -> Unknown
    at(key:K)put(value:T) -> Dictionary<K,T>
    []:=(k:K, v:T) -> Done
    at(k:K) -> T
    [](k:K) -> T
    containsKey(k:K) -> Boolean
    removeAllKeys(keys:Collection<K>) -> Dictionary<K,T>
    removeKey(*keys:K) -> Dictionary<K,T>
    removeAllValues(removals:Collection<K>) -> Dictionary<K,T>
    removeValue(*removals:K) -> Dictionary<K,T>
    containsValue(v:T) -> Boolean
    keys -> Iterator<K>
    values -> Iterator<T>
    bindings -> Iterator<Binding<K,T>>
    keysAndValuesDo(action:Block2<K,T,Done>)
    keysDo(action:Block1<K,Done>) -> Done
    valuesDo(action:Block1<T,Done>) -> Done
    do(action:Block1<K,Done>) -> Done
    ==(other:Object) -> Boolean
    copy -> Dictionary<K,T>
}

type Iterator<T> = {
    iterator -> Iterator
    iter -> Iterator
    onto(factory:EmptyCollectionFactory) -> Collection<T>
    into(accumulator:Collection<Unknown>) -> Collection<Unknown>
    do(action:Block) -> Done
    do(body:Block1<T,Done>) separatedBy(separator:Block0<Done>) -> Done
    fold(blk:Block1<T,Object>) startingWith(initial:T) -> Object
    map(blk:Block1<T,Object>) -> Iterator<Object>
    filter(condition:Block1<T,Boolean>) -> Iterator<T>
}

type CollectionFactory = {
    withAll<T> (elts:Collection<T>) -> Collection<T>
    with<T> (*elts:Object) -> Collection<T>
    empty<T> -> Collection<T>
}

type EmptyCollectionFactory = {
    empty<T> -> Collection<T>
}

class collectionFactory.trait {
    // requires withAll(elts:Collection<T>) -> Collection<T>
    method with(*a) { self.withAll(a) }
    method empty { self.with() }
}

class iterable.trait {
    // requires next, havemore
    //    method havemore { SubobjectResponsibility.raise "havemore" }
    //    method next is abstract { SubobjectResponsibility.raise "next" }
    method iterator { self }
    method iter { self }
    method onto(factory) {
        def resultCollection = factory.empty
        while {self.havemore} do { resultCollection.add(self.next) }
        return resultCollection
    }
    method into(existingCollection) {
        while {self.havemore} do { existingCollection.add(self.next) }
        return existingCollection
    }
    method do(block1) {
        while {self.havemore} do { block1.apply(self.next) }
        return self
    }
    method map(block1) {
        return object {                     // this "return" is to work around a compiler bug
            inherits iterable.trait
            method havemore { outer.havemore }
            method next { block1.apply(outer.next) }
        }
    }
    method fold(block2)startingWith(initial) {
        var res := initial
        while { self.havemore } do { res := block2.apply(res, self.next) }
        return res
    }
    method filter(selectionCondition) {
    // return an iterator that emits only those elements of the underlying
    // iterator for which selectionCondition holds.
        return object {                     // this "return" is to work around a compiler bug
            inherits iterable.trait
            var cache
            var cacheLoaded := false
            method havemore {
            // return true if this iterator has more elements.
            // To determine the answer, we have to find an acceptable element;
            // this is then cached, for the use of next
                if (cacheLoaded) then { return true }
                try {
                    cache := nextAcceptableElement
                    cacheLoaded := true
                } catch { ex:Exhausted -> return false }
                return true
            }
            method next {
                if (cacheLoaded.not) then { cache := nextAcceptableElement }
                cacheLoaded := false
                return cache
            }
            method nextAcceptableElement is confidential {
            // return the next element of the underlying iterator that satisfies
            // selectionCondition.  If there is none, raises Exhausted exception
                var outerNext
                while { true } do {
                    outerNext := outer.next
                    def acceptable = selectionCondition.apply(outerNext)
                    if (acceptable) then { return outerNext }
                }
            }
        }
    }
    method asString { "an Iterator" }
    method asDebugString { self.asString }
}

class enumerable.trait {
    // requires do, iterator
    method iterator { SubobjectResponsibility.raise "iterator" }
    method do { SubobjectResponsibility.raise "do" }
    method do(block1) separatedBy(block0) {
        var firstTime := true
        var i := 0
        self.do { each ->
            if (firstTime) then {
                firstTime := false
            } else {
                block0.apply
            }
            block1.apply(each)
        }
        return self
    }
    method reduce(initial, blk) {   // backwawrd compatibility
        fold(blk)startingWith(initial)
    }
    method map(block1) {
        iterator.map(block1)
    }
    method fold(blk)startingWith(initial) {
        var res := initial
        for (self) do {it->
            res := blk.apply(res, it)
        }
        return res
    }
    method filter(condition) {
        iterator.filter(condition)
    }
    method iter { return self.iterator }
}

method max(a,b) is confidential {
    if (a > b) then { a } else { b }
}

def list is readable = object {
    inherits collectionFactory.trait

    method withAll(a) {
        object {
            inherits enumerable.trait
            var inner := _prelude.PrimitiveArray.new(a.size * 2 + 1)
            var size is readable := 0
            for (a) do {x->
                inner.at(size)put(x)
                size := size + 1
            }
            method boundsCheck(n) is confidential {
                if ((n < 1) || (n > size)) then {
                    BoundsError.raise "index {n} out of bounds 1..{size}" 
                }
            }
            method at(n) {
                boundsCheck(n)
                inner.at(n-1)
            }
            method [](n) {
                boundsCheck(n)
                inner.at(n-1)
            }
            method at(n)put(x) {
                boundsCheck(n)
                inner.at(n-1)put(x)
                self
            }
            method []:=(n,x) {
                boundsCheck(n)
                inner.at(n-1)put(x)
                done
            }
            method add(*x) {
                addAll(x)
            }
            method addAll(l) {
                if ((size + l.size) > inner.size) then {
                    expandTo(max(size + l.size, size * 2))
                }
                for (l) do {each ->
                    inner.at(size)put(each)
                    size := size + 1
                }
                self
            }
            method push(x) {
                if (size == inner.size) then { expandTo(inner.size * 2) }
                inner.at(size)put(x)
                size := size + 1
                self
            }
            method addLast(*x) { addAll(x) }    // compatibility
            method removeLast {
                def result = inner.at(size - 1)
                size := size - 1
                result
            }
            method addAllFirst(l) {
                def increase = l.size
                if ((size + increase) > inner.size) then {
                    expandTo(max(size + increase, size * 2))
                }
                for (range.from(size-1)downTo(0)) do {i->
                    inner.at(i+increase)put(inner.at(i))
                }
                var insertionIndex := 0
                for (l) do {each ->
                    inner.at(insertionIndex)put(each)
                    insertionIndex := insertionIndex + 1
                }
                size := size + increase
                self
            }
            method addFirst(*l) { addAllFirst(l) }
            method removeFirst {
                removeAt(1)
            }
            method removeAt(n) {
                boundsCheck(n)
                def removed = inner.at(n-1)
                for (n..(size-1)) do {i->
                    inner.at(i-1)put(inner.at(i))
                }
                size := size - 1
                return removed
            }
            method pop { removeLast }
            method indices {
                range.from(1)to(size)
            }
            method first { at(1) }
            method second { at(2) }
            method third { at(3) }
            method fourth { at(4) }
            method last { at(size) }
            method ++(o) {
                def l = list.withAll(self)
                for (o) do {it->
                    l.push(it)
                }
                l
            }
            method asString {
                var s := "list<"
                for (0..(size-1)) do {i->
                    s := s ++ inner.at(i).asString
                    if (i < (size-1)) then { s := s ++ "," }
                }
                s ++ ">"
            }
            method extend(l) { addAll(l); done }    // compatibility
            method contains(element) {
                do { each -> if (each == element) then { return true } }
                return false
            }
            method do(block1) {
                var i := 0
                while {i < size} do { 
                    block1.apply(inner.at(i))
                    i := i + 1
                }
            }
            method ==(other) {
                match (other)
                    case {o:IndexableCollection ->
                        if (self.size != o.size) then {return false}
                        self.indices.do { ix ->
                            if (self.at(ix) != o.at(ix)) then {
                                return false
                            }
                        }
                        return true
                    } 
                    case {_ ->
                        return false
                    }
            }
            method iterator {
                object {
                    inherits iterable.trait
                    var idx := 1
                    method asDebugString { "aListIterator<{idx}>" }
                    method asString { "aListIterator" }
                    method havemore { idx <= size }
                    method next {
                        if (idx > size) then { Exhausted.raise "on list" }
                        def ret = at(idx)
                        idx := idx + 1
                        ret
                    }
                }
            }

            method expandTo(newSize) is confidential {
                def newInner = _prelude.PrimitiveArray.new(newSize)
                for (0..(size-1)) do {i->
                    newInner.at(i)put(inner.at(i))
                }
                inner := newInner
            }

            method copy {
                outer.withAll(self)
            }
        }
    }
}

def set is readable = object {
    inherits collectionFactory.trait

    method withAll(a:Collection) {
        object {
            inherits enumerable.trait
            var inner := _prelude.PrimitiveArray.new(if (a.size > 1)
                then {a.size * 3 + 1} else {8})
            def unused = object { 
                var unused := true 
                method asString { "unused" }
            }
            def removed = object { 
                var removed := true 
                method asString { "removed" }
                method asDebugString { "removed" }
            }
            var size is readable := 0
            for (0..(inner.size-1)) do {i->
                inner.at(i)put(unused)
            }
            for (a) do { x-> add(x) }

            method addAll(elements) {
                for (elements) do { x ->
                    if (! contains(x)) then {
                        var t := findPositionForAdd(x)
                        inner.at(t)put(x)
                        size := size + 1
                        if (size > (inner.size / 2)) then {
                            expand
                        }
                    }
                }
                self    // for chaining
            }
            
            method add(*elements) { addAll(elements) }

            method removeAll(elements) {
                for (elements) do { x ->
                    remove (x) ifAbsent {
                        NoSuchObject.raise "set does not contain {x}"
                    }
                }
                self    // for chaining
            }
            method removeAll(elements)ifAbsent(block) {
                for (elements) do { x ->
                    var t := findPosition(x)
                    if (inner.at(t) == x) then {
                        inner.at(t) put (removed)
                        size := size - 1
                    } else { 
                        block.apply
                    }
                }
                self    // for chaining
            }
            
            method remove(*elements)ifAbsent(block) {
                removeAll(elements) ifAbsent(block)
            }
            
            method remove(*elements) {
                removeAll(elements)
            }

            method contains(x) {
                var t := findPosition(x)
                if (inner.at(t) == x) then {
                    return true
                }
                return false
            }
            method includes(booleanBlock) {
                self.do { each ->
                    if (booleanBlock.apply(each)) then { return true }
                }
                return false
            }
            method find(booleanBlock)ifNone(notFoundBlock) {
                self.do { each ->
                    if (booleanBlock.apply(each)) then { return each }
                }
                return notFoundBlock.apply
            }
            method findPosition(x) is confidential {
                def h = x.hashcode
                def s = inner.size
                var t := h % s
                var jump := 5
                var candidate
                while { 
                    candidate := inner.at(t)
                    candidate != unused
                } do {
                    if (candidate == x) then {
                        return t
                    }
                    if (jump != 0) then {
                        t := (t * 3 + 1) % s
                        jump := jump - 1
                    } else {
                        t := (t + 1) % s
                    }
                }
                return t
            }
            method findPositionForAdd(x) is confidential {
                def h = x.hashcode
                def s = inner.size
                var t := h % s
                var jump := 5
                var candidate
                while { 
                    candidate := inner.at(t)
                    (candidate != unused).andAlso{candidate != removed}
                } do {
                    if (candidate == x) then {
                        return t
                    }
                    if (jump != 0) then {
                        t := (t * 3 + 1) % s
                        jump := jump - 1
                    } else {
                        t := (t + 1) % s
                    }
                }
                return t
            }

            method asString {
                var s := "set\{"
                do {each -> s := s ++ each.asString }
                    separatedBy { s := s ++ "," }
                s ++ "\}"
            }
            method -(o) {
                def result = set.empty
                for (self) do {v->
                    if (!o.contains(v)) then {
                        result.add(v)
                    }
                }
                result
            }
            method extend(l) {
                for (l) do {i->
                    add(i)
                }
            }
            method do(block1) {
                var i := 0
                var found := 0
                var candidate
                while {found < size} do { 
                    candidate := inner.at(i)
                    if ((candidate != unused).andAlso{candidate != removed}) then {
                        found := found + 1
                        block1.apply(candidate)
                    }
                    i := i + 1
                }
            }
            method iterator {
                object {
                    inherits iterable.trait
                    var count := 1
                    var idx := 0
                    method havemore {
                        count <= size
                    }
                    method next {
                        var candidate
                        while {
                            candidate := inner.at(idx)
                            (candidate == unused).orElse{candidate == removed}
                        } do {
                            idx := idx + 1
                            if (idx == inner.size) then {
                                Exhausted.raise "over {outer.asString}"
                            }
                        }
                        count := count + 1
                        idx := idx + 1
                        candidate
                    }
                }
            }

            method expand is confidential {
                def c = inner.size
                def n = c * 2
                def oldInner = inner
                size := 0
                inner := _prelude.PrimitiveArray.new(n)
                for (0..(inner.size-1)) do {i->
                    inner.at(i)put(unused)
                }
                for (0..(oldInner.size-1)) do {i->
                    if ((oldInner.at(i) != unused).andAlso{oldInner.at(i) != removed}) then {
                        add(oldInner.at(i))
                    }
                }
            }
            
            method ==(other) {
                match (other)
                    case {o:Collection ->
                        if (self.size != o.size) then {return false}
                        self.do { each ->
                            if (! o.contains(each)) then {
                                return false
                            }
                        }
                        return true
                    } 
                    case {_ ->
                        return false
                    }
            }

            method copy {
                outer.withAll(self)
            }

        }
    }
}

type Binding = {
    key -> Object
    value -> Object
    hashcode -> Number
    == -> Boolean
}

class binding.key(k)value(v) {
    method key {k}
    method value {v}
    method asString { "{k}::{v}" }
    method asDebugString { asString }
    method hashcode { (k.hashcode * 1021) + v.hashcode }
    method == (other) {
        match (other)
            case {o:Binding -> (k == o.key) && (v == o.value) }
            case {_ -> return false }
    }
}

def dictionary is readable = object {
    inherits collectionFactory.trait
    method at(k)put(v) {
            self.empty.at(k)put(v)
    }
    method withAll(initialBindings) {
        object {
            inherits enumerable.trait
            var size is readable := 0
            var inner := _prelude.PrimitiveArray.new(8)
            def unused = object { 
                var unused := true
                def key is readable = self
                def value is readable = self
                method asString { "unused" }
                method asDebugString { "unused" }
            }
            def removed = object { 
                var removed := true
                def key is readable = self
                def value is readable = self
                method asString { "removed" }
                method asDebugString { "removed" }
            }
            for (0..(inner.size-1)) do {i->
                inner.at(i)put(unused)
            }
            for (initialBindings) do { b -> at(b.key)put(b.value) }
            
            method at(key')put(value') {
                var t := findPositionForAdd(key')
                if ((inner.at(t) == unused).orElse{inner.at(t) == removed}) then {
                    size := size + 1
                }
                inner.at(t)put(binding.key(key')value(value'))
                if ((size * 2) > inner.size) then { expand }
                self    // for chaining
            }
            method []:=(k, v) { 
                at(k)put(v) 
                done
            }
            method at(k) { 
                var b := inner.at(findPosition(k))
                if (b.key == k) then {
                    return b.value
                }
                NoSuchObject.raise "dictionary does not contain entry with key {k}"
            }
            method at(k)ifAbsent(action) {
                var b := inner.at(findPosition(k))
                if (b.key == k) then {
                    return b.value
                }
                return action.apply
            }
            method [](k) { at(k) }
            method containsKey(k) {
                var t := findPosition(k)
                if (inner.at(t).key == k) then {
                    return true
                }
                return false
            }
            method removeAllKeys(keys) {
                for (keys) do { k ->
                    var t := findPosition(k)
                    if (inner.at(t).key == k) then {
                        inner.at(t)put(removed)
                        size := size - 1
                    } else {
                        NoSuchObject.raise "dictionary does not contain entry with key {k}"
                    }
                }
                return self
            }
            method removeKey(*keys) {
                removeAllKeys(keys)
            }
            method removeAllValues(removals) {
                for (0..(inner.size-1)) do {i->
                    def a = inner.at(i)
                    if (removals.contains(a.value)) then {
                        inner.at(i)put(removed)
                        size := size - 1
                    }
                }
                return self
            }
            method removeValue(*removals) {
                removeAllValues(removals)
            }
            method containsValue(v) {
                self.valuesDo{ each ->
                    if (v == each) then { return true }
                }
                return false
            }
            method contains(v) { containsValue(v) }
            method findPosition(x) is confidential {
                def h = x.hashcode
                def s = inner.size
                var t := h % s
                var jump := 5
                while {inner.at(t) != unused} do {
                    if (inner.at(t).key == x) then {
                        return t
                    }
                    if (jump != 0) then {
                        t := (t * 3 + 1) % s
                        jump := jump - 1
                    } else {
                        t := (t + 1) % s
                    }
                }
                return t
            }
            method findPositionForAdd(x) is confidential {
                def h = x.hashcode
                def s = inner.size
                var t := h % s
                var jump := 5
                while {(inner.at(t) != unused).andAlso{inner.at(t) != removed}} do {
                    if (inner.at(t).key == x) then {
                        return t
                    }
                    if (jump != 0) then {
                        t := (t * 3 + 1) % s
                        jump := jump - 1
                    } else {
                        t := (t + 1) % s
                    }
                }
                return t
            }
            method asString {
                var s := "dict["
                var numberRemaining := size
                for (0..(inner.size-1)) do {i->
                    def a = inner.at(i)
                    if ((a != unused).andAlso{a != removed}) then {
                        s := s ++ "{a.key}::{a.value}"
                        numberRemaining := numberRemaining - 1
                        if (numberRemaining > 0) then {
                            s := s ++ ", "
                        }
                    }
                }
//                self.do { a -> s := s ++ "{a.key}=>{a.value}" }
//                    separatedBy { s := s ++ ", " }
                return (s ++ "]")
            }
            method asDebugString {
                var s := "dict["
                for (0..(inner.size-1)) do {i->
                    if (i > 0) then { s := s ++ ", " }
                    def a = inner.at(i)
                    if ((a != unused).andAlso{a != removed}) then {
                        s := s ++ "{i}:{a.key}=>{a.value}"
                    } else {
                        s := s ++ "{i}:{a.asDebugString}"
                    }

                }
                s ++ "]"
            }
            method keys {
                object {
                    inherits iterable.trait
                    // We could just inherit from outer.bindings, and
                    // override next to do return super.next.key
                    // This would use stateful inheritance, and save two lines.
                    def outerIterator = bindings
                    method havemore { outerIterator.havemore }
                    method next { outerIterator.next.key }
                }
            }
            method values {
                object {
                    inherits iterable.trait
                    // We could just inherit from outer.bindings, and
                    // override next to do return super.next.value
                    // This would use stateful inheritance, and save two lines.
                    def outerIterator = bindings
                    method havemore { outerIterator.havemore }
                    method next { outerIterator.next.value }
                }
            }
            method iterator { values }
            method bindings {
                object {
                    inherits iterable.trait
                    var count := 1
                    var idx := 0
                    var elt
                    method havemore {
                        count <= size
                    }
                    method next {
                        if (count > size) then { 
                            Exhausted.raise "over {outer.asString}"
                        }
                        while {
                            elt := inner.at(idx)
                            (elt == unused).orElse{elt == removed}
                        } do {
                            idx := idx + 1
                        }
                        count := count + 1
                        idx := idx + 1
                        elt
                    }
                }
            }
            method expand is confidential {
                def c = inner.size
                def n = c * 2
                def oldInner = inner
                inner := _prelude.PrimitiveArray.new(n)
                for (0..(inner.size-1)) do {i->
                    inner.at(i)put(unused)
                }
                size := 0
                for (0..(oldInner.size-1)) do {i->
                    def a = oldInner.at(i)
                    if ((a != unused).andAlso{a != removed}) then {
                        self.at(a.key)put(a.value)
                    }
                }
            }
            method keysAndValuesDo(block2) {
                 for (0..(inner.size-1)) do {i->
                    def a = inner.at(i)
                    if ((a != unused).andAlso{a != removed}) then {
                        block2.apply(a.key, a.value)
                    }
                }
            }
            method keysDo(block1) {
                 for (0..(inner.size-1)) do {i->
                    def a = inner.at(i)
                    if ((a != unused).andAlso{a != removed}) then {
                        block1.apply(a.key)
                    }
                }
            }
            method valuesDo(block1) {
                 for (0..(inner.size-1)) do {i->
                    def a = inner.at(i)
                    if ((a != unused).andAlso{a != removed}) then {
                        block1.apply(a.value)
                    }
                }
            }
            method do(block1) { valuesDo(block1) }

            method ==(other) {
                match (other)
                    case {o:Dictionary ->
                        if (self.size != o.size) then {return false}
                        self.keysAndValuesDo { k, v ->
                            if (o.at(k)ifAbsent{return false} != v) then {
                                return false
                            }
                        }
                        return true
                    } 
                    case {_ ->
                        return false
                    }
            }

            method copy {
                def newCopy = dictionary.empty
                self.keysAndValuesDo{ k, v ->
                    newCopy.at(k)put(v)
                }
                newCopy
            }
        }
    }
}

def range is readable = object {
    method from(lower)to(upper) {
        object {
            inherits enumerable.trait
            match (lower)
                case {_:Number -> }
                case {_ -> RequestError.raise "lower bound {lower}" ++
                    " in range.from({lower})to({upper}) is not an integer" }
            def start = lower.truncate
            if (start != lower) then {
                RequestError.raise "lower bound {lower}" ++
                    " in range.from({lower})to({upper}) is not an integer" }

            match (upper)
                case {_:Number -> }
                case {_ -> RequestError.raise "upper bound {upper}" ++
                    " in range.from({lower})to({upper}) is not an integer" }
            def stop = upper.truncate
            if (stop != upper) then {
                RequestError.raise "upper bound {upper}" ++
                    " in range.from()to() is not an integer"
            }

            def size is readable = 
                if ((upper-lower+1) < 0) then { 0 } else {upper-lower+1}
            method iterator -> Iterator {
                object {
                    inherits iterable.trait
                    var val := start
                    method havemore {
                        val <= stop
                    }
                    method next {
                        if (val > stop) then { 
                            Exhausted.raise "over {outer.asString}" 
                        }
                        val := val + 1
                        return (val - 1)
                    }
                    method asString { "{super.asString} from {upper} to {lower}" }
                }
            }
            method contains(elem) -> Boolean {
                try {
                    def intElem = elem.truncate
                    if (intElem != elem) then {return false}
                    if (intElem < start) then {return false}
                    if (intElem > stop) then {return false}
                } catch { ex:_prelude.Exception -> return false }
                return true
            }
            method do(block1) {
                var val := start
                while {val <= stop} do {
                    block1.apply(val)
                    val := val + 1
                }
            }
            method reversed {
                from(upper)downTo(lower)
            }
            method ==(other) {
                match (other)
                    case {o:Collection ->
                        if (self.size != other.size) then { return false }
                        def selfIter = self.iterator
                        def otherIter = other.iterator
                        while {selfIter.havemore} do {
                            if (selfIter.next != otherIter.next) then {
                                return false
                            }
                        }
                        return true
                    } 
                    case {_ ->
                        return false
                    }
            }

            method asString -> String{
                return "range.from({lower})to({upper})"
            }

            method asList{
                var result := list.empty
                for (self) do { each -> result.add(each) }
                result
            }
        }
    }
    method from(upper)downTo(lower) {
        object {
            inherits enumerable.trait
            match (upper)
                case {_:Number -> }
                case {_ -> RequestError.raise "upper bound {upper}" ++
                    " in range.from({upper})downTo({lower}) is not an integer" }
            def start = upper.truncate
            if (start != upper) then {
                RequestError.raise "upper bound {upper}" ++
                    " in range.from({upper})downTo({lower}) is not an integer"
            }
            match (lower)
                case {_:Number -> }
                case {_ -> RequestError.raise "lower bound {lower}" ++
                    " in range.from({upper})downTo({lower}) is not an integer" }
            def stop = lower.truncate
            if (stop != lower) then {
                RequestError.raise "lower bound {lower}" ++
                    " in range.from({upper})downTo({lower}) is not an integer"
            }
            def size is readable = 
                if ((upper-lower+1) < 0) then { 0 } else {upper-lower+1}
            method iterator {
                object {
                    inherits iterable.trait
                    var val := start
                    method havemore {
                        val >= stop
                    }
                    method next {
                        if (val < stop) then { Exhausted.raise "outer.asString" }
                        val := val - 1
                        return (val + 1)
                    }
                    method asString { "{super.asString} from {upper} downTo {lower}" }
                }
            }
            method contains(elem) -> Boolean {
                try {
                    def intElem = elem.truncate
                    if (intElem != elem) then {return false}
                    if (intElem > start) then {return false}
                    if (intElem < stop) then {return false}
                } catch { ex:_prelude.Exception -> return false }
                return true
            }
            method do(block1) {
                var val := start
                while {val >= stop} do {
                    block1.apply(val)
                    val := val - 1
                }
            }
            method reversed {
                from(lower)to(upper)
            }
            method ==(other){
                match (other)
                    case {o:Collection ->
                        if (self.size != other.size) then { return false }
                        def selfIter = self.iterator
                        def otherIter = other.iterator
                        while {selfIter.havemore} do {
                            if (selfIter.next != otherIter.next) then {
                                return false
                            }
                        }
                        return true
                    } 
                    case {_ ->
                        return false
                    }
            }

            method asString -> String{
                return "range.from({upper})downTo({lower})"
            }

            method asList{
                var result := list.empty

                def iter = self.iterator

                while {iter.havemore} do {
                    result.add(iter.next)
                }

                result
            }
        }
    }
}

