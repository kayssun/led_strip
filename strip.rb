#!/usr/bin/env ruby

require 'ws2801'
require './color.rb'

class Strip

	attr_accessor :direction, :last_event, :state, :current_set, :debug

	LENGTH = 320
	DIRECTION_NONE = 0
	DIRECTION_LEFT = 1
	DIRECTION_RIGHT = 2
	TIMEOUT = 12

	STATE_OFF = 0
	STATE_ON = 1
	STATE_STARTING_UP = 2
	STATE_SHUTTING_DOWN = 3
	
	def initialize
		WS2801.length(Strip::LENGTH)
		WS2801.autowrite(true)
		self_test
		@listen_thread = Thread.new { while true do check_timer; sleep 1; end }
		@last_event = Time.now - 3600 # set last event to a longer time ago
		@state = STATE_OFF
	end

	def on(direction)
		@last_event = Time.now
		puts "triggered event 'on': #{last_event.to_f}" if DEBUG
		return if @state != STATE_OFF

		@direction = direction
		@state = STATE_STARTING_UP

		puts "starting write: #{(Time.now - last_event).to_f}" if DEBUG
		
		# 5% chance to generate rainbow or random colors
		switch = rand(100)
		if switch > 94
			set = rainbow_set
		elsif switch > 89
			set = random_set
		else
			set = gradient_set(Color.random_from_set, Color.random_from_set)
		end	
		
		@state = write_set(set)

		puts "finishing write: #{(Time.now - last_event).to_f}" if DEBUG
	end

	def off(direction = nil)
		return unless @state == STATE_ON
		puts "triggered event 'off': #{Time.now.to_f}" if DEBUG
		@state = STATE_SHUTTING_DOWN
		@direction = direction if direction
		@state = write_set(simple_set(Color.new), false)
		puts "finished shutting off: #{Time.now.to_f}" if DEBUG
	end

	def shutdown
		WS2801.set(r: 0, g: 0, b: 0)
	end

	# red and blue are switched
	def write_set(set, on = true)
		@current_set = set if on
		if @direction == DIRECTION_RIGHT
			(LENGTH/2).times do |i|
				WS2801.set(set[i])
				# Check if timeout is still given
				if @state == STATE_SHUTTING_DOWN and not timeout?
					puts "canceling shutdown." if DEBUG
					return bounce(i+1, DIRECTION_RIGHT)
				end
			end
		elsif @direction == DIRECTION_LEFT
			(LENGTH/2).times do |i|
				WS2801.set(set[(LENGTH/2)-i-1])
				# Check if timeout is still given
				if @state == STATE_SHUTTING_DOWN and not timeout?
					puts "canceling shutdown." if DEBUG
					return bounce(i+1, DIRECTION_LEFT)
				end
			end
		end

		on ? STATE_ON : STATE_OFF
	end

	def bounce(i, direction)
		@last_event = Time.now

		if direction == DIRECTION_RIGHT
			puts "bouncing left" if DEBUG
			while i > -1 do
				WS2801.set(@current_set[i-=1])
			end
		else
			puts "bouncing right" if DEBUG
			i = LENGTH/2 - i - 1
			while i < (LENGTH/2 - 1) do
				WS2801.set(@current_set[i+=1])
			end
		end

		STATE_ON
	end

	# red and blue are switched
	def set_color_single(r,g,b)
		if @direction == DIRECTION_RIGHT
			LENGTH.times{|i| WS2801.set(pixel: i, r: b, g: g, b: r)}
		elsif @direction == DIRECTION_LEFT
			LENGTH.times{|i| WS2801.set(pixel:(LENGTH-1-i),r: b, g: g, b: r)}
		else
			WS2801.set(r: b, g: g, b: r)
		end
	end

	def simple_set(color)
		preset = []
		(LENGTH/2).times do |i|
			# red and blue are switched
			preset << {
				pixel: [i, LENGTH-1-i],
				r: color.b,
				g: color.g,
				b: color.r
			}
		end
		preset
	end

	def gradient_set(color_from, color_to)
		preset = []
		(LENGTH/2).times do |i|
			# red and blue are switched
			preset << {
				pixel: [i, LENGTH-1-i],
				r: between(color_from.b, color_to.b, i),
				g: between(color_from.g, color_to.g, i),
				b: between(color_from.r, color_to.r, i)
			}
		end
		preset
	end

	def random_set
		preset = []
		(LENGTH/2).times do |i|
			# red and blue are switched
			preset << {
				pixel: [i, LENGTH-1-i],
				r: rand(192),
				g: rand(192),
				b: rand(192)
			}
		end
		preset
	end

	def rainbow_set
		frequency = 0.06 * (160.0 / LENGTH)
		preset = []
		(LENGTH/2).times do |i|
			preset << {
				pixel: [i, LENGTH-1-i],
				g: (Math.sin(frequency*i + 0) * 127 + 128),
   				r: (Math.sin(frequency*i + 2) * 127 + 128),
   				b: (Math.sin(frequency*i + 4) * 127 + 128),
   			}
   		end
   		preset
	end

	def self_test
		WS2801.set(r: 0, g: 0, b: 255)
		sleep 1
		WS2801.set(r: 0, g: 255, b: 0)
		sleep 1
		WS2801.set(r: 255, g: 0, b: 0)
		sleep 1
		WS2801.set(r: 0, g: 0, b: 0)
	end

	def between(from, to, i)
		from + ((to - from) * i.to_f/(LENGTH.to_f/2)).to_i
	end

	def check_timer
		puts "state: #{@state}" if DEBUG
		self.off if timeout?
	end

	def timeout?
		@last_event < (Time.now - TIMEOUT)
	end

end