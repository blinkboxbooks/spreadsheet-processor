# This monkey patch is here because [PR #149](https://github.com/Empact/roo/pull/149) hasn't been merged upstream yet
# and I can't figure out how to build roo locally without spending hours.
module Roo
  class Base
    def self.number_to_letter(n)
      letters=""
      if n > 26
        while n % 26 == 0 && n != 0
          letters << 'Z'
          n = ((n - 26) / 26).to_i
        end
        while n > 0
          num = n % 26
          letters = LETTERS[num-1] + letters
          n = (n / 26).to_i
        end
      else
        letters = LETTERS[n-1]
      end
      letters
    end
  end
end