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
  
  require File.dirname(__FILE__) + '/time_span_with_zone'

  class Parser

    # An SDL token.
    #
    # @author Daniel Leuck, Philippe Vosges
    #
    class Token # :nodoc: all

      def initialize(text, line = -1, position = -1)
        @text = text
        @line = line
        @position = position
        @size = text.length

        begin
          @type = nil
          @object = nil

          if text =~ /^["`]/
            @type = :STRING
            @object = Parser.parse_string(text)

          elsif text =~ /^'/
            @type = :CHARACTER
            @object = text[1...-1]

          elsif text == "null"
            @type = :NULL
            @object = nil

          elsif text =~ /^true$|^on$/
            @type = :BOOLEAN
            @object = true

          elsif text =~ /^false$|^off$/
            @type = :BOOLEAN
            @object = false

          elsif text =~ /^\[/
            @type=:BINARY
            @object = Parser.parse_binary(text)

          elsif text =~ /^\d+\/\d+\/\d+$/
            @type = :DATE;
            @object = Parser.parse_date_time(text)

          elsif text =~ /^-?\d+d?:\d+/
            @type = :TIME
            @object = parse_time_span_with_zone(text)

          elsif text =~ /^[\d\-\.]/
            @type = :NUMBER
            @object = Parser.parse_number(text)

          else
            case text[0]
            when ?{
              @type = :START_BLOCK
            when ?}
              @type = :END_BLOCK
            when ?=
              @type = :EQUALS
            when ?:
              @type = :COLON
            when ?;
              @type = :SEMICOLON
            end
          end

        rescue ArgumentError
          raise SdlParseError.new($!.message, @line, @position)
        end

        @type = :IDENTIFIER if @type.nil? # if all hope is lost, it's an identifier

        @punctuation =
          @type == :COLON || @type == :SEMICOLON || @type == :EQUALS ||
          @type == :START_BLOCK || @type == :END_BLOCK
        @literal = @type != :IDENTIFIER && !@punctuation
      end

      attr_reader :text, :type, :line, :position

      def literal?
        @literal
      end

      # Returns the Ruby object corresponding to this literal (or nil if it is
      # not a literal).
      def object_for_literal
        return @object
      end

      def to_s
        @type.to_s + " " + @text + " pos:" + @position.to_s
      end

      # This special parse method is used only by the Token class for
      # tokens which are ambiguously either a TimeSpan or the time component
      # of a date/time type
      def parse_time_span_with_zone(literal)
        raise ArgumentError("time span or date literal is nil") if literal.nil?

        days, hours, minutes, seconds, time_zone_offset =
          Parser.parse_time_span_and_time_zone(literal, true, true)

        return Parser::TimeSpanWithZone.new(days, hours, minutes, seconds, time_zone_offset)
      end
      
    end

  end
  
end
