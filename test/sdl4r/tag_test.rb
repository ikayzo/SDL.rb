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
  

  class TagTest < Test::Unit::TestCase

    public

    def test_initialize
      tag = Tag.new("tag1")
      assert_equal "tag1", tag.name, "name"
      assert_equal "", tag.namespace, "namespace"
      assert_equal 0, tag.child_count
      assert_equal false, tag.has_children?
      assert_equal [], tag.children
      assert_equal [], tag.values
      assert_equal Hash.new, tag.attributes

      tag = Tag.new("ns1", "tag1")
      assert_equal "tag1", tag.name, "name"
      assert_equal "ns1", tag.namespace, "namespace"

      # Check we can't pass garbage to the constructor
      assert_raise ArgumentError do
        Tag.new(1)
      end
      assert_raise ArgumentError do
        Tag.new("%@!")
      end
      assert_raise ArgumentError do
        Tag.new(1, "tag1")
      end
      assert_raise ArgumentError do
        Tag.new("%@!", "tag1")
      end

      # check the block idiom
      tag = Tag.new("ns1", "tag1") do
        self.name = "tag2"
        self.namespace = "ns2"
      end
      assert_equal "tag2", tag.name
      assert_equal "ns2", tag.namespace

      # check the block idiom with parameter
      tag = Tag.new("ns1", "tag1") do |t|
        t.name = "tag2"
        t.namespace = "ns2"
        t << self.class.name # self should be the test instance
      end
      assert_equal "tag2", tag.name
      assert_equal "ns2", tag.namespace
      assert_equal self.class.name, tag.value

      # check the same block+parameter idiom with new_child
      tag.new_child "ns3", "tag3" do |child|
        child.name = "tag4"
        child.namespace = "ns4"
        child.value = self.class.name
      end
      assert_equal "tag4", tag.child.name
      assert_equal "ns4", tag.child.namespace
      assert_equal self.class.name, tag.child.value
    end

    def test_children
      tag1 = nil
      tag2 = nil
      tag3 = nil
      tag4 = nil
      tag5_1 = nil
      tag5_2 = nil

      tag1 = Tag.new("tag1") do
        tag2 = new_child "ns1", "tag2" do
          tag3 = new_child "tag3"
        end
        tag4 = new_child "tag4" do
          tag5_1 = new_child "ns1", "tag5"
          tag5_2 = new_child "ns2", "tag5"
        end
      end

      assert_equal 2, tag1.child_count
      assert_equal tag2, tag1.child
      assert_equal tag2, tag1.child("tag2")
      assert tag1.has_child?("tag2")
      assert !tag1.has_child?("tag10")
      assert_equal tag2, tag1.children[0]
      assert_equal tag3, tag1.child(true, "tag3")
      assert_equal tag3, tag2.children[0]
      assert_equal 1, tag2.child_count
      assert tag2.has_children?
      assert_equal tag4, tag1.child("tag4")
      assert_equal tag4, tag1.children[1]
      assert_equal [tag5_1, tag5_2], tag4.children

      assert_equal [tag2, tag4], tag1.children(false)
      array = []
      tag1.children(false) { |child| array << child }
      assert_equal [tag2, tag4], array

      assert_equal [tag2, tag3, tag4, tag5_1, tag5_2], tag1.children(true)
      array = []
      tag1.children(true) { |child| array << child }
      assert_equal [tag2, tag3, tag4, tag5_1, tag5_2], array

      assert_equal [tag5_1, tag5_2], tag1.children(true, "tag5")
      array = []
      tag1.children(true, "tag5") { |child| array << child }
      assert_equal [tag5_1, tag5_2], array

      assert_equal [tag2, tag5_1], tag1.children(true, "ns1", nil)
      array = []
      tag1.children(true, "ns1", nil) { |child| array << child }
      assert_equal [tag2, tag5_1], array

      assert_equal [tag2], tag1.children(false, "ns1", nil)
      array = []
      tag1.children(false, "ns1", nil) { |child| array << child }
      assert_equal [tag2], array

      removed_tag = tag4.remove_child(tag5_1)
      assert_equal [tag5_2], tag4.children
      assert removed_tag

      removed_tag = tag1.remove_child(tag5_1)
      assert_equal [tag2, tag4], tag1.children
      assert !removed_tag

      tag1.clear_children
      assert_equal nil, tag1.child
      assert_equal [], tag1.children
    end

    def test_values
      tag1 = Tag.new "tag1"

      assert_equal nil, tag1.value
      assert_equal [], tag1.values

      tag1.values { fail "there should be no value" }

      tag1.values = [1]
      assert_equal 1, tag1.value
      assert_equal [1], tag1.values
      assert tag1.has_value?(1)
      assert !tag1.has_value?(2)

      tag1.values = [1, 2]
      assert_equal 1, tag1.value
      assert_equal [1, 2], tag1.values
      assert tag1.has_value?(1)
      assert tag1.has_value?(2)
      assert !tag1.has_value?(3)

      tag1.add_value(3)
      assert_equal 1, tag1.value
      assert_equal [1, 2, 3], tag1.values
      assert !tag1.has_value?(nil)

      tag1.value = nil
      assert_equal nil, tag1.value
      assert_equal [nil, 2, 3], tag1.values
      assert !tag1.has_value?(1)
      assert tag1.has_value?(nil)

      assert tag1.remove_value(2)
      assert !tag1.remove_value(2)
      assert_equal nil, tag1.value
      assert_equal [nil, 3], tag1.values

      tag1.add_value(nil)
      assert_equal nil, tag1.value
      assert_equal [nil, 3, nil], tag1.values
      assert !tag1.has_value?(2)
      assert tag1.has_value?(nil)

      tag1.remove_value(nil)
      assert_equal 3, tag1.value
      assert_equal [3, nil], tag1.values
      assert !tag1.has_value?(2)
      assert tag1.has_value?(3)
      assert tag1.has_value?(nil)
    end

    def test_stream_operator
      tag1 = Tag.new "tag1"

      tag1 << Tag.new("child")
      assert_equal [Tag.new("child")], tag1.children

      tag1.clear_children
      tag1 << Tag.new("tag1") << Tag.new("tag2") # test that all tags are added to tag1
      assert_equal [Tag.new("tag1"), Tag.new("tag2")], tag1.children

      tag1 << 123
      assert_equal [123], tag1.values
      tag1 << nil << "abc"
      assert_equal [123, nil, "abc"], tag1.values

      tag1.clear_values
      tag1 << ["def", 678, nil]
      assert_equal ["def", 678, nil], tag1.values

      tag1 << { "length" => 13 }
      assert_equal 13, tag1.attribute("length")
      tag1 << { "side:length" => 54, "top:length" => 67}
      assert_equal 13, tag1.attribute("length")
      assert_equal 54, tag1.attribute("side", "length")
      assert_equal 67, tag1.attribute("top", "length")

      # Test matrix construction
      tag1.clear_children
      tag1 << [[1, 2, 3], [4, 5, 6]]
      assert_equal "content", tag1.children[0].name
      assert_equal "content", tag1.children[1].name
      assert_equal [1, 2, 3], tag1.children[0].values
      assert_equal [4, 5, 6], tag1.children[1].values
      assert_equal 2, tag1.child_count

      # Test empty or nil attribute value
      tag1.clear_attributes
      tag1 << { "a1" => "" }
      tag1 << { "a2" => nil }
      assert_equal({ "a1" => "", "a2" => nil }, tag1.attributes)
    end

    def test_attributes
      tag = Tag.new("tag1")

      assert_equal 0, tag.attributes.size
      assert !tag.has_attribute?("a1")

      tag.set_attribute("a1", 1)
      assert_equal 1, tag.attribute("a1")
      assert_equal({"a1" => 1}, tag.attributes)
      assert tag.has_attribute?("a1")
      assert !tag.has_attribute?("a2")

      tag.set_attribute("a2", 2)
      assert_equal 1, tag.attribute("a1")
      assert_equal 1, tag.attribute("", "a1")
      assert_equal 2, tag.attribute("a2")
      assert_equal 2, tag.attribute("", "a2")
      assert_equal({"a1" => 1, "a2" => 2}, tag.attributes)

      tag.remove_attribute("a3") # nothing should change
      assert_equal({"a1" => 1, "a2" => 2}, tag.attributes)

      tag.remove_attribute("a1", "ns1") # nothing should change
      assert_equal({"a1" => 1, "a2" => 2}, tag.attributes)

      tag.set_attribute("ns1", "a1", 456)
      assert tag.has_attribute?("ns1", "a1")
      assert_equal 456, tag.attribute("ns1", "a1")

      tag.remove_attribute("a1")
      assert_nil tag.attribute("a1")
      assert tag.has_attribute?("ns1", "a1")
      assert_equal({"a2" => 2, "ns1:a1" => 456}, tag.attributes)

      tag.clear_attributes
      assert_nil tag.attribute("a2")
      assert_equal({}, tag.attributes)

      # test empty value
      tag.set_attribute("a1", "")
      assert_equal "", tag.attribute("a1")
    end

    def test_attributes_with_namespace
      tag = Tag.new "tag1"

      tag.set_attribute("", "a1", 1)
      tag.set_attribute("ns1", "a1", 2)
      assert_equal 1, tag.attribute("a1")
      assert_equal 2, tag.attribute("ns1", "a1")
      assert_equal nil, tag.attribute("ns2", "a1")

      tag.set_attribute("a1", 3)
      assert_equal 3, tag.attribute("a1")
      assert_equal 3, tag.attribute("", "a1")
      assert_equal 2, tag.attribute("ns1", "a1")
      assert_equal nil, tag.attribute("ns2", "a1")

      tag.set_attribute("ns2", "a1", 4)
      assert_equal 3, tag.attribute("a1")
      assert_equal 2, tag.attribute("ns1", "a1")
      assert_equal 4, tag.attribute("ns2", "a1")

      tag.set_attribute("ns1", "b1", 5)
      assert_equal({"a1" => 2, "b1" => 5}, tag.attributes("ns1"))
      assert_equal({"a1" => 4}, tag.attributes("ns2"))
      assert_equal({"a1" => 3}, tag.attributes(""))
      assert_equal({"a1" => 3, "ns1:a1" => 2, "ns2:a1" => 4, "ns1:b1" => 5}, tag.attributes)

      tag.remove_attribute("ns1", "a1")
      assert_equal nil, tag.attribute("ns1", "a1")

      tag.clear_attributes("")
      assert_equal({"ns2:a1" => 4, "ns1:b1" => 5}, tag.attributes)

      # test bad arguments
      assert_raise(ArgumentError) { tag.set_attribute "1", 123 }
      assert_raise(ArgumentError) { tag.set_attribute "&o^", 123 }
      assert_raise(ArgumentError) { tag.set_attribute "1", "a1", 123 }
      assert_raise(ArgumentError) { tag.set_attribute "&o^", "a1", 123 }
    end

    def test_set_attributes
      tag = Tag.new "tag1"

      tag.set_attributes({"a1" => 1})
      assert tag.has_attribute?("a1")
      assert_equal 1, tag.attribute("a1")
      assert_equal({"a1" => 1}, tag.attributes)

      tag.set_attributes({"a2" => 2, "a3" => 3})
      assert !tag.has_attribute?("a1")
      assert tag.has_attribute?("a2")
      assert tag.has_attribute?("a3")
      assert_equal nil, tag.attribute("a1")
      assert_equal 2, tag.attribute("a2")
      assert_equal 3, tag.attribute("a3")
      assert_equal({"a2" => 2, "a3" => 3}, tag.attributes)

      tag.set_attributes("ns1", {"a2" => 12, "a3" => 13})
      assert_equal 2, tag.attribute("a2")
      assert_equal 3, tag.attribute("a3")
      assert_equal 12, tag.attribute("ns1", "a2")
      assert_equal 13, tag.attribute("ns1", "a3")

      tag.set_attributes("", {}) # removes all attributes in the default namespace
      assert_equal({"ns1:a2" => 12, "ns1:a3" => 13}, tag.attributes)
    end

    def test_to_child_hash
      root = Tag.new("root") do
        (new_child "child1") << "abc"
        new_child "child2" do
          self << 123
          new_child "child2_1"
        end
        (new_child "child3") << nil << 456
      end

      assert_equal({"child1" => "abc", "child2" => 123, "child3" => nil}, root.to_child_hash)
    end

    def test_to_child_string_hash
      root = Tag.new("root") do
        (new_child "child1") << "abc"
        new_child "child2" do
          self << 123
          new_child "child2_1"
        end
        (new_child "child3") << nil << 456
      end

      assert_equal(
        {"child1" => "abc", "child2" => "123", "child3" => ""}, root.to_child_string_hash)
    end

    def test_eql?
      tag1 = Tag.new "node1"

      assert tag1.equal?(tag1)
      assert tag1.eql?(tag1)
      assert tag1 == tag1
      assert_equal tag1.hash, tag1.hash

      tag1_bis = Tag.new "node1"

      assert tag1.eql?(tag1_bis)
      assert tag1 == tag1_bis
      assert !(tag1.equal?(tag1_bis))
      assert_equal tag1.hash, tag1_bis.hash

      tag2 = Tag.new "node2"
      assert !(tag1.eql?(tag2))
      assert !(tag1 == tag2)
      assert !(tag1.equal?(tag2))
      assert_not_equal tag1.hash, tag2.hash

      tag1 = Tag.new "node1" do
        self << 123 << "abc" << nil
        self << {"length"=>45, "ns:length"=>100}
        new_child "child1"
        new_child "child2" do
          self << [[1,2], [3,4]]
        end
        new_child "child3"
      end

      assert tag1.eql?(tag1)
      assert tag1 == tag1
      assert_equal tag1.hash, tag1.hash
      assert tag1.equal?(tag1)

      tag1_bis = Tag.new "node1" do
        self << 123 << "abc" << nil
        self << {"length"=>45, "ns:length"=>100}
        new_child "child1"
        new_child "child2" do
          self << [[1,2], [3,4]]
        end
        new_child "child3"
      end

      assert tag1.eql?(tag1_bis)
      assert tag1 == tag1_bis
      assert !(tag1.equal?(tag1_bis))
      assert_equal tag1.hash, tag1_bis.hash

      tag2 = Tag.new "node1" do
        self << 123 << "abc" << nil
        self << {"length"=>45, "ns:length"=>101} # the difference is here
        new_child "child1"
        new_child "child2" do
          self << [[1,2], [3,4]]
        end
        new_child "child3"
      end

      tag2 = Tag.new "node2"
      assert !(tag1.eql?(tag2))
      assert !(tag1 == tag2)
      assert !(tag1.equal?(tag2))
      assert_not_equal tag1.hash, tag2.hash
     end

    def test_children_values
      root = Tag.new "root"

      assert_equal [], root.children_values
      assert_equal [], root.children_values("child1")

      root = SDL4R::read(<<EOF
child1 123 length=45.6
child2 2010/01/25 "abc"
child3
child4 null
child5 null null
EOF
      )

      assert_equal [], root.children_values("child0")
      assert_equal [123], root.children_values("child1")
      assert_equal [[Date.civil(2010, 01, 25), "abc"]], root.children_values("child2")
      assert_equal [nil], root.children_values("child3")
      assert_equal [nil], root.children_values("child4")
      assert_equal [[nil, nil]], root.children_values("child5")
      assert_equal [
        123,
        [Date.civil(2010, 01, 25), "abc"],
        nil,
        nil,
        [nil, nil]],
        root.children_values
    end

    # Tests the correctness of the generated XML (not the formatting).
    def test_to_xml_string
      _test_to_xml_string()
      _test_to_xml_string(:indent => " ")
      _test_to_xml_string(:indent => " ", :eol => "\r\n")
    end

    def _test_to_xml_string(options = {})
      tag = Tag.new "tag1"
      xml_doc = REXML::Document.new(tag.to_xml_string(options))
      assert_equal "tag1", xml_doc[0].name
      assert_equal "", xml_doc[0].namespace

      tag = Tag.new "ns1", "tag1"
      ns_options = {:uri_by_namespace => {"ns1" => "ns1"}}.merge(options)
      xml_doc = REXML::Document.new(tag.to_xml_string(ns_options))
      assert_equal "tag1", xml_doc[0].name
      assert_equal "ns1", xml_doc[0].namespace

      tag = Tag.new "tag1" do
        self << 123
      end
      xml_doc = REXML::Document.new(tag.to_xml_string(options))
      assert_equal "tag1", xml_doc[0].name
      assert_equal "123", xml_doc[0].attribute("_val0").value

      tag = Tag.new "tag1" do
        new_child "tag2" do
          self << {"a1" => 123}
        end
        new_child "tag3"
      end
      xml_doc = REXML::Document.new(tag.to_xml_string(options))
      assert_equal "tag1", xml_doc.elements[1].name
      assert_equal "tag2", xml_doc.elements[1].elements[1].name
      assert_equal "tag3", xml_doc.elements[1].elements[2].name
      assert_equal "123", xml_doc.elements[1].elements[1].attribute("a1").value
    end

    def test_to_xml_string_format
      root = Tag.new "tag1" do
        new_child "tag2"
        new_child "tag3"
      end

      assert_equal(
        "<tag1>\n" +
        "\t<tag2/>\n" +
        "\t<tag3/>\n" +
        "</tag1>",
        root.to_xml_string)
      assert_equal(
        "<tag1>\n" +
        "  <tag2/>\n" +
        "  <tag3/>\n" +
        "</tag1>",
        root.to_xml_string(:indent => "  "))
      assert_equal(
        "--<tag1>\n" +
        "--  <tag2/>\n" +
        "--  <tag3/>\n" +
        "--</tag1>",
        root.to_xml_string(:line_prefix => "--", :indent => "  "))
      assert_equal(
        "<tag1>\r\n" +
        "\t<tag2/>\r\n" +
        "\t<tag3/>\r\n" +
        "</tag1>",
        root.to_xml_string(:eol => "\r\n"))
    end

    def test_omit_null_attributes_xml_option
      root = Tag.new "tag1" do |tag|
        tag << { "a1" => 123, "a2" => nil }
      end

      assert_equal "<tag1 a1=\"123\" a2=\"null\"/>", root.to_xml_string
      assert_equal "<tag1 a1=\"123\"/>", root.to_xml_string(:omit_null_attributes => true)
    end

    def test_write
      root = Tag.new("root")

      output = ""
      root.write(output)
      assert_equal "", output

      output = ""
      root.write(output, true)
      assert_equal "root", output

      child1 = root.new_child "child1"
      child1 << 123

      output = ""
      root.write(output)
      assert_equal "child1 123", output

      output = ""
      root.write(output, true)
      assert_equal(
        "root {\n" +
        "\tchild1 123\n" +
        "}",
        output)

      child1 = root.new_child "child2"
      child1 << "abc"

      output = ""
      root.write(output)
      assert_equal "child1 123\nchild2 \"abc\"", output

      output = ""
      root.write(output, true)
      assert_equal(
        "root {\n" +
        "\tchild1 123\n" +
        "\tchild2 \"abc\"\n" +
        "}",
        output)
   end

  end

end
