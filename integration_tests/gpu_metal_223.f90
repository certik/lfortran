program gpu_metal_223
  implicit none
  type :: t
    real, allocatable :: v(:)
  end type
  type(t), allocatable :: a(:)
  real, allocatable :: h(:)
  integer :: i

  allocate(h(3))
  h(1) = 1.0
  h(2) = 2.0
  h(3) = 3.0
  allocate(a(2))
  do concurrent(i = 1:2)
    a(i)%v = h
  end do

  if (.not. allocated(a(1)%v)) error stop
  if (.not. allocated(a(2)%v)) error stop
  if (size(a(1)%v) /= 3) error stop
  if (size(a(2)%v) /= 3) error stop
  if (abs(a(1)%v(1) - 1.0) > 0.01) error stop
  if (abs(a(1)%v(2) - 2.0) > 0.01) error stop
  if (abs(a(1)%v(3) - 3.0) > 0.01) error stop
  if (abs(a(2)%v(1) - 1.0) > 0.01) error stop
  if (abs(a(2)%v(2) - 2.0) > 0.01) error stop
  if (abs(a(2)%v(3) - 3.0) > 0.01) error stop
  print *, "PASS"
end program
