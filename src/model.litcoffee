# Model - instance of schema-driven data

The `Model` class aggregates [Property](./property.litcoffee)
attachments to provide the *adaptive* and *event-driven* data
interactions.

It is typically not instantiated directly, but is generated as a
result of [Yang::eval](./yang.litcoffee#eval-data-opts) for a YANG
`module` schema.

```javascript
var schema = Yang.parse('module foo { container bar { leaf a { type uint8; } } }');
var model = schema.eval({ 'foo:bar': { a: 7 } });
// model is { 'foo:bar': [Getter/Setter] }
```

The generated `Model` is a hierarchical composition of
[Property](./property.litcoffee) instances. The instance itself uses
`Object.preventExtensions` to ensure no additional properties that are
not known to itself can be added.

It is designed to provide *stand-alone* interactions on a per-module
basis. For flexible management of multiple modules (such as hotplug
modules) and data persistence, please take a look at the
[yang-store](http://github.com/corenova/yang-store) project.

## Class Model

    Stack    = require 'stacktrace-parser'
    Yang     = require './yang'
    Property = require './property'
    XPath    = require './core/xpath'

    class Model extends Property
      
      @Store = {}
      
      constructor: (schema, data={}) ->
        unless schema?.kind is 'module'
          throw new Error "cannot create Model without YANG 'module' schema"

        # apply features to Model if exists
        feature.apply this for feature in schema.feature if schema.feature?

        data = node.apply data for node in schema.nodes
        if schema.import?
          for dep in schema.import when dep.tag not of Model.Store
            new Model dep.module, data 

        super schema.tag, data, schema: schema
        
        @on 'update', -> @save() unless @transactable
        # register this instance in the Model class singleton instance
        @join Model.Store

      valueOf: -> super false

### save

This routine triggers a 'commit' event for listeners to handle any
persistence operations. It also clears the `@updates` transaction
queue so that future [rollback](#rollback) will reset back to this state.

      save: -> @emit 'commit', @updates.slice(); super

### set (path..., value)

This routine allows `set` operation to reference an optional XPATH
location to update with the passed in `value`. Also, it restricts the
direct `set` operation on a Model to always peform a `merge: true`.

      set: (path..., value) ->
        if path.length then @in(path[0])?.set? value
        else super value, merge: true

### find (pattern)

This routine enables *cross-model* property search when the `Model` is
joined to another object (such as a datastore). The schema-bound model
restricts *cross-model* property access to only those modules that are
`import` dependencies of the current model instance.

      find: (pattern='.', opts={}) ->
        return super unless @parent?
        
        console.debug? "[Model:#{@name}] find #{pattern}"
        match = super pattern, root: true
        return match if match?.length or opts.root
        
        # here we have a @parent that likely has a collectin of Models
        opts.root = true
        for k, model of @parent.__props__ when k isnt @name
          console.debug? "[Model:#{@name}] looking at #{k}.find"
          try match = model.find pattern, opts
          catch then continue
          return match if match?.length
        return []

### invoke (path, input)

Executes a `Property` holding a function found at the `path` using the
`input` data.

      invoke: (path, args...) ->
        target = @in(path)
        unless target?
          throw @error "cannot invoke on '#{path}', not found"
        target.invoke args...

### on (event)

The `Model` instance is an `EventEmitter` and you can attach various
event listeners to handle events generated by the `Model`:

event | arguments | description
--- | --- | ---
update | (prop, prev) | fired when an update takes place within the data tree
change | (elems...) | fired when the schema is modified
create | (items...) | fired when one or more `list` element is added
delete | (items...) | fired when one or more `list` element is deleted

It also accepts optional XPATH/YPATH expressions which will *filter*
for granular event subscription to specified events from only the
elements of interest.

The event listeners to the `Model` can handle any customized behavior
such as saving to database, updating read-only state, scheduling
background tasks, etc.

This operation is protected from recursion, where operations by the
`callback` may result in the same `callback` being executed multiple
times due to subsequent events triggered due to changes to the
`Model`. Currently, it will allow the same `callback` to be executed
at most two times.

      on: (event, filters..., callback) ->
        unless callback instanceof Function
          throw new Error "must supply callback function to listen for events"
          
        recursive = (name) ->
          seen = {}
          frames = Stack.parse(new Error().stack)
          for frame, i in frames when ~frame.methodName.indexOf(name)
            { file, lineNumber, column } = frames[i-1]
            callee = "#{file}:#{lineNumber}:#{column}"
            seen[callee] ?= 0
            if ++seen[callee] > 1
              console.warn "detected recursion for '#{callee}'"
              return true 
          return false

        $$$ = (prop, args...) ->
          console.debug? "$$$: check if '#{prop.path}' in '#{filters}'"
          if not filters.length or prop.path.contains filters...
            unless recursive('$$$')
              callback.apply this, [prop].concat args

        super event, $$$

Please refer to [Model Events](../TUTORIAL.md#model-events) section of
the [Getting Started Guide](../TUTORIAL.md) for usage examples.

### in (pattern)

A convenience routine to locate one or more matching Property
instances based on `pattern` (XPATH or YPATH) from this Model.

      in: (pattern) ->
        try props = @find pattern
        return unless props? and props.length
        return switch
          when props.length > 1 then props
          else props[0]

## Export Model Class

    module.exports = Model
