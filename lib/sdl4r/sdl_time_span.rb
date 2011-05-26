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
  
  # Represents a period of time (duration) as opposed to a particular
  # moment in time (which would be represented using a Date, DateTime or Time
  # instance).
  #
  class SdlTimeSpan
    include Comparable
    
    private
    
    MILLISECONDS_IN_SECOND = 1000
    MILLISECONDS_IN_MINUTE = 60 * MILLISECONDS_IN_SECOND
    MILLISECONDS_IN_HOUR = 60 * MILLISECONDS_IN_MINUTE
    MILLISECONDS_IN_DAY = 24 * MILLISECONDS_IN_HOUR
    
    
    # Initializes an SdlTimeSpan using the total number of milliseconds in the
    # span.
    #
    def initialize_total_milliseconds(total_milliseconds)
      @totalMilliseconds = total_milliseconds
    end
    
    # Initializes an SdlTimeSpan defined by its day, hour, minute and
    # millisecond parts.
    # Note: if the timespan is negative all components should be negative.
    #
    def initialize_days_hours_minutes(days, hours, minutes, seconds = 0, milliseconds = 0)
      if seconds.is_a?(Rational)
        s = seconds.truncate
        milliseconds = milliseconds + ((seconds - s) * 1000).round
        seconds = s
      end

      @totalMilliseconds =
        days * MILLISECONDS_IN_DAY +
        hours * MILLISECONDS_IN_HOUR +
        minutes * MILLISECONDS_IN_MINUTE +
        seconds * MILLISECONDS_IN_SECOND +
        milliseconds
    end
    
    public
    
    # Create an SdlTimeSpan.  Note: if the timespan is negative all
    # components should be negative.
    # 
    #   SdlTimeSpan.new(days, hours, minutes, seconds = 0, milliseconds = 0)
    # 
    # or
    #
    #   SdlTimeSpan.new(totalMilliseconds)
    #
    def initialize(*args)
      if args.length == 1
        initialize_total_milliseconds(args[0])
      else
        initialize_days_hours_minutes(*args)
      end
    end

    # Returns the sign (-1 or +1) of this SdlTimeSpan.
    #
    def sign
      @totalMilliseconds <=> 0
    end

    # The days component.
    #
    def days
      sign * (@totalMilliseconds.abs / MILLISECONDS_IN_DAY)
    end
    alias_method :day, :days
    
    # The hours component.
    #
    def hours
      return sign * ((@totalMilliseconds - (days * MILLISECONDS_IN_DAY)).abs / MILLISECONDS_IN_HOUR)
    end
    alias_method :hour, :hours

    # The minutes component.
    #
    def minutes
      return sign *
        ((@totalMilliseconds - (days * MILLISECONDS_IN_DAY) - (hours * MILLISECONDS_IN_HOUR)).abs /
          MILLISECONDS_IN_MINUTE)
    end
    alias_method :min, :minutes
    
    # The seconds component.
    #
    def seconds
      return sign *
        ((@totalMilliseconds - (days * MILLISECONDS_IN_DAY) - (hours * MILLISECONDS_IN_HOUR) -
          (minutes * MILLISECONDS_IN_MINUTE)).abs /
            MILLISECONDS_IN_SECOND)
    end
    alias_method :sec, :seconds
    
    # The milliseconds component.
    #
    def milliseconds
      return @totalMilliseconds -
        (days * MILLISECONDS_IN_DAY) -
        (hours * MILLISECONDS_IN_HOUR) -
        (minutes * MILLISECONDS_IN_MINUTE) -
        (seconds * MILLISECONDS_IN_SECOND)
    end
    alias_method :usec, :milliseconds
    
    # Get the total number of hours in this time span.  For example, if
    # this time span represents two days, this method will return 48.
    #
    def total_hours
      return sign * (@totalMilliseconds.abs / MILLISECONDS_IN_HOUR)
    end
    
    # Get the total number of minutes in this time span.  For example, if
    # this time span represents two hours, this method will return 120.
    #
    def total_minutes
      return sign * (@totalMilliseconds.abs / MILLISECONDS_IN_MINUTE)
    end
    
    # Get the total number of seconds in this time span.  For example, if
    # this time span represents three minutes, this method will return 180.
    #
    def total_seconds
      return sign * (@totalMilliseconds.abs / MILLISECONDS_IN_SECOND)
    end
    
    # Get the total number of milliseconds in this time span.  For example, if
    # this time span represents 4 seconds, this method will return 4000.
    #
    def total_milliseconds
      return @totalMilliseconds
    end
    
    # Returns an new SdlTimeSpan instance that is the opposite of this
    # instance
    #
    def negate
      SdlTimeSpan.new(-@totalMilliseconds)
    end
    
    # Return a new instance with the days adjusted by the given amount.
    # Positive numbers add days. Negative numbers remove days.
    # 
    # +days+:: The adjustment (days to add or subtract)
    #
    def roll_days(days)
      SdlTimeSpan.new(@totalMilliseconds + (days * MILLISECONDS_IN_DAY))
    end
    
    # Return a new instance with the hours adjusted by the given amount.
    # Positive numbers add hours.  Negative numbers remove hours.
    # 
    # +hours+:: The adjustment (hours to add or subtract)
    #
    def roll_hours(hours)
      SdlTimeSpan.new(@totalMilliseconds + (hours * MILLISECONDS_IN_HOUR))
    end
    
    # Return a new instance with the minutes adjusted by the given amount.
    # Positive numbers add minutes.  Negative numbers remove minutes.
    # 
    # +minutes+:: The adjustment (minutes to add or subtract)
    #
    def roll_minutes(minutes)
      SdlTimeSpan.new(@totalMilliseconds + (minutes * MILLISECONDS_IN_MINUTE))
    end
    
    # Return a new instance with the seconds adjusted by the given amount.
    # Positive numbers add seconds.  Negative numbers remove seconds.
    # 
    # +seconds+:: The adjustment (seconds to add or subtract)
    #
    def roll_seconds(seconds)
      SdlTimeSpan.new(@totalMilliseconds + (seconds * MILLISECONDS_IN_SECOND))
    end
    
    # Return a new instance with the milliseconds adjusted by the given amount.
    # Positive numbers add milliseconds.  Negative numbers remove milliseconds.
    # 
    # +milliseconds+:: The adjustment (milliseconds to add or subtract)
    #
    def roll_milliseconds(milliseconds)
      SdlTimeSpan.new(@totalMilliseconds + milliseconds)
    end
    
    # A hashcode based on the canonical string representation.
    #
    def hash
      to_s.hash
    end
    
    # Tests for equivalence.
    #
    def eql?(other)
      other.is_a?(SdlTimeSpan) and @totalMilliseconds == other.total_milliseconds
    end
    
    # define '==' as 'eql?'
    alias_method :==, :eql?

    def <=>(other)
      @totalMilliseconds <=> other.total_milliseconds
    end
    
    # Returns an SDL representation of this time span using the format:
    # 
    #   (days:)hours:minutes:seconds(.milliseconds)
    # 
    # (parenthesis indicate optional components)
    # 
    # The days and milliseconds components will not be included if they 
    # are set to 0.  Days must be suffixed with "d" for clarity.
    # 
    # Hours, minutes, and seconds will be zero paded to two characters.
    # 
    # Examples:
    # 
    #     23:13:00 (12 hours and 13 minutes)
    #     24d:12:13:09.234 (24 days, 12 hours, 13 minutes, 9 seconds,
    #         234 milliseconds)
    #
    def to_s
      _days = days
      _milliseconds = milliseconds
      
      s = nil
      if _days == 0
        if _milliseconds == 0
          s = sprintf("%d:%02d:%02d", hours, minutes.abs, seconds.abs)
        else
          s = sprintf("%d:%02d:%02d.%03d", hours, minutes.abs, seconds.abs, _milliseconds.abs)
        end
      else
        if _milliseconds == 0
          s = sprintf("%dd:%02d:%02d:%02d", _days, hours.abs, minutes.abs, seconds.abs)
        else
          s = sprintf(
            "%dd:%02d:%02d:%02d.%03d",
            _days,
            hours.abs,
            minutes.abs,
            seconds.abs,
            _milliseconds.abs)
        end
      end
      return s
    end
  end
end
