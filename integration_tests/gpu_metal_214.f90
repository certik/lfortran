program gpu_metal_214
  implicit none
  type :: dt
    real, allocatable :: v(:)
  end type
  type(dt) :: arr(2)
  real :: data(4)
  integer :: i

  data = [1.0, 2.0, 3.0, 4.0]

  do concurrent(i=1:2)
    arr(i)%v = data(2*i-1:2*i)
  end do

  if (size(arr(1)%v) /= 2) error stop
  if (size(arr(2)%v) /= 2) error stop
  if (abs(arr(1)%v(1) - 1.0) > 1e-6) error stop
  if (abs(arr(1)%v(2) - 2.0) > 1e-6) error stop
  if (abs(arr(2)%v(1) - 3.0) > 1e-6) error stop
  if (abs(arr(2)%v(2) - 4.0) > 1e-6) error stop
  print *, "ok"
end program
