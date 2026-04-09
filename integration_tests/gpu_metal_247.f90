program gpu_metal_247
  implicit none
  type :: t
    real, allocatable :: v(:)
  end type
  integer :: i
  type(t) :: a(2, 4), r(4)
  do i = 1, 4
    allocate(a(1,i)%v(1))
    allocate(a(2,i)%v(1))
    a(1,i)%v(1) = real(i)
    a(2,i)%v(1) = real(i*10)
  end do
  do concurrent(i = 1:4)
    r(i) = a(1, i)
  end do
  if (abs(r(1)%v(1) - 1.0) > 1e-6) error stop
  if (abs(r(2)%v(1) - 2.0) > 1e-6) error stop
  if (abs(r(3)%v(1) - 3.0) > 1e-6) error stop
  if (abs(r(4)%v(1) - 4.0) > 1e-6) error stop
  print *, "PASS"
end program
