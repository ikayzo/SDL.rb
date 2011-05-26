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

  class Parser

    # Gives access to the characters read to the Parser.
    # This class was designed to gather the handling of the UTF-8 issues in one place and shield the
    # Parser class from these problems.
    class Reader # :nodoc: all

      # +io+  an open IO from which the characters are read.
      def initialize(io)
        raise ArgumentError, "io == nil" unless io

        @io = io
        @line = nil
        @line_chars = nil
        @line_no = -1
        @pos = 0
      end

      # The current line no (zero-based)
      attr_reader :line_no

      # The position of the char currently pointed by this reader in the current line.
      # This is not necessarily the position of the char you just got from a method, it might be
      # the position of the next char, for instance.
      attr_reader :pos
      
      attr_reader :line

      def line_length
        return @line_chars.nil? ? 0 : @line_chars.length
      end

      # Reads next line in stream skipping comment lines and blank lines.
      #
      # Returns the next line or nil at the end of the file.
      def read_line
        @line_chars = nil

        while @line = read_raw_line()
          # Skip empty and commented lines
          break unless @line.empty? or @line =~ /^#/
        end

        return @line
      end

      # Returns the string that goes from the current position of this Reader to the end of the line
      # or nil if the current position doesn't allow that.
      def rest_of_line
        return @line[@pos..-1]
      end

      # Indicates whether the end of file has been reached.
      def eof?
        return @line.nil?
      end

      # Indicates whether there are more characters in the current line after the current char
      def more_chars_in_line?
        return @pos < line_length - 1
      end

      # Returns whether the end of the current +line+ as been reached.
      def eol?
        return @pos >= line_length
      end

      # Skips the current line by going just after its end.
      def skip_to_eol
        @pos = line_length
      end

      # Skips the whitespaces that follow the current position.
      def skip_whitespaces
        while (@pos + 1) < line_length and
            (@line[@pos + 1] == ?\s or @line[@pos + 1] == ?\t)
          @pos += 1
        end
      end

      # Returns the character at position +pos+ in the current line.
      # Returns nil if there is no current line or if +pos+ is after the end of the line.
      def get_line_char(pos)
        if @line_chars and pos < line_length
          return @line_chars[pos]
        else
          return nil
        end
      end

      # Returns the character at the current position or nil after end-of-line or end-of -file.
      def current_char
        return get_line_char(@pos)
      end

      # Go to the next character in the line. This method doesn't skip to the next line once the
      # reached eol.
      def skip_char
        @pos += 1 if @pos < line_length
      end

      # Returns the current char and go to the next.
      # Returns nil if end-of-line or -file has been reached.
      def read_char
        c = current_char
        skip_char()
        c
      end

      # Returns to the previous char if possible.
      def previous_char
        @pos -= 1 if @pos >= 1
      end

      # Returns the next index of the expression (string, regexp, fixnum) in the current line,
      # starting from after the current position if no position is specified.
      def find_next_in_line(searched, start_pos = nil)
        start_pos = @pos + 1 unless start_pos
        return @line.index(searched, start_pos)
      end

      # Skips the specified position in the current line.
      def skip_to(new_pos)
        @pos = new_pos
      end


      # Returns a subpart of the current line starting from +from+ and stopping at +to+ (excluded).
      def substring(from, to = -1)
        return @line[from..to]
      end

      # Reads and returns a "raw" line including lines with comments and blank lines.
      #
      # Returns the next line or nil if at the end of the file.
      #
      # This method changes the value of @line, @lineNo and @pos.
      def read_raw_line
        @line = @io.gets()

        # Remove a possible \r at the end of line
        @line.gsub!(/\r+$/, "") if @line

        @pos = 0;
        @line_chars = nil
        if @line
          @line_no += 1
          @line_chars = @line.scan(/./m)
        end
        return @line
      end

      # Closes this Reader and its underlying +IO+.
      def close
        @io.close
      end

    end
    
  end

end
