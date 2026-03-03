module pdt_07_mod
  implicit none

  integer, parameter :: sp = kind(1.)
  integer, parameter :: dp = kind(1d0)

  type :: inner_t(k)
    integer, kind :: k = sp
    real(k) :: val
  end type

  type :: outer_t(k)
    integer, kind :: k = sp
    type(inner_t(k)) :: comp
  end type

contains

  subroutine test_it(self, x)
    class(outer_t(dp)), intent(in) :: self
    real(dp), intent(out) :: x
    x = self%comp%val
  end subroutine

end module

program pdt_07
  use pdt_07_mod
  implicit none

  type(outer_t(dp)) :: obj
  real(dp) :: x
  obj%comp%val = 3.14_dp

  call test_it(obj, x)

  if (abs(x - 3.14_dp) > 1.0e-12_dp) error stop

  print *, "ok"
end program
