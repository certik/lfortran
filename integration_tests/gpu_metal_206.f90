program gpu_metal_206
  implicit none
  integer :: i
  real, pointer :: p(:)
  real :: y(4)
  allocate(p(4))
  p = [1.0, 2.0, 3.0, 4.0]
  do concurrent(i=1:4)
    y(i) = double_first(p)
  end do
  if (abs(y(1) - 2.0) > 1e-6) error stop
  if (abs(y(2) - 2.0) > 1e-6) error stop
  if (abs(y(3) - 2.0) > 1e-6) error stop
  if (abs(y(4) - 2.0) > 1e-6) error stop
  print *, "ok"
  deallocate(p)
contains
  pure real function double_first(a)
    real, pointer, intent(in) :: a(:)
    double_first = a(1) * 2.0
  end function
end program
