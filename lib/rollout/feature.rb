# frozen_string_literal: true

require 'zlib'

class Rollout
    class Feature
      attr_accessor :percentage
      attr_reader :name, :data

      RAND_BASE = (2**32 - 1) / 100.0
  
      def initialize(name, data={})
        @name = name
        @data = data
        @percentage = @data[:percentage]
      end
  
      def active?(determinator=nil)
        if determinator
          determinator_in_percentage?(determinator)
        else
          @percentage == 100
        end
      end

      def add_request
        if @data[:requests]
          @data[:requests] = @data[:requests] + 1
        else
          @data[:requests] = 1
        end
      end

      def add_error
        if @data[:errors]
          @data[:errors] = @data[:errors] + 1
        else
          @data[:errors] = 1
        end
      end

      def requests
        @data[:requests] || 0
      end

      def errors
        @data[:errors] || 0
      end
  
      private
  
      def determinator_in_percentage?(determinator)
        Zlib.crc32(determinator) < RAND_BASE * @percentage
      end
    end
  end