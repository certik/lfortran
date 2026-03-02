! Test sequence association: passing an array element to an
! explicit-shape array dummy argument.
module array_section_14_mod
  implicit none
contains
  subroutine callee(beta)
    real, intent(out) :: beta(2)
    beta(1) = 1.0
    beta(2) = 2.0
  end subroutine

  subroutine caller()
    real :: work(10)
    integer :: n
    n = 3
    work = 0.0
    ! Sequence association: work(n) maps to beta(1), work(n+1) maps to beta(2)
    call callee(work(n))
    if (abs(work(3) - 1.0) > 1e-6) error stop
    if (abs(work(4) - 2.0) > 1e-6) error stop
  end subroutine
end module

program array_section_14
  use array_section_14_mod
  call caller()
  print *, "ok"
end program
