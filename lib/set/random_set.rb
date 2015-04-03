
require 'color'
require 'set/color_set'

class RandomSet < ColorSet

  def frame
    @set ||= generate_set
  end

  def pixel(number, _frame = 0)
    @set[number]
  end

  def generate_set
    length = type == :double ? Strip::LENGTH * 2 : Strip::LENGTH
    set = []
    length.times do
      set << Color.random
    end
    set
  end

end