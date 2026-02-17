submodule(submodule_24_mod) submodule_24_sub
  implicit none
contains

  module procedure from_chars
    res%val = s
  end procedure

  module procedure get_val
    res = self%val
  end procedure

end submodule
