! Test: generic type-bound procedure on a PDT accessed through a component chain
module pdt_09_mod
  implicit none

  type inner_t(k)
    integer, kind :: k = 4
  contains
    generic :: values => get_values
    procedure, private :: get_values
  end type

  type outer_t
    type(inner_t) :: comp
  end type

contains

  integer function get_values(self)
    class(inner_t), intent(in) :: self
    get_values = 42
  end function

  subroutine test_direct(y)
    type(inner_t), intent(in) :: y
    if (y%values() /= 42) error stop
  end subroutine

  subroutine test_chain(x)
    type(outer_t), intent(in) :: x
    if (x%comp%values() /= 42) error stop
  end subroutine

end module

program pdt_09
  use pdt_09_mod
  implicit none
  type(inner_t) :: y
  type(outer_t) :: x
  call test_direct(y)
  call test_chain(x)
  print *, "ok"
end program
