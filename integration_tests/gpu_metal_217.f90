program gpu_metal_217
  implicit none

  type :: dt
    real, allocatable :: x(:)
  end type

  type(dt) :: a(1)
  real :: h(2)
  integer :: i

  h = 1.0

  do concurrent(i = 1:1)
    a(i) = dt(h(:))
  end do

  if (size(a(1)%x) /= 2) error stop
  if (a(1)%x(1) /= 1.0) error stop
  if (a(1)%x(2) /= 1.0) error stop

  print *, "ok"
end program
