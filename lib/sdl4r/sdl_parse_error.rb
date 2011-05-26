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
	#
	# An exception describing a problem with an SDL document's structure
	#
	class SdlParseError < StandardError
	
		#
		# Note: Line and positioning numbering start with 1 rather than 0 to be
		# consistent with most editors.
		# 
		# +description+ A description of the problem.
		# +lineNo+ The line on which the error occured or -1 for unknown
		# +position+ The position (within the line) where the error occured or -1 for unknown
		#
		def initialize(description, line_no, position, line = nil)
			super(
				"#{description} Line " + ((line_no.nil? or line_no < 0)? "unknown" : line_no.to_s) +
					", Position " + ((position.nil? or position < 0)? "unknown" : position.to_s) + $/ +
          (line ? line + (position ? " " * (position - 1) : "") + "^" : ""))
          
			@line = line_no
			@position = position
		end
		
		attr_reader :line
		attr_reader :position
	end
end
