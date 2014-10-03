module Kernel
  def tic(label = :default)
    (@@timers ||= {})[label] = Time.now.utc.to_r
  end

  def toc(label = :default)
    return nil if @@timers[label].nil?
    (Time.now.utc.to_r - @@timers[label]) * 1000
  end
end