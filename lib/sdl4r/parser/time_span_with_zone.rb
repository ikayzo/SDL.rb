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

    # An intermediate object used to store a timeSpan or the time
    # component of a date/time instance. The types are disambiguated at a later stage.
    #
    # +seconds+ can have a fraction
    # +time_zone_offset+ is a fraction of a day (equal to nil if not specified)
    class TimeSpanWithZone # :nodoc: all

      private

        SECONDS_IN_DAY = 24 * 60 * 60

      public

      def initialize(day, hour, minute, second, time_zone_offset)
        @day = day
        @hour = hour
        @min = minute
        @sec = second
        @time_zone_offset = time_zone_offset
      end

      attr_reader :day, :hour, :min, :sec, :time_zone_offset

      # Returns the UTC offset as a fraction of a day on the current machine
      def TimeSpanWithZone.default_time_zone_offset
        return Rational(Time.now.utc_offset, SECONDS_IN_DAY)
      end

    end

  end

end
