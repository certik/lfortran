! Test: submodule referencing parent module's implied-shape character
! parameter whose len= uses len("...") should not cause ICE.
module submodule_37_m
  implicit none
  character(len=*), parameter :: names(*) = [character(len=len("ab")) :: "ab"]

  interface
    module subroutine print_name()
    end subroutine
  end interface
end module

submodule(submodule_37_m) submodule_37_s
  implicit none
contains
  module procedure print_name
    if (names(1) /= "ab") error stop
    print *, names(1)
  end procedure
end submodule

program submodule_37
  use submodule_37_m
  implicit none
  call print_name()
end program
