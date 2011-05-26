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

  # Represents a binary value.
  # 
  # This class was introduced to avoid the confusion between a Ruby String and a binary literal.
  #
  class SdlBinary

    attr_accessor :bytes

    # +value+: a String containing the bytes
    def initialize(bytes)
      @bytes = bytes
    end
    
    def ==(o)
      return true if self.equal?(o)
      return false if not o.instance_of?(self.class)
      return self.bytes == o.bytes
    end

    alias_method :eql?, :==

    def hash
      return bytes.hash
    end

    # Returns the bytes base64-encoded.
    def to_s
      return Base64.encode64(bytes)
    end

    # Decodes the specified base-64 encoded string and returns a corresponding SdlBinary
    # instance.
    # +s+ might not include the conventional starting and ending square brackets.
    def self.decode64(s)
      s = s.delete("\n\r\t ")

      binary = Base64.decode64(s)
      
      if binary.empty? and not s.empty?
        raise ArgumentError, "bad binary literal"
      end

      return SdlBinary.new(binary)
    end
  end

  # Try to coerce 'o' into a SdlBinary.
  # Raise an ArgumentError if it fails.
  def self.SdlBinary(o)
    if o.kind_of? SdlBinary
      return o
    elsif o.kind_of? String
      return SdlBinary.new(o)
    else
      raise ArgumentError, "can't coerce argument"
    end
  end
end