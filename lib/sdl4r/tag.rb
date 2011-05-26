#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
# Simple Declarative Language (SDL) for Ruby
# Copyright 2005 Ikayzo, inc.
#
# This program is free software. You can distribute or modify it under the
# terms of the GNU Lesser General Public License version 2.1 as published by
# the Free Software Foundation.
#
# This program is distributed AS IS and WITHOUT WARRANTY. OF ANY KIND,
# INCLUDING MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, contact the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#++


module SDL4R

  require 'pathname'
  require 'open-uri'
  require 'stringio'
  
  require File.dirname(__FILE__) + '/sdl4r'
  require File.dirname(__FILE__) + '/parser'

  # SDL documents are made of Tags.
  #
  # See the README[link:files/README.html] for a longer explanation on SDL documents.
  #
  # Do not assume that methods returning sets (Hash, Array, etc) of children/values/attributes/etc
  # in this class returns copies or implementations. It can be one or the other depending on the
  # method. The implementations are designed to be correct and somewhat efficient, not too protect
  # the Tag internal state from ill-use of the returned values.
  #
  # == Authors
  # Daniel Leuck, Philippe Vosges
  #
  class Tag
    
    # the name of this Tag
    #
    attr_reader :name
    
    # the namespace of this Tag or an empty string when there is no namespace (i.e. default
    # namespace).
    #
    attr_reader :namespace

    # Convenient method to check and handle a pair of parameters namespace/name where, in some
    # cases, only one is specified (i.e. the name only).
    #
    # Use at the beginning of a method in order to have correctly defined parameters:
    #   def foo(namespace, name = nil)
    #     namespace, name = to_nns namespace, name
    #   end
    #
    def to_nns(namespace, name)
      if name.nil? and not namespace.nil?
        name = namespace
        namespace = ""
      end
      return namespace, name
    end
    private :to_nns
    
    # Creates an empty tag in the given namespace.  If the +namespace+ is nil
    # it will be coerced to an empty String.
    #
    #   tag = Tag.new("name")
    #   tag = Tag.new("namespace", "name")
    #
    #   tag = Tag.new("fruit") do
    #     add_value 2
    #     new_child("orange") do
    #       set_attribute("quantity", 2)
    #     end
    #   end
    #
    # which builds the following SDL structure
    #
    #   fruit 2 {
    #     orange quantity=2
    #   }
    #
    # If you provide a block that takes an argument, you will write the same example, as follows:
    #
    #   tag = Tag.new("fruit") do |t|
    #     t.add_value 2
    #     t.new_child("orange") do
    #       set_attribute("quantity", 2)
    #     end
    #   end
    #
    # In this case, the current context is not the new Tag anymore but the context of your code.
    #
    # === Raises
    # ArgumentError if the name is not a legal SDL identifier
    # (see SDL4R#validate_identifier) or the namespace is non-blank
    # and is not a legal SDL identifier.
    #
    def initialize(namespace, name = nil, &block)
      namespace, name = to_nns namespace, name

      raise ArgumentError, "tag namespace must be a String" unless namespace.is_a? String
      raise ArgumentError, "tag name must be a String" unless name.is_a? String

      SDL4R.validate_identifier(namespace) unless namespace.empty?
      @namespace = namespace
      
      name = name.to_s.strip
      raise ArgumentError, "Tag name cannot be nil or empty" if name.empty?
      SDL4R.validate_identifier(name)
      @name = name
      
      @children = []
      @values = []
      
      # a Hash of Hash : {namespace => {name => value}}
      # The default namespace is represented by an empty string.
      @attributesByNamespace = {}

      if block_given?
        if block.arity > 0
          block[self]
        else
          instance_eval(&block)
        end
      end
    end

    # Creates a new child tag.
    # Can take a block so that you can write something like:
    #
    #   car = Tag.new("car") do
    #     new_child("wheels") do
    #       self << 4
    #     end
    #   end
    #
    # The context of execution of the given block is the child instance.
    # If you provide a block that takes a parameter (see below), the context is the context of your
    # code:
    #
    #   car = Tag.new("car") do |child|
    #     child.new_child("wheels") do |grandchild|
    #       grandchild << 4
    #     end
    #   end
    #
    # Returns the created child Tag.
    #
    def new_child(*args, &block)
      return add_child Tag.new(*args, &block)
    end
  
    # Add a child to this Tag.
    # 
    # _child_:: The child to add
    # 
    # Returns the added child.
    #
    def add_child(child)
      @children.push(child)
      return child
    end

    # Adds the given object as a child if it is a +Tag+, as an attribute if it is a Hash
    # {key => value} (supports namespaces), or as a value otherwise.
    # If it is an Enumerable (e.g. Array), each of its elements is added to this Tag via this
    # operator. If any of its elements is itself an Enumerable, then an anonymous tag is created and
    # the Enumerable is passed to it via this operator (see the examples below).
    #
    #   tag << Tag.new("child")
    #   tag << 123                          # new integer value
    #   tag << "islamabad"                  # new string value
    #   tag << { "metric:length" => 1027 }  # new attribute (with namespace)
    #   tag << [nil, 456, "abc"]            # several values added
    #
    #   tag = Tag.new("tag")
    #   tag << [[1, 2, 3], [4, 5, 6]]       # tag {
    #                                       #   1 2 3
    #                                       #   4 5 6
    #                                       # }
    #
    # Of course, despite the fact that String is an Enumerable, it is considered as the type of
    # values.
    #
    # Returns +self+.
    #
    # Use other accessors (#add_child, #add_value, #attributes, etc) for a stricter and less
    # "magical" behavior.
    #
    def <<(o)
      if o.is_a?(Tag)
        add_child(o)
      elsif o.is_a?(Hash)
        o.each_pair { |key, value|
          namespace, key = key.split(/:/) if key.match(/:/)
          namespace ||= ""
          set_attribute(namespace, key, value)
        }
      elsif o.is_a? String
        add_value(o)
      elsif o.is_a? Enumerable
        o.each { |item|
          if item.is_a? Enumerable and not item.is_a? String
            anonymous = new_child("content")
            anonymous << item
          else
            self << item
          end
        }
      else
        add_value(o)
      end
      return self
    end
    
    # Remove a child from this Tag
    # 
    # _child_:: the child to remove
    #
    # Returns true if the child exists and is removed
    #
    def remove_child(child)
      return !@children.delete(child).nil?
    end

    # Removes all children.
    #
    def clear_children
      @children = []
      nil
    end
    
    #
    # A convenience method that sets the first value in the value list.
    # See # #add_value for legal types.
    # 
    # _value_:: The value to be set.
    #
    # === Raises
    #
    # _ArgumentError_:: if the value is not a legal SDL type
    #
    def value=(value)
      @values[0] = SDL4R.coerce_or_fail(value)
      nil
    end
    
    #
    # A convenience method that returns the first value.
    #
    def value
      @values[0]
    end

    # Returns the number of children Tag.
    #
    def child_count
      @children.size
    end

    #   children(recursive)
    #   children(recursive, name)
    #   children(recursive, namespace, name)
    #   
    #   children(recursive) { |child| ... }
    #   children(recursive, name) { |child| ... }
    #   children(recursive, namespace, name) { |child| ... }
    #
    # Returns an Array of the children Tags of this Tag or enumerates them.
    #
    # _recursive_:: if true children and all descendants will be returned. False by default.
    # _name_:: if not nil, only children having this name will be returned. Nil by default.
    # _namespace_:: use nil for all namespaces and "" for the default one. Nil by default.
    #
    #   tag.children # => array of the children
    #   tag.children(true) { |descendant| ... }
    #
    #   tag.children(false, "name") # => children of name "name"
    #   tag.children(false, "ns", nil) # => children of namespace "ns"
    #
    def children(recursive = false, namespace = nil, name = :DEFAULT, &block) # :yields: child
      if name == :DEFAULT
        name = namespace
        namespace = nil
      end

      if block_given?
        each_child(recursive, namespace, name, &block)
        return nil
        
      else
        unless recursive or name or namespace
          return @children
          
        else
          result = []
          each_child(recursive, namespace, name) { |child|
            result << child
          }
          return result
        end
      end
    end

    # Returns the values of all the children with the given +name+. If the child has
    # more than one value, all the values will be added as an array. If the child
    # has no value, +nil+ will be added. The search is not recursive.
    #
    # _name_:: if nil, all children are considered (nil by default).
    def children_values(name = nil)
      children_values = []
      each_child(false, name) { |child|
        case child.values.size
        when 0
          children_values << nil
        when 1
          children_values << child.value
        else
          children_values << child.values
        end
      }
      return children_values
    end

    #   child
    #   child(name)
    #   child(recursive, name)
    #
    # Get the first child with the given name, optionally using a recursive search.
    # 
    # _name_:: the name of the child Tag. If +nil+, the first child is returned (+nil+ if there are
    # no children at all).
    # 
    # Returns the first child tag having the given name or +nil+ if no such child exists
    #
    def child(recursive = false, name = nil)
      if name.nil?
        name = recursive
        recursive = false
      end
      
      unless name
        return @children.first
      else
        each_child(recursive, name) { |child| return child }
      end
    end

    # Indicates whether the child Tag of given name exists.
    #
    # _name_:: name of the searched child Tag
    #
    def has_child?(name)
      !child(name).nil?
    end

    # Indicates whether there are children Tag.
    #
    def has_children?
      !@children.empty?
    end

    # Enumerates the children +Tag+s of this Tag and calls the given block
    # providing it the child as parameter.
    #
    # _recursive_:: if true, enumerate grand-children, etc, recursively
    # _namespace_:: if not nil, indicates the namespace of the children to enumerate
    # _name_:: if not nil, indicates the name of the children to enumerate
    #
    def each_child(recursive = false, namespace = nil, name = :DEFAULT, &block)
      if name == :DEFAULT
        name = namespace
        namespace = nil
      end

      @children.each do |child|
        if (name.nil? or child.name == name) and
            (namespace.nil? or child.namespace == namespace)
          yield child
        end

        child.children(recursive, namespace, name, &block) if recursive
      end
      return nil
    end
    private :each_child

    # Returns a new Hash where the children's names as keys and their values as the key's value.
    # Example:
    #
    #   child1 "toto"
    #   child2 2
    #
    # would give
    #
    #   { "child1" => "toto", "child2" => 2 }
    #
    def to_child_hash
      hash = {}
      children { |child| hash[child.name] = child.value }
      return hash
    end

    # Returns a new Hash where the children's names as keys and their values as the key's value.
    # Values are converted to Strings. +nil+ values become empty Strings.
    # Example:
    #
    #   child1 "toto"
    #   child2 2
    #   child3 null
    #
    # would give
    #
    #   { "child1" => "toto", "child2" => "2", "child3" => "" }
    #
    def to_child_string_hash
      hash = {}
      children do |child|
        # FIXME: it is quite hard to be sure whether we should mimic the Java version
        # as there might be a lot of values that don't translate nicely to Strings.
        hash[child.name] = child.value.to_s
      end
      return hash
    end
    
    # Adds a value to this Tag. See SDL4R#coerce_or_fail to know about the allowable types.
    #
    # _v_:: The value to add
    #
    # Raises an +ArgumentError+ if the value is not a legal SDL type
    #
    def add_value(v)
      @values.push(SDL4R::coerce_or_fail(v))
      return nil
    end

    # Returns true if +v+ is a value of this Tag's.
    #
    def has_value?(v)
      @values.include?(v)
    end
    
    # Removes the first occurence of the specified value from this Tag.
    # 
    # _v_:: The value to remove
    #
    # Returns true If the value exists and is removed
    #
    def remove_value(v)
      index = @values.index(v)
      if index
        return !@values.delete_at(index).nil?
      else
        return false
      end
    end

    # Removes all values.
    #
    def clear_values
      @values = []
      nil
    end
    
    # Returns an Array of the values of this Tag or enumerates them.
    #
    #   tag.values # => [123, "spices"]
    #   tag.values { |value| puts value }
    #
    def values # :yields: value
      if block_given?
        @values.each { |v| yield v }
        nil
      else
        return @values
      end
    end
    
    # Set the values for this tag.  See #add_value for legal value types.
    # 
    # _values_:: The new values
    #
    # Raises an +ArgumentError+ if the collection contains any values which are not legal SDL types.
    #
    def values=(someValues)
      @values.clear()
      someValues.to_a.each { |v|
        # this is required to ensure validation of types
        add_value(v)
      }
      nil
    end
  
    #   set_attribute(key, value)
    #   set_attribute(namespace, key, value)
    #
    # Set an attribute in the given namespace for this tag.  The allowable
    # attribute value types are the same as those allowed for #add_value.
    # 
    # _namespace_:: The namespace for this attribute
    # _key_:: The attribute key
    # _value_:: The attribute value
    #
    # Raises +ArgumentError+ if the key is not a legal SDL identifier (see
    # SDL4R#validate_identifier), or the namespace is non-blank and is not a legal SDL identifier,
    # or thevalue is not a legal SDL type
    #
    def set_attribute(namespace, key, value = :default)
      if value == :default
        value = key
        key = namespace
        namespace = ""
      end

      raise ArgumentError, "attribute namespace must be a String" unless namespace.is_a? String
      raise ArgumentError, "attribute key must be a String" unless key.is_a? String
      raise ArgumentError, "attribute key cannot be empty" if key.empty?

      SDL4R.validate_identifier(namespace) unless namespace.empty?
      SDL4R.validate_identifier(key)

      attributes = @attributesByNamespace[namespace]
      
      if attributes.nil?
        attributes = {}
        @attributesByNamespace[namespace] = attributes
      end
      
      attributes[key] = SDL4R.coerce_or_fail(value)
    end
    
    #   attribute(key)
    #   attribute(namespace, key)
    #
    # Returns the attribute of the specified +namespace+ of specified +key+ or +nil+ if not found.
    #
    #
    def attribute(namespace, key = nil)
      namespace, key = to_nns namespace, key
      attributes = @attributesByNamespace[namespace]
      return attributes.nil? ? nil : attributes[key]
    end

    # Indicates whether there is at least an attribute in this Tag.
    #   has_attribute?
    #
    # Indicates whether there is the specified attribute exists in this Tag.
    #   has_attribute?(key)
    #   has_attribute?(namespace, key)
    #
    def has_attribute?(namespace = nil, key = nil)
      namespace, key = to_nns namespace, key

      if namespace or key
        attributes = @attributesByNamespace[namespace]
        return attributes.nil? ? false : attributes.has_key?(key)

      else
        attributes { return true }
        return false
      end
    end
    
    # Returns a Hash of the attributes of the specified +namespace+ (default is all) or enumerates
    # them.
    #
    #   tag.attributes # => { "length" => 123, "width" = 25.4, "orig:color" => "gray" }
    #   tag.attributes("orig") do |namespace, key, value|
    #     p "#{namespace}:#{key} = #{value}"
    #   end
    #
    # _namespace_::
    # namespace of the returned attributes. If nil, all attributes are returned with
    # qualified names (e.g. "meat:color"). If "", attributes of the default namespace are returned.
    #
    def attributes(namespace = nil, &block) # :yields: namespace, key, value
      if block_given?
        each_attribute(namespace, &block)
        
      else
        if namespace.nil?
          hash = {}

          each_attribute do | namespace, key, value |
            qualified_name = namespace.empty? ? key : namespace + ':' + key
            hash[qualified_name] = value
          end

          return hash

        else
          return @attributesByNamespace[namespace]
        end
      end
    end

    #   remove_attribute(key)
    #   remove_attribute(namespace, key)
    #
    # Removes the attribute, whose name and namespace are specified.
    #
    # _key_:: name of the removed atribute
    # _namespace_:: namespace of the removed attribute (equal to "", default namespace, by default)
    #
    # Returns the value of the removed attribute or +nil+ if it didn't exist.
    #
    def remove_attribute(namespace, key = nil)
      namespace, key = to_nns namespace, key
      attributes = @attributesByNamespace[namespace]
      return attributes.nil? ? nil : attributes.delete(key)
    end

    # Clears the attributes of the specified namespace or all the attributes if +namespace+ is
    # +nil+.
    #
    def clear_attributes(namespace = nil)
      if namespace.nil?
        @attributesByNamespace.clear
      else
        @attributesByNamespace.delete(namespace)
      end
    end
    
    # Enumerates the attributes for the specified +namespace+.
    # Enumerates all the attributes by default.
    #
    def each_attribute(namespace = nil, &block) # :yields: namespace, key, value
      if namespace.nil?
        @attributesByNamespace.each_key { |a_namespace| each_attribute(a_namespace, &block) }
        
      else
        attributes = @attributesByNamespace[namespace]
        unless attributes.nil?
          attributes.each_pair do |key, value|
            yield namespace, key, value
          end
        end
      end
    end
    private :each_attribute
    

    #   set_attributes(attribute_hash)
    #   set_attributes(namespace, attribute_hash)
    #
    # Sets the attributes specified by a Hash in the given +namespace+ in one operation. The
    # previous attributes of the specified +namespace+ are removed.
    # See #set_attribute for allowable attribute value types.
    # 
    # _attributes_:: a Hash where keys are attribute keys
    # _namespace_:: "" (default namespace) by default
    # 
    # Raises an +ArgumentError+ if any key in the map is not a legal SDL identifier
    # (see SDL4R#validate_identifier), or any value is not a legal SDL type.
    #
    def set_attributes(namespace, attribute_hash = nil)
      if attribute_hash.nil?
        attribute_hash = namespace
        namespace = ""
      end
      
      raise ArgumentError, "namespace can't be nil" if namespace.nil?
      raise ArgumentError, "attribute_hash should be a Hash" unless attribute_hash.is_a? Hash

      namespace_attributes = @attributesByNamespace[namespace]
      namespace_attributes.clear if namespace_attributes
      
      attribute_hash.each_pair do |key, value|
          # Calling set_attribute() is required to ensure validations
          set_attribute(namespace, key, value)
      end
    end
    
    # Sets all the attributes of the default namespace for this Tag in one
    # operation.
    # 
    # See #set_attributes.
    #
    def attributes=(attribute_hash)
      set_attributes(attribute_hash)
    end
  
    # Sets the name of this Tag.
    # 
    # Raises +ArgumentError+ if the name is not a legal SDL identifier
    # (see SDL4R#validate_identifier).
    #
    def name=(a_name)
      a_name = a_name.to_s
      SDL4R.validate_identifier(a_name)
      @name = a_name
    end
  
    # The namespace to set. +nil+ will be coerced to the empty string.
    # 
    # Raises +ArgumentError+ if the namespace is non-blank and is not
    # a legal SDL identifier (see SDL4R#validate_identifier)
    #
    def namespace=(a_namespace)
      a_namespace = a_namespace.to_s
      SDL4R.validate_identifier(a_namespace) unless a_namespace.empty?
      @namespace = a_namespace
    end
        
    # Adds all the tags specified in the given IO, String, Pathname or URI to this Tag.
    # 
    # Returns this Tag after adding all the children read from +input+.
    #
    def read(input)
      if input.is_a? String
        read_from_io(true) { StringIO.new(input) }

      elsif input.is_a? Pathname
        read_from_io(true) { input.open("r:UTF-8") }

      elsif input.is_a? URI
        read_from_io(true) { input.open }

      else
        read_from_io(false) { input }
      end
      
      return self
    end

    # Reads and parses the +io+ returned by the specified block and closes this +io+ if +close_io+
    # is true.
    def read_from_io(close_io)
      io = yield

      begin
        Parser.new(io).parse.each do |tag|
          add_child(tag)
        end

      ensure
        if close_io
          io.close rescue IOError
        end
      end
    end
    private_methods :read_io
    
    # Write this tag out to the given IO or StringIO or String (optionally clipping the root.)
    # Returns +output+.
    # 
    # _output_:: an IO or StringIO or a String to write to
    # +include_root+:: if true this tag will be written out as the root element, if false only the
    #   children will be written. False by default.
    #
    def write(output, include_root = false)
      if output.is_a? String
        io = StringIO.new(output)
        close_io = true # indicates we close the IO ourselves
      elsif output.is_a? IO or output.is_a? StringIO
        io = output
        close_io = false # let the caller close the IO
      else
        raise ArgumentError, "'output' should be a String or an IO but was #{output.class}"
      end
      
      if include_root
        io << to_s
      else
        first = true
        children do |child|
          io << $/ unless first
          first = false
          io << child.to_s
        end
      end
      
      io.close() if close_io

      output
    end
  
    # Get a String representation of this SDL Tag.  This method returns a
    # complete description of the Tag's state using SDL (i.e. the output can
    # be parsed by #read)
    # 
    # Returns A string representation of this tag using SDL
    #
    def to_s
      to_string
    end
    
    # _linePrefix_:: A prefix to insert before every line.
    # Returns A string representation of this tag using SDL
    # 
    # TODO: break up long lines using the backslash
    #
    def to_string(line_prefix = "", indent = "\t")
      line_prefix = "" if line_prefix.nil?
      s = ""
      s << line_prefix
      
      if name == "content" && namespace.empty?
        skip_value_space = true
      else
        skip_value_space = false
        s << "#{namespace}:" unless namespace.empty?
        s << name
      end

      # output values
      values do |value|
        if skip_value_space
          skip_value_space = false
        else
          s << " "
        end
        s << SDL4R.format(value, true, line_prefix, indent)
      end

      # output attributes
      unless @attributesByNamespace.empty?
        all_attributes_hash = attributes
        all_attributes_array = all_attributes_hash.sort { |a, b|
          namespace1, name1 = a[0].split(':')
          namespace1, name1 = "", namespace1 if name1.nil?
          namespace2, name2 = b[0].split(':')
          namespace2, name2 = "", namespace2 if name2.nil?

          diff = namespace1 <=> namespace2
          diff == 0 ? name1 <=> name2 : diff
        }
        all_attributes_array.each do |attribute_name, attribute_value|
          s << " " << attribute_name << '=' << SDL4R.format(attribute_value, true)
        end
      end

      # output children
      unless @children.empty?
        s << " {#{$/}"
        children_to_string(line_prefix + indent, s)
        s << line_prefix << ?}
      end

      return s
    end

    # Returns a string representation of the children tags.
    #
    # _linePrefix_:: A prefix to insert before every line.
    # _s_:: a String that receives the string representation
    #
    # TODO: break up long lines using the backslash
    #
    def children_to_string(line_prefix = "", s = "")
      @children.each do |child|
        s << child.to_string(line_prefix) << $/
      end
      
      return s
    end
    
    # Returns true if this tag (including all of its values, attributes, and
    # children) is equivalent to the given tag.
    # 
    # Returns true if the tags are equivalet
    #
    def eql?(o)
      # this is safe because to_string() dumps the full state
      return o.is_a?(Tag) && o.to_string == to_string;
    end
    alias_method :==, :eql?
  
    # Returns The hash (based on the output from toString())
    #
    def hash
      return to_string.hash
    end
    
    # Returns a string containing an XML representation of this tag.  Values
    # will be represented using _val0, _val1, etc.
    #
    # _options_:: a hash of the options
    #
    # === options:
    #
    # [:line_prefix] a text prefixing each line (default: "")
    # [:uri_by_namespace] a Hash giving the URIs for the namespaces
    # [:indent] text specifying one indentation (default: "\t")
    # [:eol] end of line expression (default: "\n")
    # [:omit_null_attributes]
    #   if true, null/nil attributes are not exported (default: false). Otherwise, they are exported
    #   as follows:
    #     tag attr="null"
    #
    def to_xml_string(options = {})
      options = {
        :uri_by_namespace => nil,
        :indent => "\t",
        :line_prefix => "",
        :eol => "\n",
        :omit_null_attributes => false
      }.merge(options)
      _to_xml_string(options[:line_prefix], options)
    end

    protected

    # Implementation of #to_xml_string but without the extra-treatment on parameters for default
    # values.
    def _to_xml_string(line_prefix, options)
      eol = options[:eol]

      s = ""
      s << line_prefix << ?<
      s << "#{namespace}:" unless namespace.empty?
      s << name

      # output namespace declarations
      uri_by_namespace = options[:uri_by_namespace]
      if uri_by_namespace
        uri_by_namespace.each_pair do |namespace, uri|
          if namespace
            s << " xmlns:#{namespace}=\"#{uri}\""
          else
            s << " xmlns=\"#{uri}\""
          end
        end
      end
      
      # output values
      unless @values.empty?
        i = 0
        @values.each do |value|
          s << " _val" << i.to_s << "=\"" << SDL4R.format(value, false) << "\""
          i += 1
        end
      end
      
      # output attributes
      if has_attribute?
        omit_null_attributes = options[:omit_null_attributes]
        attributes do |attribute_namespace, attribute_name, attribute_value|
          unless omit_null_attributes and attribute_value.nil?
            s << " "
            s << "#{attribute_namespace}:" unless attribute_namespace.empty?
            s << attribute_name << "=\"" << SDL4R.format(attribute_value, false) << ?"
          end
        end
      end
  
      if @children.empty?
        s << "/>"
      else
        s << ">" << eol
        @children.each do |child|
          s << child._to_xml_string(line_prefix + options[:indent], options) << eol
        end
        
        s << line_prefix << "</"
        s << "#{namespace}:" unless namespace.empty?
        s << name << ?>
      end
  
      return s
    end
  end
end