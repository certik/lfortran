module pdt_13_mod
  implicit none
  integer, parameter :: dp = kind(1.)

  type :: t(k)
    integer, kind :: k = dp
    real(k) :: x
    type(t(k)), allocatable :: next
  contains
    procedure :: sub
  end type

contains
  subroutine sub(self)
    class(t), intent(in) :: self
    if (abs(self%x) < 0.0) error stop
  end subroutine
end module

program pdt_13
  use pdt_13_mod
  implicit none

  type(t(dp)) :: head

  head%x = 3.14
  call head%sub()

  allocate(head%next)
  head%next%x = 2.72
  call head%next%sub()

  if (abs(head%x - 3.14) > 1.0e-5) error stop
  if (abs(head%next%x - 2.72) > 1.0e-5) error stop

  print *, "ok"
end program
