submodule (separate_compilation_39a) separate_compilation_39b
  implicit none
contains
  module procedure greet
    msg = "Hello, " // trim(name)
  end procedure
end submodule
