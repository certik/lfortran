program gpu_metal_228
implicit none

type :: t
  real, allocatable :: v(:)
end type

type :: s
  type(t) :: x
end type

type(t) :: a(2)
type(s) :: b(2)
integer :: i

a(1) = t([1.0, 2.0])
a(2) = t([3.0, 4.0])

do concurrent (i = 1:2)
  b(i)%x = a(i)
end do

if (size(b(1)%x%v) /= 2) error stop
if (abs(b(1)%x%v(1) - 1.0) > 0.001) error stop
if (abs(b(1)%x%v(2) - 2.0) > 0.001) error stop
if (size(b(2)%x%v) /= 2) error stop
if (abs(b(2)%x%v(1) - 3.0) > 0.001) error stop
if (abs(b(2)%x%v(2) - 4.0) > 0.001) error stop
print *, "PASS"

end program
