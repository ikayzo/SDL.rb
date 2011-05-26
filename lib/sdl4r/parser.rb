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

  require 'base64'

  require File.dirname(__FILE__) + '/sdl_binary'
  require File.dirname(__FILE__) + '/sdl_time_span'
  require File.dirname(__FILE__) + '/sdl_parse_error'
  require File.dirname(__FILE__) + '/parser/tokenizer'

  # The SDL parser.
  #
  # In Ruby 1.8, in order to enable UTF-8 support, you may have to declare the following lines:
  #
  #   $KCODE = 'u'
  #   require 'jcode'
  #
  # This will give you correct input and output and correct UTF-8 "general" sorting.
  # Alternatively you can use the following options when launching the Ruby interpreter:
  #
  #   /path/to/ruby -Ku -rjcode
  #
  # == Authors
  # Daniel Leuck, Philippe Vosges
  #
  class Parser
			
    # Passed to parse_error() in order to specify an error that occured on no specific position
    # (column).
    UNKNOWN_POSITION = -2
	 	
    # Creates an SDL parser on the specified +IO+.
    #
    #   IO.open("path/to/sdl_file") { |io|
    #     parser = SDL4R::Parser.new(io)
    #     tags = parser.parse()
    #   }
    #
    def initialize(io)
      raise ArgumentError, "io == nil" if io.nil?
			
      @tokenizer = Tokenizer.new(io)
    end
		
    # Parses the underlying +IO+ and returns an +Array+ of +Tag+.
    # 
    # ==Errors
    # [IOError] If a problem is encountered with the IO
    # [SdlParseError] If the document is malformed
    def parse
      tags = []
			
      while tokens = @tokenizer.read_line_tokens()
        if tokens.last.type == :START_BLOCK
          # tag with a block
          tag = construct_tag(tokens[0...-1])
          add_children(tag)
          tags << tag

        elsif tokens.first.type == :END_BLOCK
          # we found an block end token that should have been consumed by
          # add_children() normally
          parse_error(
            "No opening block ({) for close block (}).",
            tokens.first.line,
            tokens.first.position)
        else
          # tag without block
          tags << construct_tag(tokens)
        end
      end
			
      @tokenizer.close()
			
      return tags
    end

    # Creates and returns the object representing a datetime (DateTime in the default
    # implementation). Can be overriden.
    #
    #   def new_date_time(year, month, day, hour, min, sec, time_zone_offset)
    #     Time.utc(year, month, day, hour, min, sec)
    #   end
    #
    def new_date_time(year, month, day, hour, min, sec, time_zone_offset)
      SDL4R::new_date_time(year, month, day, hour, min, sec, time_zone_offset)
    end
		
    private
		
    # Parses the children tags of +parent+ until an end of block is found.
    def add_children(parent)
      while tokens = @tokenizer.read_line_tokens()
        if tokens.first.type == :END_BLOCK
          return
					
        elsif tokens.last.type == :START_BLOCK
          # found a child with a block
          tag = construct_tag(tokens[0...-1]);
          add_children(tag)
          parent.add_child(tag)
					
        else
          parent.add_child(construct_tag(tokens))
        end
      end
			
      parse_error("No close block (}).", @tokenizer.line_no, UNKNOWN_POSITION)
    end
		
    # Construct a Tag (but not its children) from a string of tokens
    # 
    # Throws SdlParseError if some bad syntax is found.
    def construct_tag(tokens)
      raise ArgumentError, "tokens == nil" if tokens.nil?
      if tokens.empty?
        parse_error("Internal Error: empty token list", @tokenizer.line_no, UNKNOWN_POSITION)
      end
			
      first_token = tokens.first
      if first_token.literal?
        first_token = Token.new("content")
        tokens.insert(0, first_token)
				
      elsif first_token.type != :IDENTIFIER
        expecting_but_got(
          "IDENTIFIER",
          "#{first_token.type} (#{first_token.text})",
          first_token.line,
          first_token.position)
      end
			
      tag = nil
      if tokens.size == 1
        tag = Tag.new(first_token.text)
				
      else
        values_start_index = 1
        second_token = tokens[1]
				
        if second_token.type == :COLON
          if tokens.size == 2 or tokens[2].type != :IDENTIFIER
            parse_error(
              "Colon (:) encountered in unexpected location.",
              second_token.line,
              second_token.position)
          end
					
          third_token = tokens[2];
          tag = Tag.new(first_token.text, third_token.text)
          values_start_index = 3
					
        else
          tag = Tag.new(first_token.text)
        end
				
        # read values
        attribute_start_index = add_tag_values(tag, tokens, values_start_index)
				
        # read attributes
        if attribute_start_index < tokens.size
          add_tag_attributes(tag, tokens, attribute_start_index)
        end
      end
			
      return tag
    end
		
    #
    # @return The position at the end of the value list
    #
    def add_tag_values(tag, tokens, start)
      size = tokens.size()
      i = start;
			
      while i < size
        token = tokens[i]
				
        if token.literal?
          # if a DATE token is followed by a TIME token combine them
          next_token = ((i + 1) < size)? tokens[i + 1] : nil
          if token.type == :DATE && next_token && next_token.type == :TIME
            date = token.object_for_literal()
            time_zone_with_zone = next_token.object_for_literal()
						
            if time_zone_with_zone.day != 0
              # as there are days specified, it can't be a full precision date
              tag.add_value(date);
              tag.add_value(
                SdlTimeSpan.new(
                  time_zone_with_zone.day,
                  time_zone_with_zone.hour,
                  time_zone_with_zone.min,
                  time_zone_with_zone.sec))
							
							
              if time_zone_with_zone.time_zone_offset
                parse_error("TimeSpan cannot have a timeZone", t.line, t.position)
              end
							
            else
              tag.add_value(combine(date, time_zone_with_zone))
            end
						
            i += 1
						
          else
            value = token.object_for_literal()
            if value.is_a?(TimeSpanWithZone)
              # the literal looks like a time zone
              if value.time_zone_offset
                expecting_but_got(
                  "TIME SPAN",
                  "TIME (component of date/time)",
                  token.line,
                  token.position)
              end
							
              tag.add_value(
                SdlTimeSpan.new(
                  value.day,
                  value.hour,
                  value.min,
                  value.sec))
            else
              tag.add_value(value)
            end
          end
        elsif token.type == :IDENTIFIER
          break
        else
          expecting_but_got(
            "LITERAL or IDENTIFIER", token.type, token.line, token.position)
        end
				
        i += 1
      end
			
      return i
    end
		
    #
    # Add attributes to the given tag
    #
    def add_tag_attributes(tag, tokens, start)
      i = start
      size = tokens.size
			
      while i < size
        token = tokens[i]
        if token.type != :IDENTIFIER
          expecting_but_got("IDENTIFIER", token.type, token.line, token.position)
        end
        name_or_namespace = token.text;
				
        if i == (size - 1)
          expecting_but_got(
            "\":\" or \"=\" \"LITERAL\"",
            "END OF LINE.",
            token.line,
            token.position)
        end
				
        i += 1
        token = tokens[i]
        if token.type == :COLON
          if i == (size - 1)
            expecting_but_got(
              "IDENTIFIER", "END OF LINE", token.line, token.position)
          end
					
          i += 1
          token = tokens[i]
          if token.type != :IDENTIFIER
            expecting_but_got(
              "IDENTIFIER", token.type, token.line, token.position)
          end
          name = token.text
					
          if i == (size - 1)
            expecting_but_got("\"=\"", "END OF LINE", token.line, token.position)
          end
					
          i += 1
          token = tokens[i]
          if token.type != :EQUALS
            expecting_but_got("\"=\"", token.type, token.line, token.position)
          end
					
          if i == (size - 1)
            expecting_but_got("LITERAL", "END OF LINE", token.line, token.position)
          end
					
          i += 1
          token = tokens[i]
          if !token.literal?
            expecting_but_got("LITERAL", token.type, token.line, token.position)
          end
					
          if token.type == :DATE and (i + 1) < size and tokens[i + 1].type == :TIME
            date = token.get_object_for_literal()
            time_span_with_zone = tokens[i + 1].get_object_for_literal()
						
            if time_span_with_zone.days != 0
              expecting_but_got(
                "TIME (component of date/time) in attribute value",
                "TIME SPAN",
                token.line,
                token.position)
            else
              tag.set_attribute(name_or_namespace, name, combine(date, time_span_with_zone))
            end
						
            i += 1
          else
            value = token.object_for_literal();
            if value.is_a?(TimeSpanWithZone)
              time_span_with_zone = value
							
              if time_span_with_zone.time_zone_offset
                expecting_but_got(
                  "TIME SPAN",
                  "TIME (component of date/time)",
                  token.line,
                  token.position)
              end
							
              time_span = SdlTimeSpan.new(
                time_span_with_zone.day,
                time_span_with_zone.hour,
                time_span_with_zone.min,
                time_span_with_zone.sec)
							
              tag.set_attribute(name_or_namespace, name, time_span)
            else
              tag.set_attribute(name_or_namespace, name, value);
            end
          end
        elsif token.type == :EQUALS
          if i == (size - 1)
            expecting_but_got("LITERAL", "END OF LINE", token.line, token.position)
          end
					
          i += 1
          token = tokens[i]
          if !token.literal?
            expecting_but_got("LITERAL", token.type, token.line, token.position)
          end
					
          if token.type == :DATE and (i + 1) < size and tokens[i + 1].type == :TIME
            date = token.object_for_literal()
            time_span_with_zone = tokens[i + 1].object_for_literal()
						
            if time_span_with_zone.day != 0
              expecting_but_got(
                "TIME (component of date/time) in attribute value",
                "TIME SPAN",
                token.line,
                token.position)
            end
            tag.set_attribute(name_or_namespace, combine(date, time_span_with_zone))
						
            i += 1
          else
            value = token.object_for_literal()
            if value.is_a?(TimeSpanWithZone)
              time_span_with_zone = value
              if time_span_with_zone.time_zone_offset
                expecting_but_got(
                  "TIME SPAN",
                  "TIME (component of date/time)",
                  token.line,
                  token.position)
              end
							
              time_span = SdlTimeSpan.new(
                time_span_with_zone.day,
                time_span_with_zone.hour,
                time_span_with_zone.min,
                time_span_with_zone.sec)
              tag.set_attribute(name_or_namespace, time_span)
            else
              tag.set_attribute(name_or_namespace, value);
            end			
          end
        else
          expecting_but_got(
            "\":\" or \"=\"", token.type, token.line, token.position)
        end
				
        i += 1
      end
    end
		
    # Combines a simple Date with a TimeSpanWithZone to create a DateTime
    #
    def combine(date, time_span_with_zone)
      time_zone_offset = time_span_with_zone.time_zone_offset
      time_zone_offset = TimeSpanWithZone.default_time_zone_offset if time_zone_offset.nil?
			
      new_date_time(
        date.year,
        date.month,
        date.day,
        time_span_with_zone.hour,
        time_span_with_zone.min,
        time_span_with_zone.sec,
        time_zone_offset)
    end
		
    private
    ############################################################################
    ## Parsers for types
    ############################################################################
		
    def Parser.parse_string(literal)
      unless literal =~ /(^`.*`$)|(^\".*\"$)/m
        raise ArgumentError,
          "Malformed string <#{literal}>." +
          "	Strings must start and end with \" or `"
      end
			
      return literal[1..-2]
    end
		
    def Parser.parse_character(literal)
      unless literal =~ /(^'.*'$)/
        raise ArgumentError,
          "Malformed character <#{literal}>." +
          "	Character must start and end with single quotes"
      end
			
      return literal[1]
    end
		
    def Parser.parse_number(literal)
      # we use the fact that Kernel.Integer() and Kernel.Float() raise ArgumentErrors
      if literal =~ /(.*)(L)$/i
        return Integer($1)
      elsif literal =~ /([^BDF]*)(BD)$/i
        return BigDecimal($1)
      elsif literal =~ /([^BDF]*)(F|D)$/i
        return Float($1)
      elsif literal.count(".e") == 0
        return Integer(literal)
      else
        return Float(literal)
      end
    end
		
    # Parses the given literal into a returned array
    # [days, hours, minutes, seconds, time_zone_offset].
    # 'days', 'hours' and 'minutes' are integers.
    # 'seconds' and 'time_zone_offset' are rational numbers.
    # 'days' and 'seconds' are equal to 0 if they're not specified in ((|literal|)).
    # 'time_zone_offset' is equal to nil if not specified.
    #
    # ((|allowDays|)) indicates whether the specification of days is allowed
    # in ((|literal|))
    # ((|allowTimeZone|)) indicates whether the specification of the timeZone is
    # allowed in ((|literal|))
    #
    # All components are returned disregarding the values of ((|allowDays|)) and
    # ((|allowTimeZone|)).
    #
    # Raises an ArgumentError if ((|literal|)) has a bad format.
    def Parser.parse_time_span_and_time_zone(literal, allowDays, allowTimeZone)
      overall_sign = (literal =~ /^-/)? -1 : +1

      if literal =~ /^(([+\-]?\d+)d:)/
        if allowDays
          days = Integer($2)
          days_specified = true
          time_part = literal[($1.length)..-1]
        else
          # detected a day specification in a pure time literal
          raise ArgumentError, "unexpected day specification in #{literal}"
        end
      else
        days = 0;
        days_specified = false
        time_part = literal
      end
			
      # We have to parse the string ourselves because AFAIK :
      #	- strptime() can't parse milliseconds
      #	- strptime() can't parse the time zone custom offset (CET+02:30)
      #	- strptime() accepts trailing chars
      #		(e.g. "12:24-xyz@" ==> "xyz@" is obviously wrong but strptime()
      #		 won't mind)
      if time_part =~ /^([+-]?\d+):(\d+)(?::(\d+)(?:\.(\d+))?)?(?:(?:-([a-zA-Z]+))?(?:([\+\-]\d+)(?::(\d+))?)?)?$/i
        hours = $1.to_i
        minutes = $2.to_i
        # seconds and milliseconds are implemented as one rational number
        # unless there are no milliseconds
        millisecond_part = ($4)? $4.ljust(3, "0") : nil
        if millisecond_part
          seconds = Rational(($3 + millisecond_part).to_i, 10 ** millisecond_part.length)
        else
          seconds = ($3)? Integer($3) : 0
        end
				
        if ($5 or $6) and not allowTimeZone
          raise ArgumentError, "unexpected time zone specification in #{literal}"
        end
				
        time_zone_code = $5 # might be nil

        if $6
          zone_custom_minute_offset = $6.to_i * 60
          if $7
            if zone_custom_minute_offset > 0
              zone_custom_minute_offset = zone_custom_minute_offset + $7.to_i
            else
              zone_custom_minute_offset = zone_custom_minute_offset - $7.to_i
            end
          end
        end

        time_zone_offset = get_time_zone_offset(time_zone_code, zone_custom_minute_offset)
				
        if not allowDays and $1 =~ /^[+-]/
          # unexpected timeSpan syntax
          raise ArgumentError, "unexpected sign on hours : #{literal}"
        end

        # take the sign into account
        hours *= overall_sign if days_specified # otherwise the sign is already applied to the hours
        minutes *= overall_sign
        seconds *= overall_sign
				
        return [ days, hours, minutes, seconds, time_zone_offset ]
				
      else
        raise ArgumentError, "bad time component : #{literal}"
      end
    end
		
    # Parses the given literal (String) into a returned DateTime object.
    #
    # Raises an ArgumentError if ((|literal|)) has a bad format.
    def Parser.parse_date_time(literal)
      raise ArgumentError("date literal is nil") if literal.nil?
			
      begin
        parts = literal.split(" ")
        if parts.length == 1
          return parse_date(literal)
        else
          date = parse_date(parts[0]);
          time_part = parts[1]
					
          days, hours, minutes, seconds, time_zone_offset =
            parse_time_span_and_time_zone(time_part, false, true)
					
          return new_date_time(
            date.year, date.month, date.day, hours, minutes, seconds, time_zone_offset)
        end
				
      rescue ArgumentError
        raise ArgumentError, "Bad date/time #{literal} : #{$!.message}"
      end
    end

    ##
    # Returns the time zone offset (Rational) corresponding to the provided parameters as a fraction
    # of a day. This method adds the two offsets if they are both provided.
    # 
    # +time_zone_code+: can be nil
    # +custom_minute_offset+: can be nil
    #
    def Parser.get_time_zone_offset(time_zone_code, custom_minute_offset)
      return nil unless time_zone_code or custom_minute_offset

      time_zone_offset = custom_minute_offset ? Rational(custom_minute_offset, 60 * 24) : 0
      
      return time_zone_offset unless time_zone_code
			
      # we have to provide some bogus year/month/day in order to parse our time zone code
      d = DateTime.strptime("1999/01/01 #{time_zone_code}", "%Y/%m/%d %Z")
      # the offset is a fraction of a day
      return d.offset() + time_zone_offset
    end
		
    # Parses the +literal+ into a returned Date object.
    #
    # Raises an ArgumentError if +literal+ has a bad format.
    
    def Parser.parse_date(literal)
      # here, we're being stricter than strptime() alone as we forbid trailing chars
      if literal =~ /^(\d+)\/(\d+)\/(\d+)$/
        begin
          return Date.strptime(literal, "%Y/%m/%d")
        rescue ArgumentError
          raise ArgumentError, "Malformed Date <#{literal}> : #{$!.message}"
        end
      end

      raise ArgumentError, "Malformed Date <#{literal}>"
    end
		
    # Returns a String that contains the binary content corresponding to ((|literal|)).
    #
    # ((|literal|)) : a base-64 encoded literal (e.g.
    # "[V2hvIHdhbnRzIHRvIGxpdmUgZm9yZXZlcj8=]")
    def Parser.parse_binary(literal)
      clean_literal = literal[1..-2] # remove square brackets
      return SdlBinary.decode64(clean_literal)
    end
		
    # Parses +literal+ (String) into the corresponding SDLTimeSpan, which is then
    # returned.
    #
    # Raises an ArgumentError if the literal is not a correct timeSpan literal.
    def Parser.parse_time_span(literal)
      days, hours, minutes, seconds, time_zone_offset =
        parse_time_span_and_time_zone(literal, true, false)
			
      milliseconds = ((seconds - seconds.to_i) * 1000).to_i
      seconds = seconds.to_i
			
      return SDLTimeSpan.new(days, hours, minutes, seconds, milliseconds)
    end

    # Close the reader and throw a SdlParseError using the format
    # Was expecting X but got Y.
    #
    def expecting_but_got(expecting, got, line, position)
      @tokenizer.expecting_but_got(expecting, got, line, position)
    end
  end
end
