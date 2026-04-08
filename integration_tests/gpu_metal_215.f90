module gpu_metal_215_m
implicit none
contains
  pure function f(x) result(y)
    real, intent(in) :: x
    real, allocatable :: y(:)
    y = [x]
  end function
end module

program gpu_metal_215
use gpu_metal_215_m
implicit none
real :: out(4)
real, allocatable :: tmp(:)
integer :: i

do concurrent(i = 1:4)
  tmp = f(real(i))
  out(i) = tmp(1)
end do

if (abs(out(1) - 1.0) > 1e-6) error stop
if (abs(out(2) - 2.0) > 1e-6) error stop
if (abs(out(3) - 3.0) > 1e-6) error stop
if (abs(out(4) - 4.0) > 1e-6) error stop
print *, "PASS"
end program
