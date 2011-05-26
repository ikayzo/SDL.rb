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

  require 'test/unit'
  require "rexml/document"

  require File.dirname(__FILE__) + '/../../lib/sdl4r/tag'

  class SDLTest < Test::Unit::TestCase

    def test_coerce_or_fail
      # Most basic types are considered to be tested in other tests (like ParserTest)
      tag = Tag.new "tag1"
      assert_raise ArgumentError do tag.add_value(Object.new) end
      assert_raise ArgumentError do tag.add_value([1, 2, 3]) end
      assert_raise ArgumentError do tag.add_value({"a" => "b"}) end

      # check translation of Rational
      tag.add_value(Rational(3, 10))
      assert_equal [0.3], tag.values
    end
  end
end
