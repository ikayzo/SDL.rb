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

require 'base64'
require 'bigdecimal'
require 'date'

# Gathers utility methods.
# 
module SDL4R
  
  MAX_INTEGER_32 = 2**31 - 1
  MIN_INTEGER_32 = -(2**31)
  
  MAX_INTEGER_64 = 2**63 - 1
  MIN_INTEGER_64 = -(2**63)

  BASE64_WRAP_LINE_LENGTH = 72

  # Creates an SDL string representation for a given object and returns it.
  # 
  # +o+:: the object to format
  # +add_quotes+:: indicates whether quotes will be added to Strings and characters (true by default)
  # +line_prefix+:: the line prefix to use ("" by default)
  # +indent+:: the indent string to use ("\t" by default)
  #
  def self.format(o, add_quotes = true, line_prefix = "", indent = "\t")
    if o.is_a?(String)
      if add_quotes
        o_length = 0
        o.scan(/./m) { o_length += 1 } # counts the number of chars (as opposed of bytes)
        if o_length == 1
          return "'" + escape(o, "'") + "'"
        else
          return '"' + escape(o, '"') + '"'
        end
      else
        return escape(o)
      end
      
    elsif o.is_a?(Bignum)
      return o.to_s + "BD"
      
    elsif o.is_a?(Integer)
      if MIN_INTEGER_32 <= o and o <= MAX_INTEGER_32
        return o.to_s
      elsif MIN_INTEGER_64 <= o and o <= MAX_INTEGER_64
        return o.to_s + "L"
      else
        return o.to_s + "BD"
      end
      
    elsif o.is_a?(Float)
      return (o.to_s + "F")
      
    elsif o.is_a?(Rational)
      return o.to_f.to_s + "F"

    elsif o.is_a?(BigDecimal)
      s = o.to_s('F')
      s.sub!(/\.0$/, "")
      return "#{s}BD"

    elsif o.nil?
      return "null"

    elsif o.is_a?(SdlBinary)
      encoded_o = Base64.encode64(o.bytes)
      encoded_o.gsub!(/[\r\n]/m, "") # Remove the EOL inserted every 60 chars

      if add_quotes
        if encoded_o.length > BASE64_WRAP_LINE_LENGTH
          # FIXME: we should a constant or some parameter instead of hardcoded spaces
          wrap_lines_in_ascii(encoded_o, BASE64_WRAP_LINE_LENGTH, "#{line_prefix}#{indent}")
          encoded_o.insert(0, "[#{$/}")
          encoded_o << "#{$/}#{line_prefix}]"
        else
          encoded_o.insert(0, "[")
          encoded_o << "]"
        end
      end

      return encoded_o
      
    # Below, we use "#{o.year}" instead of "%Y" because "%Y" always emit 4 chars at least even if
    # the date is before 1000.
    elsif o.is_a?(DateTime) || o.is_a?(Time)
      milliseconds = get_datetime_milliseconds(o)

      if milliseconds == 0
        if o.zone
          return o.strftime("#{o.year}/%m/%d %H:%M:%S%Z")
        else
          return o.strftime("#{o.year}/%m/%d %H:%M:%S")
        end
      else
        if o.zone
          return o.strftime("#{o.year}/%m/%d %H:%M:%S." + milliseconds.to_s.ljust(3, '0') + "%Z")
        else
          return o.strftime("#{o.year}/%m/%d %H:%M:%S." + milliseconds.to_s.ljust(3, '0'))
        end
      end

    elsif o.is_a?(Date)
      return o.strftime("#{o.year}/%m/%d")
      
    else
      return o.to_s
    end
  end

  # Creates and returns the object representing a datetime (DateTime in the default implementation).
  # This method is, by default, called by the Parser class.
  # It could be overriden as follows in order to get Time instances from all the SDL4R parsers.
  #
  #   module SDL4R
  #     def self.new_date_time(year, month, day, hour, min, sec, time_zone_offset)
  #       Time.utc(year, month, day, hour, min, sec)
  #     end
  #   end
  #
  def self.new_date_time(year, month, day, hour, min, sec, time_zone_offset)
    DateTime.civil(year, month, day, hour, min, sec, time_zone_offset)
  end
    
  # Coerce the type to a standard SDL type or raises an ArgumentError.
  #
  # Returns +o+ if of the following classes:
  # NilClass, String, Numeric, Float, TrueClass, FalseClass, Date, DateTime, Time,
  # SdlTimeSpan, SdlBinary,
  #
  # Rationals are turned into Floats using Rational#to_f.
  #
  def self.coerce_or_fail(o)
    case o

    when Rational
      return o.to_f

    when NilClass,
        String,
        Numeric,
        Float,
        TrueClass,
        FalseClass,
        Date,
        DateTime,
        Time,
        SdlTimeSpan,
        SdlBinary
      return o

    end

    raise ArgumentError, "#{o.class.name} is not coercible to an SDL type"
  end
  
  # Validates an SDL identifier String.  SDL Identifiers must start with a
  # Unicode letter or underscore (_) and contain only unicode letters,
  # digits, underscores (_), dashes(-) and periods (.).
  # 
  # == Raises
  # ArgumentError if the identifier is not legal
  #
  # TODO: support UTF-8 identifiers
  #
  def self.validate_identifier(identifier)
    if identifier.nil? or identifier.empty?
      raise ArgumentError, "SDL identifiers cannot be null or empty."
    end

    # in Java, was if(!Character.isJavaIdentifierStart(identifier.charAt(0)))
    unless identifier =~ /^[a-zA-Z_]/
      raise ArgumentError,
        "'" + identifier[0..0] +
        "' is not a legal first character for an SDL identifier. " +
        "SDL Identifiers must start with a unicode letter or " +
        "an underscore (_)."
    end
    
    unless identifier.length == 1 or identifier =~ /^[a-zA-Z_][a-zA-Z_0-9\-\.]*$/
      for i in 1..identifier.length
        unless identifier[i..i] =~ /^[a-zA-Z_0-9\-]$/
          raise ArgumentError,
            "'" + identifier[i..i] + 
            "' is not a legal character for an SDL identifier. " +
            "SDL Identifiers must start with a unicode letter or " +
            "underscore (_) followed by 0 or more unicode " +
            "letters, digits, underscores (_), or dashes (-)"
        end
      end
    end
  end

  # Creates and returns a tag named "root" and add all the tags specified in the given +input+.
  #
  # +input+:: String, IO, Pathname or URI.
  #
  #   root = SDL4R::read(<<EOF
  #   planets {
  #     earth area_km2=510900000
  #     mars
  #   }
  #   EOF
  #   )
  #
  #   root = SDL4R::read(Pathname.new("my_dir/my_file.sdl"))
  #
  #   IO.open("my_dir/my_file.sdl", "r") { |io|
  #     root = SDL4R::read(io)
  #   }
  #   
  #   root = SDL4R::read(URI.new("http://my_site/my_file.sdl"))
  #
  def self.read(input)
    Tag.new("root").read(input)
  end

  # Parses and returns the value corresponding with the specified SDL literal.
  #
  #   SDL4R.to_value("\"abcd\"") # => "abcd"
  #   SDL4R.to_value("1") # => 1
  #   SDL4R.to_value("null") # => nil
  #
  def self.to_value(s)
    raise ArgumentError, "'s' cannot be null" if s.nil?
    return read(s).child.value
  end

  # Parse the string of values and return a list.  The string is handled
  # as if it is the values portion of an SDL tag.
	#
	# Example
	#
	#   array = SDL4R.to_value_array("1 true 12:24:01")
	#
	# Will return an int, a boolean, and a time span.
	#
  def self.to_value_array(s)
    raise ArgumentError, "'s' cannot be null" if s.nil?
    return read(s).child.values
  end

	# Parse a string representing the attributes portion of an SDL tag
	# and return the results as a map.
	#
	# Example
	# 
	#   hash = SDL4R.to_attribute_hash("value=1 debugging=on time=12:24:01");
	#
	#   # { "value" => 1, "debugging" => true, "time" => SdlTimeSpan.new(12, 24, 01) }
	#
  def self.to_attribute_map(s)
    raise ArgumentError, "'s' cannot be null" if s.nil?
    return read("atts " + s).child.attributes
  end

  # The following is a not so readable way to implement module private methods in Ruby: we add
  # private methods to the singleton class of +self+ i.e. the SDL4R module.
  class << self
    private

    # Wraps lines in "s" (by modifying it). This method only supports 1-byte character strings.
    #
    def wrap_lines_in_ascii(s, line_length, line_prefix = nil)
      # We could use such code if it supported any value for "line_prefix": unfortunately it is capped
      # at 64 in the regular expressions.
      #
      # return "#{line_prefix}" + encoded_o.scan(/.{1,#{line_prefix}}/).join("#{$/}#{line_prefix}")

      eol_size = "#{$/}".size

      i = 0
      while i < s.size
        if i > 0
          s.insert(i, $/)
          i += eol_size
        end

        if line_prefix
          s.insert(i, line_prefix)
          i += line_prefix.size
        end

        i += line_length
      end
    end

    ESCAPED_QUOTES = {
      "\"" => "\\\"",
      "'" => "\\'",
      "`" => "\\`",
    }

    ESCAPED_CHARS = {
      "\\" => "\\\\",
      "\t" => "\\t",
      "\r" => "\\r",
      "\n" => "\\n",
    }
    ESCAPED_CHARS.merge!(ESCAPED_QUOTES)

    # Returns an escaped version of +s+ (i.e. where characters which need to be
    # escaped, are escaped).
    #
    def escape(s, quote_char = nil)
      escaped_s = ""

      s.each_char { |c|
        escaped_char = ESCAPED_CHARS[c]
        if escaped_char
          if ESCAPED_QUOTES.has_key?(c)
            if quote_char && c == quote_char
              escaped_s << escaped_char
            else
              escaped_s << c
            end
          else
              escaped_s << escaped_char
          end
        else
          escaped_s << c
        end
      }

      return escaped_s
    end

    # Returns the microseconds component of the given DateTime or Time.
    # DateTime and Time having vastly different behaviors between themselves or in Ruby 1.8 and 1.9,
    # this method makes an attemps at getting this component out of the specified object.
    # 
    # In particular, DateTime.sec_fraction() (which I used before) returns incorrect values in, at
    # least, some revisions of Ruby 1.9.
    #
    def get_datetime_milliseconds(datetime)
      if defined?(datetime.usec)
        return (datetime.usec / 1000).round
      else
        # Here don't believe that we could use '%3N' to get the milliseconds directly: the "3" is
        # ignored for DateTime.strftime() in Ruby 1.8.
        nanoseconds = Integer(datetime.strftime("%N"))
        return (nanoseconds / 1000000).round
      end
    end

  end

end