program gpu_metal_235
implicit none

type :: leaf_t
  real, allocatable :: v(:)
end type

type :: mid_t
  type(leaf_t) :: x
end type

type :: top_t
  type(mid_t), allocatable :: items(:)
end type

integer, parameter :: n = 2
type(leaf_t) :: data(n)
type(top_t) :: arr(n)
integer :: i

do i = 1, n
  data(i) = leaf_t([real :: i, i+1])
end do

do concurrent(i = 1:n)
  arr(i) = top_t([mid_t(data(i))])
end do

if (size(arr(1)%items(1)%x%v) /= 2) error stop
if (any(arr(1)%items(1)%x%v /= [1.0, 2.0])) error stop
if (size(arr(2)%items(1)%x%v) /= 2) error stop
if (any(arr(2)%items(1)%x%v /= [2.0, 3.0])) error stop
print *, "ok"
end program
