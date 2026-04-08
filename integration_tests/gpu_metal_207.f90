program gpu_metal_207
  ! Test that do concurrent inside a loop does not leak Metal pipeline states.
  ! Previously, each invocation compiled a new shader variant, exceeding
  ! Metal's 16384 compiled variants limit.
  implicit none
  integer :: i, iter
  integer, parameter :: n = 10
  real :: a(n)
  a = 1.0
  do iter = 1, 20000
    do concurrent(i = 1:n)
      a(i) = a(i) + 1.0
    end do
  end do
  if (abs(sum(a) - 200010.0) > 1.0) error stop "wrong result"
  print *, "PASSED"
end program
