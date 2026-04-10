program gpu_metal_257
  implicit none
  integer :: i
  real :: w(2,2), a(2), r(2,2)
  real :: expected
  w = 0.1
  a = 0.5
  do concurrent (i = 1:2)
    r(:,i) = matmul(w, a) * a * a
  end do
  expected = 0.1 * 0.5 * 2 * 0.5 * 0.5
  if (abs(r(1,1) - expected) > 1.0e-6) error stop
  if (abs(r(2,1) - expected) > 1.0e-6) error stop
  if (abs(r(1,2) - expected) > 1.0e-6) error stop
  if (abs(r(2,2) - expected) > 1.0e-6) error stop
  print *, "ok"
end program
