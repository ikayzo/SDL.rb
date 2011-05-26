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

  require File.dirname(__FILE__) + '/reader'
  require File.dirname(__FILE__) + '/token'

  class Parser

    # Tokenizer of the SDL parser
    class Tokenizer # :nodoc: all

      TOKEN_TYPES = [
        :IDENTIFIER,

        # punctuation
        :COLON, :SEMICOLON, :EQUALS, :START_BLOCK, :END_BLOCK,

        # literals
        :STRING, :CHARACTER, :BOOLEAN, :NUMBER, :DATE, :TIME, :BINARY, :NULL ]


      # Creates an SDL tokenizer on the specified +IO+.
      def initialize(io)
        raise ArgumentError, "io == nil" if io.nil?

        @reader = Parser::Reader.new(io)
        @token_start = 0
        @starting_escaped_quote_line = false
        @tokens = nil
        @token_text = nil
      end

      # Closes this Tokenizer and its underlying +Reader+.
      def close
        @reader.close
      end

      # Raises a SdlParseError.
      def parse_error(description, line_no = nil, position = nil)
        line_no = @reader.line_no unless line_no
        position = @reader.pos - 1 unless position # @reader.pos points to the *next* position

        # We add one because editors typically start with line 1 rather than 0...
        raise SdlParseError.new(description, line_no + 1, position + 1, @reader.line)
      end

      # Close the reader and throw a SdlParseError using the format
      # Was expecting X but got Y.
      #
      def expecting_but_got(expecting, got, line, position)
        parse_error("Was expecting #{expecting} but got #{got}", line, position)
      end

      # Returns the next line as tokens or nil if the end of the stream has been reached.
      # This method handles line continuations both within and outside String literals.
      # The line of tokens is assigned to @tokens.
      #
      # Returns a logical line as a list of Tokens.
      #
      def read_line_tokens
        begin
          read_line_tokens_even_if_empty()
        end until @tokens.nil? or !@tokens.empty?
        return @tokens
      end

      def line_no
        @reader.line_no
      end

      def pos
        @reader.pos
      end

      def line
        @reader.line
      end

      private

      # Returns the next line as tokens or nil if the end of the stream has been reached.
      # This method handles line continuations both within and outside String literals.
      # The line of tokens is assigned to @tokens.
      #
      # Returns a logical line as a list of Tokens.
      # Returns an empty array if the line was empty.
      # Returns +nil+ if the end of the stream has been reached.
      #
      def read_line_tokens_even_if_empty
        # Reset of the token-related fields
        @tokens = nil
        @token_text = nil
        @token_start = nil

        if @reader.eol? and not @reader.read_line()
          return nil
        end

        @tokens = []
        @token_start = @reader.pos

        until @reader.eol?
          if @token_text
            @tokens << Token.new(@token_text, @reader.line_no, @token_start)
            @token_text = nil
            @token_start = @reader.pos
          end

          c = @reader.current_char
          next_c = @reader.get_line_char(@reader.pos + 1)
          
          case c
          when "\""
            # handle "" style strings including line continuations
            handle_double_quote_string()

          when "'"
            handle_character_literal()

          when "{", "}", "=", ":", ";"
            # handle punctuation
            punctuation_token = Token.new(c, @reader.line_no, @reader.pos)
            @token_text = nil

            if punctuation_token.type == :SEMICOLON
              @reader.skip_char()
              break
            else
              @tokens << punctuation_token
            end

          when "#"
            # skip : hash comment at end of line
            @reader.skip_to_eol()

          when "/"
            # handle // and /**/ style comments
            if next_c == "/"
              # skip : // comment
              @reader.skip_to_eol()
            else
              handle_slash_comment()
            end

          when "`"
            # handle multiline `` style strings
            handle_back_quote_string()

          when "["
            # handle binary literals
            handle_binary_literal()

          when "\s", "\t"
            @reader.skip_whitespaces()

          when "\\"
            # line continuations (outside a string literal)
            handle_line_continuation()
            next # otherwise 1st char of the continuation line is skipped by skip_char()

          when /^[0-9\-\.]$/
            if c == "-" and next_c == "-"
              # -- comments : ignore
              @reader.skip_to_eol()
            else
              # handle numbers, dates, and time spans
              handle_number_date_or_time_span()
            end

          when /^[a-zA-Z\$_]$/
            # FIXME Here, the Java code specifies isJavaIdentifierStart() but
            # this is not easily implemented (at least as of Ruby 1.8).
            # So, we implement a subset of these characters.
            handle_identifier()

          when "\n", "\r" # end of line
            @reader.skip_to_eol()

          else
            parse_error("Unexpected character '#{c}'")
          end

          @reader.skip_char()
        end

        if @token_text
          @tokens << Token.new(@token_text, @reader.line_no, @token_start)
        end

        return @tokens
      end

      # Adds the current escaped character (represented by ((|c|))) to @token_text.
      # This method assumes the previous char was a backslash.
      #
      def add_escaped_char_in_string(c)
        case c
        when "\\", "\""
          @token_text << c
        when "n"
          @token_text << ?\n
        when "r"
          @token_text << ?\r
        when "t"
          @token_text << ?\t
        else
          parse_error("Illegal escape character in string literal: '#{c}'.")
        end
      end

      def handle_double_quote_string
        escaped = false
        @starting_escaped_quote_line = false

        @token_text = @reader.read_char()

        until @reader.eol?
          c = @reader.current_char

          if "\s\t".include?(c) and @starting_escaped_quote_line
            # skip the heading spaces (indentation) of a continued line
          else
            @starting_escaped_quote_line = false

            if escaped
              add_escaped_char_in_string(c)
              escaped = false

            elsif c == "\\"
              # check for String broken across lines
              if @reader.rest_of_line =~ /^\\\s*$/
                handle_escaped_double_quoted_string()
                next # as we are at the beginning of a new line
              else
                escaped = true
              end

            else
              @token_text << c
              if c == '"'
                # end of double-quoted string detected
                @tokens << Token.new(@token_text, @reader.line_no, @token_start)
                @token_text = nil
                return
              end
            end
          end

          @reader.skip_char()
        end

        # detection of ill-terminated literals
        if @token_text =~ /^".*[^"]$/
          parse_error(
            "String literal \"#{@token_text}\" not terminated by end quote.",
            @reader.line_no,
            @reader.line_length)
        else#if @token_text == '"'
          parse_error("Orphan quote (unterminated string)", @reader.line_no, @reader.line_length)
        end
puts "end of chars"
      end

      def handle_escaped_double_quoted_string
        # '\' can be followed by whitespaces
        if @reader.rest_of_line =~ /^\\\s*$/
          @reader.read_line()
          parse_error("Escape at end of file.") if @reader.eof?

          @starting_escaped_quote_line = true

        else
          parse_error(
            "Malformed string literal - escape followed by whitespace " +
              "followed by non-whitespace.")
        end
      end

      def handle_character_literal
        @reader.skip_char # skip the starting quote

        parse_error("Got ' at end of line") if @reader.eol?

        c2 = @reader.read_char()

        if c2 == "\\"
          parse_error("Got '\\ at end of line") if @reader.eol?

          c3 = @reader.read_char()

          parse_error("Got '\\#{c3} at end of line") if @reader.eol?

          case c3
          when "\\"
            @tokens << Token.new("'\\'", @reader.line_no, @reader.pos)
          when "'"
            @tokens << Token.new("'''", @reader.line_no, @reader.pos)
          when "n"
            @tokens << Token.new("'\n'", @reader.line_no, @reader.pos)
          when "r"
            @tokens << Token.new("'\r'", @reader.line_no, @reader.pos)
          when "t"
            @tokens << Token.new("'\t'", @reader.line_no, @reader.pos)
          else
            parse_error("Illegal escape character #{@reader.current_char}")
          end

          if @reader.read_char != "'"
            expecting_but_got("single quote (')", "\"#{@reader.current_char}\"")
          end

        else
          @tokens << Token.new("'#{c2}'", @reader.line_no, @reader.pos)

          parse_error("Got '#{c2} at end of line") if @reader.eol?
          
          if @reader.read_char != "'"
            expecting_but_got(
              "quote (')", "\"#{@reader.current_char}\"", @reader.line_no, @reader.pos)
          end
        end
      end

      def handle_slash_comment
        if not @reader.more_chars_in_line?
          parse_error("Got slash (/) at end of line.")
        end

        if @reader.get_line_char(@reader.pos + 1) == "*"
          end_index = @reader.find_next_in_line("*/")
          if end_index
            # handle comment on same line
            @reader.skip_to(end_index + 1)
          else
            # handle multiline comments
            loop do
              @reader.read_raw_line()
              if @reader.eof?
                parse_error("/* comment not terminated.", @reader.line_no, -2)
              end

              end_index = @reader.find_next_in_line("*/", 0)

              if end_index
                @reader.skip_to(end_index + 1)
                break
              end
            end
          end
        elsif @reader.get_line_char(@reader.pos + 1) == "/"
          parse_error("Got slash (/) in unexpected location.")
        end
      end

      def handle_back_quote_string
        end_index = @reader.find_next_in_line("`")

        if end_index
          # handle end quote on same line
          @tokens << Token.new(@reader.substring(@reader.pos, end_index), @reader.line_no, @reader.pos)
          @token_text = nil
          @reader.skip_to(end_index)

        else
          @token_text = @reader.rest_of_line
          @token_start = @reader.pos
          # handle multiline quotes
          loop do
            @reader.read_raw_line()
            if @reader.eof?
              parse_error("` quote not terminated.", @reader.line_no, -2)
            end

            end_index = @reader.find_next_in_line("`", 0)
            if end_index
              @token_text << @reader.substring(0, end_index)
              @reader.skip_to(end_index)
              break
            else
              @token_text << @reader.line
            end
          end

          @tokens << Token.new(@token_text, @reader.line_no, @token_start)
          @token_text = nil
        end
      end

      def handle_binary_literal
        end_index = @reader.find_next_in_line("]")

        if end_index
          # handle end quote on same line
          @tokens << Token.new(@reader.substring(@reader.pos, end_index), @reader.line_no, @reader.pos)
          @token_text = nil
          @reader.skip_to(end_index)
        else
          @token_text = @reader.substring(@reader.pos)
          @token_start = @reader.pos
          # handle multiline quotes
          loop do
            @reader.read_raw_line()
            if @reader.eof?
              parse_error("[base64] binary literal not terminated.", @reader.line_no, -2)
            end

            end_index = @reader.find_next_in_line("]", 0)
            if end_index
              @token_text << @reader.substring(0, end_index)
              @reader.skip_to(end_index)
              break
            else
              @token_text << @reader.line
            end
          end

          @tokens << Token.new(@token_text, @reader.line_no, @token_start)
          @token_text = nil
        end
      end

      # handle a line continuation (not inside a string)
      def handle_line_continuation
        # backslash line continuation outside of a String literal
        # can only occur at the end of a line
        if not @reader.rest_of_line =~ /^\\\s*$/
          parse_error("Line continuation (\\) before end of line")
        else
          @line = @reader.read_line()
          unless @line
            parse_error("Line continuation at end of file.", @reader.line_no, @reader.pos)
          end
        end
      end

      def handle_number_date_or_time_span
        @token_start = @reader.pos
        @token_text = ""

        until @reader.eol?
          c = @reader.current_char

          if c =~ /[\w\.\-+:]/
            @token_text << c
          elsif c == "/" and not @reader.get_line_char(@reader.pos + 1) == "*"
            @token_text << c
          else
            @reader.previous_char()
            break
          end

          @reader.skip_char()
        end

        @tokens << Token.new(@token_text, @reader.line_no, @token_start)
        @token_text = nil
      end

      def handle_identifier
        @token_start = @reader.pos
        @token_text = ""

        until @reader.eol?
          c = @reader.current_char

          # FIXME here we are stricter than the Java version because there is no
          # easy way to implement Character.isJavaIdentifierPart() in Ruby :)
          if c =~ /[\w_$-\.]/
            @token_text << c
          else
            @reader.previous_char()
            break
          end

          @reader.skip_char()
        end

        @tokens << Token.new(@token_text, @reader.line_no, @token_start)
        @token_text = nil
      end

    end

  end
  
end
