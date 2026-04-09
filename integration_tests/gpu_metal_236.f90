program gpu_metal_236
! Test do concurrent with allocatable array of structs containing
! nested allocatable components (Metal GPU offloading).
implicit none

type :: inner_t
  real, allocatable :: v(:)
end type

type :: outer_t
  type(inner_t), allocatable :: items(:)
end type

integer, parameter :: n = 4
type(outer_t), allocatable :: arr(:)
type(inner_t) :: src(n)
integer :: i

do i = 1, n
  src(i) = inner_t([real :: i, 2*i])
end do

allocate(arr(n))
do concurrent(i = 1:n)
  arr(i) = outer_t([src(i)])
end do

do i = 1, n
  if (size(arr(i)%items) /= 1) error stop
  if (abs(arr(i)%items(1)%v(1) - real(i)) > 1e-6) error stop
  if (abs(arr(i)%items(1)%v(2) - real(2*i)) > 1e-6) error stop
end do

print *, "ok"
end program
