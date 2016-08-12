// The MIT License
//
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// "It's all boxes all the way down."
//
// Mustache templates don't eat raw values: they eat boxed values.
//
// To box something, you use the `Box()` function. It comes in several variants
// so that nearly anything can be boxed and feed templates:
//
//     let value = ...
//     template.render(Box(value))
//
// This file is organized in five sections with many examples. You can use the
// Playground included in `Mustache.xcworkspace` to run those examples.
//
//
// - MustacheBoxable and the Boxing of Value Types
//
//   The `MustacheBoxable` protocol lets any type describe how it interacts with
//   the Mustache rendering engine.
//
//   It is adopted by the standard types Bool, Int, UInt, Double, String, and
//   NSObject.
//
//
// - Boxing of Collections
//
//   Learn how Array and Set are rendered.
//
//
// - Boxing of Dictionaries
//
//   Learn how Dictionary and NSDictionary are rendered.
//
//
// - Boxing of Core Mustache functions
//
//   The "core Mustache functions" are raw filters, Mustache lambdas, etc. Those
//   can be boxed as well so that you can feed templates with them.
//
//
// - Boxing of multi-facetted values
//
//   Describes the most advanced `Box()` function.


// =============================================================================
// MARK: - MustacheBoxable and the Boxing of Value Types

/**
The MustacheBoxable protocol gives any type the ability to feed Mustache
templates.

It is adopted by the standard types Bool, Int, UInt, Double, String, and
NSObject.

Your own types can conform to it as well, so that they can feed templates:

    extension Profile: MustacheBoxable { ... }

    let profile = ...
    let template = try! Template(named: "Profile")
    let rendering = try! template.render(Box(profile))
*/
public protocol MustacheBoxable {
    
    /**
    You should not directly call the `mustacheBox` property. Always use the
    `Box()` function instead:
    
        value.mustacheBox   // Valid, but discouraged
        Box(value)          // Preferred
    
    Return a `MustacheBox` that describes how your type interacts with the
    rendering engine.
    
    You can for example box another value that is already boxable, such as
    dictionaries:

        struct Person {
            let firstName: String
            let lastName: String
        }

        extension Person : MustacheBoxable {
            // Expose the `firstName`, `lastName` and `fullName` keys to
            // Mustache templates:
            var mustacheBox: MustacheBox {
                return Box([
                    "firstName": firstName,
                    "lastName": lastName,
                    "fullName": "\(self.firstName) \(self.lastName)",
                ])
            }
        }

        let person = Person(firstName: "Tom", lastName: "Selleck")
    
        // Renders "Tom Selleck"
        let template = try! Template(string: "{{person.fullName}}")
        try! template.render(Box(["person": Box(person)]))

    However, there are multiple ways to build a box, several `Box()` functions.
    See their documentations.
    */
    var mustacheBox: MustacheBox { get }
}

// IMPLEMENTATION NOTE
//
// This protocol conformance is not only a matter of consistency. It is also
// a convenience for the library implementation: it makes arrays
// [MustacheBox] boxable via Box<C: Collection where C.Iterator.Element: MustacheBoxable>(collection: C?)
// and dictionaries [String:MustacheBox] boxable via Box<T: MustacheBoxable>(dictionary: [String: T]?)

extension MustacheBox {
    
    /**
    `MustacheBox` adopts the `MustacheBoxable` protocol so that it can feed
    Mustache templates. Its mustacheBox property returns itself.
    */
    public var mustacheBox: MustacheBox {
        return self
    }
}


/**
GRMustache provides built-in support for rendering `Bool`.
*/

extension Bool: MustacheBoxable {
    
    /**
    `Bool` adopts the `MustacheBoxable` protocol so that it can feed Mustache
    templates.

    You should not directly call the `mustacheBox` property. Always use the
    `Box()` function instead:
    
        true.mustacheBox   // Valid, but discouraged
        Box(true)          // Preferred

    
    ### Rendering
    
    - `{{bool}}` renders as `0` or `1`.
    
    - `{{#bool}}...{{/bool}}` renders if and only if `bool` is true.
    
    - `{{^bool}}...{{/bool}}` renders if and only if `bool` is false.
    
    */
    public var mustacheBox: MustacheBox {
        return MustacheBox(
            value: self,
            boolValue: self,
            render: { (info: RenderingInfo) in
                switch info.tag.type {
                case .Variable:
                    // {{ bool }}
                    return Rendering("\(self ? 1 : 0)") // Behave like [NSNumber numberWithBool:]
                case .Section:
                    if info.enumerationItem {
                        // {{# bools }}...{{/ bools }}
                        return try info.tag.render(context: info.context.extendedContext(Box(boolValue: self)))
                    } else {
                        // {{# bool }}...{{/ bool }}
                        //
                        // Bools do not enter the context stack when used in a
                        // boolean section.
                        //
                        // This behavior must not change:
                        // https://github.com/groue/GRMustache/issues/83
                        return try info.tag.render(context: info.context)
                    }
                }
        })
    }
}


/**
GRMustache provides built-in support for rendering `Int`.
*/

extension Int: MustacheBoxable {
    
    /**
    `Int` adopts the `MustacheBoxable` protocol so that it can feed Mustache
    templates.
    
    You should not directly call the `mustacheBox` property. Always use the
    `Box()` function instead:
    
        1.mustacheBox   // Valid, but discouraged
        Box(1)          // Preferred
    
    
    ### Rendering
    
    - `{{int}}` is rendered with built-in Swift String Interpolation.
      Custom formatting can be explicitly required with NSNumberFormatter, as in
      `{{format(a)}}` (see `NSFormatter`).
    
    - `{{#int}}...{{/int}}` renders if and only if `int` is not 0 (zero).
    
    - `{{^int}}...{{/int}}` renders if and only if `int` is 0 (zero).
    
    */
    public var mustacheBox: MustacheBox {
        return MustacheBox(
            value: self,
            boolValue: (self != 0),
            render: { (info: RenderingInfo) in
                switch info.tag.type {
                case .Variable:
                    // {{ int }}
                    return Rendering("\(self)")
                case .Section:
                    if info.enumerationItem {
                        // {{# ints }}...{{/ ints }}
                        return try info.tag.render(context: info.context.extendedContext(Box(value: self)))
                    } else {
                        // {{# int }}...{{/ int }}
                        //
                        // Ints do not enter the context stack when used in a
                        // boolean section.
                        //
                        // This behavior must not change:
                        // https://github.com/groue/GRMustache/issues/83
                        return try info.tag.render(context: info.context)
                    }
                }
        })
    }
}


/**
GRMustache provides built-in support for rendering `UInt`.
*/

extension UInt: MustacheBoxable {
    
    /**
    `UInt` adopts the `MustacheBoxable` protocol so that it can feed Mustache
    templates.
    
    You should not directly call the `mustacheBox` property. Always use the
    `Box()` function instead:
    
        1.mustacheBox   // Valid, but discouraged
        Box(1)          // Preferred
    
    
    ### Rendering
    
    - `{{uint}}` is rendered with built-in Swift String Interpolation.
      Custom formatting can be explicitly required with NSNumberFormatter, as in
      `{{format(a)}}` (see `NSFormatter`).
    
    - `{{#uint}}...{{/uint}}` renders if and only if `uint` is not 0 (zero).
    
    - `{{^uint}}...{{/uint}}` renders if and only if `uint` is 0 (zero).
    
    */
    public var mustacheBox: MustacheBox {
        return MustacheBox(
            value: self,
            boolValue: (self != 0),
            render: { (info: RenderingInfo) in
                switch info.tag.type {
                case .Variable:
                    // {{ uint }}
                    return Rendering("\(self)")
                case .Section:
                    if info.enumerationItem {
                        // {{# uints }}...{{/ uints }}
                        return try info.tag.render(context: info.context.extendedContext(Box(value: self)))
                    } else {
                        // {{# uint }}...{{/ uint }}
                        //
                        // Uints do not enter the context stack when used in a
                        // boolean section.
                        //
                        // This behavior must not change:
                        // https://github.com/groue/GRMustache/issues/83
                        return try info.tag.render(context: info.context)
                    }
                }
        })
    }
}


/**
GRMustache provides built-in support for rendering `Double`.
*/

extension Double: MustacheBoxable {
    
    /**
    `Double` adopts the `MustacheBoxable` protocol so that it can feed Mustache
    templates.
    
    You should not directly call the `mustacheBox` property. Always use the
    `Box()` function instead:
    
        3.14.mustacheBox   // Valid, but discouraged
        Box(3.14)          // Preferred
    
    
    ### Rendering
    
    - `{{double}}` is rendered with built-in Swift String Interpolation.
      Custom formatting can be explicitly required with NSNumberFormatter, as in
      `{{format(a)}}` (see `NSFormatter`).
    
    - `{{#double}}...{{/double}}` renders if and only if `double` is not 0 (zero).
    
    - `{{^double}}...{{/double}}` renders if and only if `double` is 0 (zero).
    
    */
    public var mustacheBox: MustacheBox {
        return MustacheBox(
            value: self,
            boolValue: (self != 0.0),
            render: { (info: RenderingInfo) in
                switch info.tag.type {
                case .Variable:
                    // {{ double }}
                    return Rendering("\(self)")
                case .Section:
                    if info.enumerationItem {
                        // {{# doubles }}...{{/ doubles }}
                        return try info.tag.render(context: info.context.extendedContext(Box(value: self)))
                    } else {
                        // {{# double }}...{{/ double }}
                        //
                        // Doubles do not enter the context stack when used in a
                        // boolean section.
                        //
                        // This behavior must not change:
                        // https://github.com/groue/GRMustache/issues/83
                        return try info.tag.render(context: info.context)
                    }
                }
        })
    }
}


/**
GRMustache provides built-in support for rendering `String`.
*/

extension String: MustacheBoxable {
    
    /**
    `String` adopts the `MustacheBoxable` protocol so that it can feed Mustache
    templates.
    
    You should not directly call the `mustacheBox` property. Always use the
    `Box()` function instead:
    
        "foo".mustacheBox   // Valid, but discouraged
        Box("foo")          // Preferred
    
    
    ### Rendering
    
    - `{{string}}` renders the string, HTML-escaped.
    
    - `{{{string}}}` renders the string, *not* HTML-escaped.
    
    - `{{#string}}...{{/string}}` renders if and only if `string` is not empty.
    
    - `{{^string}}...{{/string}}` renders if and only if `string` is empty.
    
    HTML-escaping of `{{string}}` tags is disabled for Text templates: see
    `Configuration.contentType` for a full discussion of the content type of
    templates.
    
    
    ### Keys exposed to templates

    A string can be queried for the following keys:
    
    - `length`: the number of characters in the string.
    
    */
    public var mustacheBox: MustacheBox {
        return MustacheBox(
            value: self,
            boolValue: (self.characters.count > 0),
            keyedSubscript: { (key: String) in
                switch key {
                case "length":
                    return Box(value: self.characters.count)
                default:
                    return Box()
                }
            })
    }
}

/**
 GRMustache provides built-in support for rendering `Set`.
 */

extension Set: MustacheBoxable {

    /**
     `NSSet` adopts the `MustacheBoxable` protocol so that it can feed Mustache
     templates.

     let set: NSSet = [1,2,3]

     // Renders "213"
     let template = try! Template(string: "{{#set}}{{.}}{{/set}}")
     try! template.render(Box(["set": Box(set)]))


     You should not directly call the `mustacheBox` property. Always use the
     `Box()` function instead:

     set.mustacheBox   // Valid, but discouraged
     Box(set)          // Preferred


     ### Rendering

     - `{{set}}` renders the concatenation of the renderings of the set items, in
     any order.

     - `{{#set}}...{{/set}}` renders as many times as there are items in `set`,
     pushing each item on its turn on the top of the context stack.

     - `{{^set}}...{{/set}}` renders if and only if `set` is empty.


     ### Keys exposed to templates

     A set can be queried for the following keys:

     - `count`: number of elements in the set
     - `first`: the first object in the set

     Because 0 (zero) is falsey, `{{#set.count}}...{{/set.count}}` renders once,
     if and only if `set` is not empty.


     ### Unwrapping from MustacheBox

     Whenever you want to extract a collection of a MustacheBox, use the
     `arrayValue` property: it reliably returns an Array of MustacheBox, whatever
     the actual type of the raw boxed value (Set, Array, NSArray, NSSet, ...)
     */
    public var mustacheBox: MustacheBox {
        var array: [MustacheBoxable] = []
        for element in self {
            if let e = element as? MustacheBoxable {
                array.append(e)
            } else {
                print("Tried to use a set as MustacheBoxable, but the set is not boxable.")
                return Box()
            }
        }
        let a = array
        return a.mustacheBox(withSetValue: a, box: { Box(boxable: $0) })
    }
}

/**
 GRMustache provides built-in support for rendering `Array`.
 */

extension Array: MustacheBoxable {
    public var mustacheBox: MustacheBox {
        var array: [MustacheBoxable] = []
        for element in self {
            if let e = element as? MustacheBoxable {
                array.append(e)
            } else {
                print("Tried to use an array as MustacheBoxable, but the array is not boxable.")
                return Box()
            }
        }
        let a = array
        return a.mustacheBox(withArrayValue: a, box: { Box(boxable: $0) })
    }
}

/**
 GRMustache provides built-in support for rendering `Dictionary`.
 */

extension Dictionary: MustacheBoxable {

    /**
     `Dictionary` adopts the `MustacheBoxable` protocol so that it can feed
     Mustache templates.

     // Renders "Freddy Mercury"
     let dictionary: NSDictionary = [
     "firstName": "Freddy",
     "lastName": "Mercury"
     ]

     let template = try! Template(string: "{{firstName}} {{lastName}}")
     let rendering = try! template.render(Box(dictionary))


     You should not directly call the `mustacheBox` property. Always use the
     `Box()` function instead:

     dictionary.mustacheBox   // Valid, but discouraged
     Box(dictionary)          // Preferred


     ### Rendering

     - `{{dictionary}}` renders the result of the `description` method, HTML-escaped.

     - `{{{dictionary}}}` renders the result of the `description` method, *not* HTML-escaped.

     - `{{#dictionary}}...{{/dictionary}}` renders once, pushing `dictionary` on
     the top of the context stack.

     - `{{^dictionary}}...{{/dictionary}}` does not render.


     In order to iterate over the key/value pairs of a dictionary, use the `each`
     filter from the Standard Library:

     // Attach StandardLibrary.each to the key "each":
     let template = try! Template(string: "<{{# each(dictionary) }}{{@key}}:{{.}}, {{/}}>")
     template.registerInBaseContext("each", Box(StandardLibrary.each))

     // Renders "<name:Arthur, age:36, >"
     let dictionary = ["name": "Arthur", "age": 36] as NSDictionary
     let rendering = try! template.render(Box(["dictionary": dictionary]))


     ### Unwrapping from MustacheBox

     Whenever you want to extract a dictionary of a MustacheBox, use the
     `dictionaryValue` property: it reliably returns an `[String: MustacheBox]`
     dictionary, whatever the actual type of the raw boxed value.
     */
    public var mustacheBox: MustacheBox {
        var dictionaryValue: [String: MustacheBox] = [:]
        for (key, value) in self {
            if let k = key as? String {
                if let v = value as? MustacheBox {
                    dictionaryValue[k] = v
                } else if let v = value as? MustacheBoxable {
                    dictionaryValue[k] = Box(boxable: v)
                } else {
                    print("Tried to use a dictionary as MustacheBoxable, but the value: \(value) is not boxable.")
                    return Box()
                }
            }
        }

        let dict = dictionaryValue

        let keyedSubscript = { (subscriptKey: String) in
            dict[subscriptKey] ?? Box()
        }
        
        return MustacheBox(
            converter: MustacheBox.Converter(dictionaryValue: dict),
            value: self,
            keyedSubscript: keyedSubscript
        )
    }
}

/**
Values that conform to the `MustacheBoxable` protocol can feed Mustache
templates.

- parameter boxable: An optional value that conform to the `MustacheBoxable`
                     protocol.

- returns: A MustacheBox that wraps *boxable*.
*/
public func Box(boxable: MustacheBoxable?) -> MustacheBox {
    return boxable?.mustacheBox ?? Box()
}

// IMPLEMENTATION NOTE
//
// Why is there a BoxAnyObject(AnyObject?) function, but no Box(AnyObject?)
//
// GRMustache aims at having a single boxing function: Box(), with many
// overloaded variants. This lets the user box anything, standard Swift types
// (Bool, String, etc.), custom types, as well as opaque types (such as
// StandardLibrary.javascriptEscape).
//
// For example:
//
//      public func Box(boxable: MustacheBoxable?) -> MustacheBox
//      public func Box(filter: FilterFunction) -> MustacheBox
//
// Sometimes values come out of Foundation objects:
//
//     class NSDictionary {
//         subscript (key: NSCopying) -> AnyObject? { get }
//     }
//
// So we need a Box(AnyObject?) function, right?
//
// Unfortunately, this will not work:
//
//     protocol MustacheBoxable {}
//     class Thing: MustacheBoxable {}
//
//     func Box(x: MustacheBoxable?) -> String { return "MustacheBoxable" }
//     func Box(x: AnyObject?) -> String { return "AnyObject" }
//
//     // error: ambiguous use of 'Box'
//     Box(Thing())
//
// Maybe if we turn the func Box(x: MustacheBoxable?) into a generic one? Well,
// it does not make the job either:
//
//     protocol MustacheBoxable {}
//     class Thing: MustacheBoxable {}
//
//     func Box<T: MustacheBoxable>(x: T?) -> String { return "MustacheBoxable" }
//     func Box(x: AnyObject?) -> String { return "AnyObject" }
//
//     // Wrong: uses the AnyObject variant
//     Box(Thing())
//
//     // Error: cannot find an overload for 'Box' that accepts an argument list of type '(MustacheBoxable)'
//     Box(Thing() as MustacheBoxable)
//
//     // Error: Crash the compiler
//     Box(Thing() as MustacheBoxable?)
//
// And if we turn the func Box(x: AnyObject) into a generic one? Well, it gets
// better:
//
//     protocol MustacheBoxable {}
//     class Thing: MustacheBoxable {}
//
//     func Box(x: MustacheBoxable?) -> String { return "MustacheBoxable" }
//     func Box<T:AnyObject>(object: T?) -> String { return "AnyObject" }
//
//     // OK: uses the MustacheBox variant
//     Box(Thing())
//
//     // OK: uses the MustacheBox variant
//     Box(Thing() as MustacheBoxable)
//
//     // OK: uses the MustacheBox variant
//     Box(Thing() as MustacheBoxable?)
//
//     // OK: uses the AnyObject variant
//     Box(Thing() as AnyObject)
//
//     // OK: uses the AnyObject variant
//     Box(Thing() as AnyObject?)
//
// This looks OK, doesn't it? Well, it's not satisfying yet.
//
// According to http://airspeedvelocity.net/2015/03/26/protocols-and-generics-2/
// there are reasons for preferring func Box<T: MustacheBoxable>(x: T?) over
// func Box(x: MustacheBoxable?). The example above have shown that the boxing
// of AnyObject with an overloaded version of Box() would make this choice for
// us.
//
// It's better not to make any choice right now, until we have a better
// knowledge of Swift performances and optimization, and of the way Swift
// resolves overloaded functions.
// 
// So let's avoid having any Box(AnyObject?) variant in the public API, and
// let's expose the BoxAnyObject(object: AnyObject?) instead.

// IMPLEMENTATION NOTE 2
//
// BoxAnyObject has been made private. Now users get a compiler error when they
// try to box AnyObject.
//
// Reasons for this removal from the public API:
//
// - Users will try Box() first, which will fail. Since they may not know
//   anything BoxAnyObject, BoxAnyObject is of little value anyway.
// - BoxAnyObject is error-prone, since it accepts anything and fails at
//   runtime.
//
// It still exists because we need it to box Foundation collections like
// NSArray, NSSet, NSDictionary.

/**
`AnyObject` can feed Mustache templates.

Yet, due to constraints in the Swift language, there is no `Box(AnyObject)`
function. Instead, you use `BoxAnyObject`:

    let set = NSSet(object: "Mario")
    let object: AnyObject = set.anyObject()
    let box = BoxAnyObject(object)
    box.value as String  // "Mario"

The object is tested at runtime whether it adopts the `MustacheBoxable`
protocol. In this case, this function behaves just like `Box(MustacheBoxable)`.

Otherwise, GRMustache logs a warning, and returns the empty box.

- parameter object: An object.
- returns: A MustacheBox that wraps *object*.
*/
private func BoxAnyObject(object: AnyObject?) -> MustacheBox {
    if let boxable = object as? MustacheBoxable {
        return boxable.mustacheBox
    } else if let object: AnyObject = object {
        
        // IMPLEMENTATION NOTE
        //
        // In the example below, the Thing class can not be turned into any
        // relevant MustacheBox.
        // 
        // Yet we can not prevent the user from trying to box it, because the
        // Thing class adopts the AnyObject protocol, just as all Swift classes.
        //
        //     class Thing { }
        //
        //     // Compilation error (OK): cannot find an overload for 'Box' that accepts an argument list of type '(Thing)'
        //     Box(Thing())
        //
        //     // Runtime warning (Not OK but unavoidable): value `Thing` is not NSObject and does not conform to MustacheBoxable: it is discarded.
        //     BoxAnyObject(Thing())
        //
        //     // Foundation collections can also contain unsupported classes:
        //     let array = NSArray(object: Thing())
        //
        //     // Runtime warning (Not OK but unavoidable): value `Thing` is not NSObject and does not conform to MustacheBoxable: it is discarded.
        //     Box(array)
        //
        //     // Compilation error (OK): cannot find an overload for 'Box' that accepts an argument list of type '(AnyObject)'
        //     Box(array[0])
        //
        //     // Runtime warning (Not OK but unavoidable): value `Thing` is not NSObject and does not conform to MustacheBoxable: it is discarded.
        //     BoxAnyObject(array[0])
        
        print("Mustache.BoxAnyObject(): value `\(object)` is does not conform to MustacheBoxable: it is discarded.")
        return Box()
    } else {
        return Box()
    }
}


// =============================================================================
// MARK: - Boxing of Collections


// IMPLEMENTATION NOTE
//
// We don't provide any boxing function for `Sequence`, because this type
// makes no requirement on conforming types regarding whether they will be
// destructively "consumed" by iteration (as stated by documentation).
//
// Now we need to consume a sequence several times:
//
// - for converting it to an array for the arrayValue property.
// - for consuming the first element to know if the sequence is empty or not.
// - for rendering it.
//
// So we don't support boxing of sequences.

// Support for all collections
extension Collection {
    
    /**
    Concatenates the rendering of the collection items.
    
    There are two tricks when rendering collections:
    
    1. Items can render as Text or HTML, and our collection should render with
       the same type. It is an error to mix content types.
    
    2. We have to tell items that they are rendered as an enumeration item.
       This allows collections to avoid enumerating their items when they are
       part of another collections:
    
            {{# arrays }}  // Each array renders as an enumeration item, and has itself enter the context stack.
              {{#.}}       // Each array renders "normally", and enumerates its items
                ...
              {{/.}}
            {{/ arrays }}
    
    - parameter info: A RenderingInfo
    - parameter box: A closure that turns collection items into a MustacheBox.
                     It makes us able to provide a single implementation
                     whatever the type of the collection items.
    - returns: A Rendering
    */
    internal func renderItems(info: RenderingInfo, box: @noescape(Iterator.Element) -> MustacheBox) throws -> Rendering {
        // Prepare the rendering. We don't known the contentType yet: it depends on items
        var info = info
        var buffer = ""
        var contentType: ContentType? = nil
        
        // Tell items they are rendered as an enumeration item.
        //
        // Some values don't render the same whenever they render as an
        // enumeration item, or alone: {{# values }}...{{/ values }} vs.
        // {{# value }}...{{/ value }}.
        //
        // This is the case of Int, UInt, Double, Bool: they enter the context
        // stack when used in an iteration, and do not enter the context stack
        // when used as a boolean.
        //
        // This is also the case of collections: they enter the context stack
        // when used as an item of a collection, and enumerate their items when
        // used as a collection.
        
        info.enumerationItem = true
        
        for item in self {
            let boxRendering = try box(item).render(info)
            if contentType == nil
            {
                // First item: now we know our contentType
                contentType = boxRendering.contentType
                buffer += boxRendering.string
            }
            else if contentType == boxRendering.contentType
            {
                // Consistent content type: keep on buffering.
                buffer += boxRendering.string
            }
            else
            {
                // Inconsistent content type: this is an error. How are we
                // supposed to mix Text and HTML?
                throw MustacheError(kind: .RenderError, message: "Content type mismatch")
            }
        }
        
        if let contentType = contentType {
            // {{ collection }}
            // {{# collection }}...{{/ collection }}
            //
            // We know our contentType, hence the collection is not empty and
            // we render our buffer.
            return Rendering(buffer, contentType)
        } else {
            // {{ collection }}
            //
            // We don't know our contentType, hence the collection is empty.
            //
            // Now this code is executed. This means that the collection is
            // rendered, despite its emptiness.
            //
            // We are not rendering a regular {{# section }} tag, because empty
            // collections have a false boolValue, and RenderingEngine would prevent
            // us to render.
            //
            // We are not rendering an inverted {{^ section }} tag, because
            // RenderingEngine takes care of the rendering of inverted sections.
            //
            // So we are rendering a {{ variable }} tag. As en empty collection, we
            // must return an empty rendering.
            //
            // Renderings have a content type. In order to render an empty
            // rendering that has the contentType of the tag, let's use the
            // `render` method of the tag.
            return try info.tag.render(context: info.context)
        }
    }
}

// Support for Set
extension Collection where IndexDistance == Int {
    /**
    This function returns a MustacheBox that wraps a set-like collection.
    
    The returned box can be queried for the following keys:
    
    - `first`: the first object in the collection
    - `count`: number of elements in the collection
    
    - parameter value: the value of the returned box.
    - parameter box:   A closure that turns collection items into a MustacheBox.
                       It makes us able to provide a single implementation
                       whatever the type of the collection items.
    - returns: A MustacheBox that wraps the collection.
    */
    internal func mustacheBox(withSetValue value: Any?, box: @escaping (Iterator.Element) -> MustacheBox) -> MustacheBox {
        return MustacheBox(
            converter: MustacheBox.Converter(arrayValue: self.map({ box($0) })),
            value: value,
            boolValue: !isEmpty,
            keyedSubscript: { (key) in
                switch key {
                case "first":   // C: Collection
                    if let first = self.first {
                        return box(first)
                    } else {
                        return Box()
                    }
                case "count":   // C.Index.Distance == Int
                    return Box(value: self.count)
                default:
                    return Box()
                }
            },
            render: { (info: RenderingInfo) in
                if info.enumerationItem {
                    // {{# collections }}...{{/ collections }}
                    return try info.tag.render(context: info.context.extendedContext(self.mustacheBox(withSetValue: value, box: box)))
                } else {
                    // {{ collection }}
                    // {{# collection }}...{{/ collection }}
                    return try self.renderItems(info: info, box: box)
                }
            }
        )
    }
}

// Support for Array
extension BidirectionalCollection where IndexDistance == Int {
    /**
    This function returns a MustacheBox that wraps an array-like collection.
    
    The returned box can be queried for the following keys:
    
    - `first`: the first object in the collection
    - `count`: number of elements in the collection
    - `last`: the last object in the collection
    
    - parameter value: the value of the returned box.
    - parameter box:   A closure that turns collection items into a MustacheBox.
                       It makes us able to provide a single implementation
                       whatever the type of the collection items.
    - returns: A MustacheBox that wraps the collection.
    */
    internal func mustacheBox(withArrayValue value: Any?, box: @escaping (Iterator.Element) -> MustacheBox) -> MustacheBox {
        return MustacheBox(
            converter: MustacheBox.Converter(arrayValue: self.map({ box($0) })),
            value: value,
            boolValue: !isEmpty,
            keyedSubscript: { (key) in
                switch key {
                case "first":   // C: Collection
                    if let first = self.first {
                        return box(first)
                    } else {
                        return Box()
                    }
                case "last":    // C.Index: BidirectionalIndex
                    if let last = self.last {
                        return box(last)
                    } else {
                        return Box()
                    }
                case "count":   // C.Index.Distance == Int
                    return Box(value: self.count)
                default:
                    return Box()
                }
            },
            render: { (info: RenderingInfo) in
                if info.enumerationItem {
                    // {{# collections }}...{{/ collections }}
                    return try info.tag.render(context: info.context.extendedContext(self.mustacheBox(withArrayValue: value, box: box)))
                } else {
                    // {{ collection }}
                    // {{# collection }}...{{/ collection }}
                    return try self.renderItems(info: info, box: box)
                }
            }
        )
    }
}

/**
Sets of `MustacheBoxable` can feed Mustache templates.

    let set:Set<Int> = [1,2,3]

    // Renders "132", or "231", etc.
    let template = try! Template(string: "{{#set}}{{.}}{{/set}}")
    try! template.render(Box(["set": Box(set)]))


### Rendering

- `{{set}}` renders the concatenation of the set items.

- `{{#set}}...{{/set}}` renders as many times as there are items in `set`,
  pushing each item on its turn on the top of the context stack.

- `{{^set}}...{{/set}}` renders if and only if `set` is empty.


### Keys exposed to templates

A set can be queried for the following keys:

- `count`: number of elements in the set
- `first`: the first object in the set

Because 0 (zero) is falsey, `{{#set.count}}...{{/set.count}}` renders once, if
and only if `set` is not empty.


### Unwrapping from MustacheBox

Whenever you want to extract a collection of a MustacheBox, use the `arrayValue`
property: it returns an Array of MustacheBox, whatever the actual
type of the raw boxed value (Array, Set, NSArray, NSSet, ...).


- parameter array: An array of boxable values.

- returns: A MustacheBox that wraps *array*.
*/
public func Box<C: Collection where C.Iterator.Element: MustacheBoxable, C.IndexDistance == Int>(set: C?) -> MustacheBox {
    if let set = set {
        return set.mustacheBox(withSetValue: set, box: { Box(boxable: $0) })
    } else {
        return Box()
    }
}

/**
Arrays of `MustacheBoxable` can feed Mustache templates.

    let array = [1,2,3]

    // Renders "123"
    let template = try! Template(string: "{{#array}}{{.}}{{/array}}")
    try! template.render(Box(["array": Box(array)]))


### Rendering

- `{{array}}` renders the concatenation of the array items.

- `{{#array}}...{{/array}}` renders as many times as there are items in `array`,
  pushing each item on its turn on the top of the context stack.

- `{{^array}}...{{/array}}` renders if and only if `array` is empty.


### Keys exposed to templates

An array can be queried for the following keys:

- `count`: number of elements in the array
- `first`: the first object in the array
- `last`: the last object in the array

Because 0 (zero) is falsey, `{{#array.count}}...{{/array.count}}` renders once,
if and only if `array` is not empty.


### Unwrapping from MustacheBox

Whenever you want to extract a collection of a MustacheBox, use the `arrayValue`
property: it returns an Array of MustacheBox, whatever the actual
type of the raw boxed value (Array, Set, NSArray, NSSet, ...).


- parameter array: An array of boxable values.

- returns: A MustacheBox that wraps *array*.
*/
public func Box<C: BidirectionalCollection where C.Iterator.Element: MustacheBoxable, C.IndexDistance == Int>(array: C?) -> MustacheBox {
    if let array = array {
        return array.mustacheBox(withArrayValue: array, box: { Box(boxable: $0) })
    } else {
        return Box()
    }
}

/**
Arrays of `MustacheBoxable?` can feed Mustache templates.

    let array = [1,2,nil]

    // Renders "<1><2><>"
    let template = try! Template(string: "{{#array}}<{{.}}>{{/array}}")
    try! template.render(Box(["array": Box(array)]))


### Rendering

- `{{array}}` renders the concatenation of the array items.

- `{{#array}}...{{/array}}` renders as many times as there are items in `array`,
  pushing each item on its turn on the top of the context stack.

- `{{^array}}...{{/array}}` renders if and only if `array` is empty.


### Keys exposed to templates

An array can be queried for the following keys:

- `count`: number of elements in the array
- `first`: the first object in the array
- `last`: the last object in the array

Because 0 (zero) is falsey, `{{#array.count}}...{{/array.count}}` renders once,
if and only if `array` is not empty.


### Unwrapping from MustacheBox

Whenever you want to extract a collection of a MustacheBox, use the `arrayValue`
property: it returns an Array of MustacheBox, whatever the actual
type of the raw boxed value (Array, Set, NSArray, NSSet, ...).


- parameter array: An array of optional boxable values.

- returns: A MustacheBox that wraps *array*.
*/
public func Box<C: BidirectionalCollection, T where C.Iterator.Element == Optional<T>, T: MustacheBoxable, C.IndexDistance == Int>(array: C?) -> MustacheBox {
    if let array = array {
        return array.mustacheBox(withArrayValue: array, box: { Box(boxable: $0) })
    } else {
        return Box()
    }
}


// =============================================================================
// MARK: - Boxing of Dictionaries


/**
A dictionary of values that conform to the `MustacheBoxable` protocol can feed
Mustache templates. It behaves exactly like Objective-C `NSDictionary`.

    let dictionary: [String: String] = [
        "firstName": "Freddy",
        "lastName": "Mercury"]

    // Renders "Freddy Mercury"
    let template = try! Template(string: "{{firstName}} {{lastName}}")
    let rendering = try! template.render(Box(dictionary))


### Rendering

- `{{dictionary}}` renders the built-in Swift String Interpolation of the
  dictionary.

- `{{#dictionary}}...{{/dictionary}}` pushes the dictionary on the top of the
  context stack, and renders the section once.

- `{{^dictionary}}...{{/dictionary}}` does not render.


In order to iterate over the key/value pairs of a dictionary, use the `each`
filter from the Standard Library:

    // Register StandardLibrary.each for the key "each":
    let template = try! Template(string: "<{{# each(dictionary) }}{{@key}}:{{.}}, {{/}}>")
    template.registerInBaseContext("each", Box(StandardLibrary.each))

    // Renders "<firstName:Freddy, lastName:Mercury,>"
    let dictionary: [String: String] = ["firstName": "Freddy", "lastName": "Mercury"]
    let rendering = try! template.render(Box(["dictionary": dictionary]))


### Unwrapping from MustacheBox

Whenever you want to extract a dictionary of a MustacheBox, use the
`dictionaryValue` property: it reliably returns an `[String: MustacheBox]`
dictionary, whatever the actual type of the raw boxed value.


- parameter dictionary: A dictionary of values that conform to the
                        `MustacheBoxable` protocol.

- returns: A MustacheBox that wraps *dictionary*.
*/
public func Box<T: MustacheBoxable>(dictionary: [String: T]?) -> MustacheBox {
    if let dictionary = dictionary {
        return MustacheBox(
            converter: MustacheBox.Converter(
                dictionaryValue: dictionary.reduce([String: MustacheBox](), { (b, item: (key: String, value: T)) in
                    var boxDictionary = b
                    boxDictionary[item.key] = Box(boxable: item.value)
                    return boxDictionary
                })),
            value: dictionary,
            keyedSubscript: { (key: String) in
                return Box(boxable: dictionary[key])
        })
    } else {
        return Box()
    }
}

/**
A dictionary of optional values that conform to the `MustacheBoxable` protocol
can feed Mustache templates. It behaves exactly like Objective-C `NSDictionary`.

    let dictionary: [String: String?] = [
        "firstName": nil,
        "lastName": "Zappa"]

    // Renders " Zappa"
    let template = try! Template(string: "{{firstName}} {{lastName}}")
    let rendering = try! template.render(Box(dictionary))


### Rendering

- `{{dictionary}}` renders the built-in Swift String Interpolation of the
  dictionary.

- `{{#dictionary}}...{{/dictionary}}` pushes the dictionary on the top of the
  context stack, and renders the section once.

- `{{^dictionary}}...{{/dictionary}}` does not render.


In order to iterate over the key/value pairs of a dictionary, use the `each`
filter from the Standard Library:

    // Register StandardLibrary.each for the key "each":
    let template = try! Template(string: "<{{# each(dictionary) }}{{@key}}:{{.}}, {{/}}>")
    template.registerInBaseContext("each", Box(StandardLibrary.each))

    // Renders "<firstName:Freddy, lastName:Mercury,>"
    let dictionary: [String: String?] = ["firstName": "Freddy", "lastName": "Mercury"]
    let rendering = try! template.render(Box(["dictionary": dictionary]))


### Unwrapping from MustacheBox

Whenever you want to extract a dictionary of a MustacheBox, use the
`dictionaryValue` property: it reliably returns an `[String: MustacheBox]`
dictionary, whatever the actual type of the raw boxed value.


- parameter dictionary: A dictionary of optional values that conform to the
                        `MustacheBoxable` protocol.

- returns: A MustacheBox that wraps *dictionary*.
*/
public func Box<T: MustacheBoxable>(optionalDictionary dictionary: [String: T?]?) -> MustacheBox {
    if let dictionary = dictionary {
        return MustacheBox(
            converter: MustacheBox.Converter(
                dictionaryValue: dictionary.reduce([String: MustacheBox](), { (b, item: (key: String, value: T?)) in
                    var boxDictionary = b
                    boxDictionary[item.key] = Box(value: item.value)
                    return boxDictionary
                })),
            value: dictionary,
            keyedSubscript: { (key: String) in
                if let value = dictionary[key] {
                    return Box(value: value)
                } else {
                    return Box()
                }
        })
    } else {
        return Box()
    }
}

// =============================================================================
// MARK: - Boxing of Core Mustache functions

/**
A function that wraps a `FilterFunction` into a `MustacheBox` so that it can
feed template.

    let square: FilterFunction = Filter { (x: Int?) in
        return Box(x! * x!)
    }

    let template = try! Template(string: "{{ square(x) }}")
    template.registerInBaseContext("square", Box(square))

    // Renders "100"
    try! template.render(Box(["x": 10]))

- parameter filter: A FilterFunction.
- returns: A MustacheBox that wraps *filter*.

See also:

- FilterFunction
*/
public func Box(filter: FilterFunction) -> MustacheBox {
    return MustacheBox(filter: filter)
}

/**
A function that wraps a `RenderFunction` into a `MustacheBox` so that it can
feed template.

    let foo: RenderFunction = { (_) in Rendering("foo") }

    // Renders "foo"
    let template = try! Template(string: "{{ foo }}")
    try! template.render(Box(["foo": Box(foo)]))

- parameter render: A RenderFunction.
- returns: A MustacheBox that wraps *render*.

See also:

- RenderFunction
*/
public func Box(render: RenderFunction) -> MustacheBox {
    return MustacheBox(render: render)
}

/**
A function that wraps a `WillRenderFunction` into a `MustacheBox` so that it can
feed template.

    let logTags: WillRenderFunction = { (tag: Tag, box: MustacheBox) in
        print("\(tag) will render \(box.value!)")
        return box
    }

    // By entering the base context of the template, the logTags function
    // will be notified of all tags.
    let template = try! Template(string: "{{# user }}{{ firstName }} {{ lastName }}{{/ user }}")
    template.extendBaseContext(Box(logTags))

    // Prints:
    // {{# user }} at line 1 will render { firstName = Errol; lastName = Flynn; }
    // {{ firstName }} at line 1 will render Errol
    // {{ lastName }} at line 1 will render Flynn
    let data = ["user": ["firstName": "Errol", "lastName": "Flynn"]]
    try! template.render(Box(data))

- parameter willRender: A WillRenderFunction
- returns: A MustacheBox that wraps *willRender*.

See also:

- WillRenderFunction
*/
public func Box(willRender: WillRenderFunction) -> MustacheBox {
    return MustacheBox(willRender: willRender)
}

/**
A function that wraps a `DidRenderFunction` into a `MustacheBox` so that it can
feed template.

    let logRenderings: DidRenderFunction = { (tag: Tag, box: MustacheBox, string: String?) in
        print("\(tag) did render \(box.value!) as `\(string!)`")
    }

    // By entering the base context of the template, the logRenderings function
    // will be notified of all tags.
    let template = try! Template(string: "{{# user }}{{ firstName }} {{ lastName }}{{/ user }}")
    template.extendBaseContext(Box(logRenderings))

    // Renders "Errol Flynn"
    //
    // Prints:
    // {{ firstName }} at line 1 did render Errol as `Errol`
    // {{ lastName }} at line 1 did render Flynn as `Flynn`
    // {{# user }} at line 1 did render { firstName = Errol; lastName = Flynn; } as `Errol Flynn`
    let data = ["user": ["firstName": "Errol", "lastName": "Flynn"]]
    try! template.render(Box(data))

- parameter didRender: A DidRenderFunction/
- returns: A MustacheBox that wraps *didRender*.

See also:

- DidRenderFunction
*/
public func Box(didRender: DidRenderFunction) -> MustacheBox {
    return MustacheBox(didRender: didRender)
}

///**
//The empty box, the box that represents missing values.
//*/
//public func Box() -> MustacheBox {
//    return EmptyBox
//}
//
//private let EmptyBox = MustacheBox()

// =============================================================================
// MARK: - Boxing of multi-facetted values


/**
This function is the most low-level function that lets you build MustacheBox
for feeding templates.

It is suited for building "advanced" boxes. There are other simpler versions of
the `Box` function that may well better suit your need: you should check them.

It can take up to seven parameters, all optional, that define how the box
interacts with the Mustache engine:

- `boolValue`:      an optional boolean value for the Box.
- `value`:          an optional boxed value
- `keyedSubscript`: an optional KeyedSubscriptFunction
- `filter`:         an optional FilterFunction
- `render`:         an optional RenderFunction
- `willRender`:     an optional WillRenderFunction
- `didRender`:      an optional DidRenderFunction


To illustrate the usage of all those parameters, let's look at how the
`{{f(a)}}` tag is rendered.

First the `a` and `f` expressions are evaluated. The Mustache engine looks in
the context stack for boxes whose *keyedSubscript* return non-empty boxes for
the keys "a" and "f". Let's call them aBox and fBox.

Then the *filter* of the fBox is evaluated with aBox as an argument. It is
likely that the result depends on the *value* of the aBox: it is the resultBox.

Then the Mustache engine is ready to render resultBox. It looks in the context
stack for boxes whose *willRender* function is defined. Those willRender
functions have the opportunity to process the resultBox, and eventually provide
the box that will be actually rendered: the renderedBox.

The renderedBox has a *render* function: it is evaluated by the Mustache engine
which appends its result to the final rendering.

Finally the Mustache engine looks in the context stack for boxes whose
*didRender* function is defined, and call them.


### boolValue

The optional `boolValue` parameter tells whether the Box should trigger or
prevent the rendering of regular `{{#section}}...{{/}}` and inverted
`{{^section}}...{{/}}` tags. The default value is true, unless the function is
called without argument to build the empty box: `Box()`.

// Render "true", "false"
let template = try! Template(string:"{{#.}}true{{/.}}{{^.}}false{{/.}}")
template.render(Box(boolValue: true))!
template.render(Box(boolValue: false))!


### value

The optional `value` parameter gives the boxed value. The value is used when the
box is rendered (unless you provide a custom RenderFunction).

let aBox = Box(value: 1)

// Renders "1"
let template = try! Template(string: "{{a}}")
try! template.render(Box(["a": aBox]))


### keyedSubscript

The optional `keyedSubscript` parameter is a `KeyedSubscriptFunction` that lets
the Mustache engine extract keys out of the box. For example, the `{{a}}` tag
would call the subscript function with `"a"` as an argument, and render the
returned box.

The default value is nil, which means that no key can be extracted.

See `KeyedSubscriptFunction` for a full discussion of this type.

let box = Box(keyedSubscript: { (key: String) in
return Box("key:\(key)")
})

// Renders "key:a"
let template = try! Template(string:"{{a}}")
try! template.render(box)


### filter

The optional `filter` parameter is a `FilterFunction` that lets the Mustache
engine evaluate filtered expression that involve the box. The default value is
nil, which means that the box can not be used as a filter.

See `FilterFunction` for a full discussion of this type.

let box = Box(filter: Filter { (x: Int?, _) in
return Box(x! * x!)
})

// Renders "100"
let template = try! Template(string:"{{square(x)}}")
try! template.render(Box(["square": box, "x": Box(10)]))


### render

The optional `render` parameter is a `RenderFunction` that is evaluated when the
Box is rendered.

The default value is nil, which makes the box perform default Mustache
rendering:

- `{{box}}` renders the built-in Swift String Interpolation of the value,
HTML-escaped.

- `{{{box}}}` renders the built-in Swift String Interpolation of the value,
not HTML-escaped.

- `{{#box}}...{{/box}}` does not render if `boolValue` is false. Otherwise, it
pushes the box on the top of the context stack, and renders the section once.

- `{{^box}}...{{/box}}` renders once if `boolValue` is false. Otherwise, it
does not render.

See `RenderFunction` for a full discussion of this type.

let box = Box(render: { (info: RenderingInfo) in
return Rendering("foo")
})

// Renders "foo"
let template = try! Template(string:"{{.}}")
try! template.render(box)


### willRender, didRender

The optional `willRender` and `didRender` parameters are a `WillRenderFunction`
and `DidRenderFunction` that are evaluated for all tags as long as the box is in
the context stack.

See `WillRenderFunction` and `DidRenderFunction` for a full discussion of those
types.

let box = Box(willRender: { (tag: Tag, box: MustacheBox) in
return Box("baz")
})

// Renders "baz baz"
let template = try! Template(string:"{{#.}}{{foo}} {{bar}}{{/.}}")
try! template.render(box)


### Multi-facetted boxes

By mixing all those parameters, you can finely tune the behavior of a box.

GRMustache source code ships a few multi-facetted boxes, which may inspire you.
See for example:

- NSFormatter.mustacheBox
- HTMLEscape.mustacheBox
- StandardLibrary.Localizer.mustacheBox

Let's give an example:

// A regular type:

struct Person {
let firstName: String
let lastName: String
}

We want:

1. `{{person.firstName}}` and `{{person.lastName}}` should render the matching
properties.
2. `{{person}}` should render the concatenation of the first and last names.

We'll provide a `KeyedSubscriptFunction` to implement 1, and a `RenderFunction`
to implement 2:

// Have Person conform to MustacheBoxable so that we can box people, and
// render them:

extension Person : MustacheBoxable {

// MustacheBoxable protocol requires objects to implement this property
// and return a MustacheBox:

var mustacheBox: MustacheBox {

// A person is a multi-facetted object:
return Box(
// It has a value:
value: self,

// It lets Mustache extracts properties by name:
keyedSubscript: { (key: String) -> MustacheBox in
switch key {
case "firstName": return Box(self.firstName)
case "lastName":  return Box(self.lastName)
default:          return Box()
}
},

// It performs custom rendering:
render: { (info: RenderingInfo) -> Rendering in
switch info.tag.type {
case .Variable:
// {{ person }}
return Rendering("\(self.firstName) \(self.lastName)")
case .Section:
// {{# person }}...{{/}}
//
// Perform the default rendering: push self on the top
// of the context stack, and render the section:
let context = info.context.extendedContext(Box(self))
return try info.tag.render(context)
}
}
)
}
}

// Renders "The person is Errol Flynn"
let person = Person(firstName: "Errol", lastName: "Flynn")
let template = try! Template(string: "{{# person }}The person is {{.}}{{/ person }}")
try! template.render(Box(["person": person]))

- parameter value:          An optional boxed value.
- parameter boolValue:      An optional boolean value for the Box.
- parameter keyedSubscript: An optional `KeyedSubscriptFunction`.
- parameter filter:         An optional `FilterFunction`.
- parameter render:         An optional `RenderFunction`.
- parameter willRender:     An optional `WillRenderFunction`.
- parameter didRender:      An optional `DidRenderFunction`.
- returns: A MustacheBox.
*/
public func Box(
    value: Any? = nil,
    boolValue: Bool? = nil,
    keyedSubscript: KeyedSubscriptFunction? = nil,
    filter: FilterFunction? = nil,
    render: RenderFunction? = nil,
    willRender: WillRenderFunction? = nil,
    didRender: DidRenderFunction? = nil) -> MustacheBox
{

    return MustacheBox(
        value: value,
        boolValue: boolValue,
        keyedSubscript: keyedSubscript,
        filter: filter,
        render: render,
        willRender: willRender,
        didRender: didRender)

}
