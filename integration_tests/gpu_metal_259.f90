program gpu_metal_259
  implicit none
  real :: w(2,2), d(2), r(2)
  integer :: i
  w(1,1) = 1.0; w(1,2) = 2.0
  w(2,1) = 3.0; w(2,2) = 4.0
  d(1) = 1.0; d(2) = 1.0
  r = 0.0
  do concurrent (i = 1:2)
    r = matmul(w, d) * 2.0
  end do
  print *, r(1), r(2)
  if (abs(r(1) - 6.0) > 1e-6) error stop
  if (abs(r(2) - 14.0) > 1e-6) error stop
end program
