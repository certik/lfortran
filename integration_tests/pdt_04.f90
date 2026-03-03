module pdt_04_m
  implicit none
  integer, parameter :: wp = 4
end module

module pdt_04_n
  use pdt_04_m, only : wp
  implicit none

  type t(k)
    integer, kind :: k = wp
    integer(kind=k) :: val
  end type

  interface
    module subroutine foo(x)
      type(t), intent(out) :: x
    end subroutine
  end interface
end module

program pdt_04
  use pdt_04_n
  implicit none
  type(t) :: x
  x%val = 42
  if (x%k /= 4) error stop
  if (x%val /= 42) error stop
  print *, "ok"
end program
