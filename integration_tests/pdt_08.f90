! Test type-bound procedures on parameterized derived types (PDTs)
module pdt_08_mod
  implicit none

  integer, parameter :: dp = kind(1.)

  type :: inner_t(k)
    integer, kind :: k = dp
    real(k) :: val
  contains
    procedure :: get_val => inner_get_val
    procedure :: set_val => inner_set_val
  end type

contains

  integer function inner_get_val(self)
    class(inner_t), intent(in) :: self
    inner_get_val = int(self%val)
  end function

  subroutine inner_set_val(self, v)
    class(inner_t), intent(inout) :: self
    real(dp), intent(in) :: v
    self%val = v
  end subroutine

end module

program pdt_08
  use pdt_08_mod
  implicit none

  type(inner_t) :: x
  integer :: r

  call x%set_val(42.0)
  r = x%get_val()
  if (r /= 42) error stop

  print *, "ok"
end program
