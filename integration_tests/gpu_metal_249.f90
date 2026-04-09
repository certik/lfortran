program gpu_metal_249
! Test: do concurrent calling a function that returns a derived type
! with an allocatable array of derived types that themselves have
! allocatable components.  Exercises nested VLA pre-allocation on the
! GPU offload path and companion buffer copy-back in Metal codegen.
implicit none
type :: inner_t
  real, allocatable :: vals(:)
end type
type :: outer_t
  type(inner_t), allocatable :: items(:)
end type
type(inner_t), allocatable :: arr(:)
type(outer_t), allocatable :: res(:)
integer :: i
allocate(arr(10))
do i = 1, 10
  arr(i) = inner_t([real(i), real(i*2)])
end do
allocate(res(10))
do concurrent(i = 1:10)
  res(i) = wrap([arr(i)])
end do
do i = 1, 10
  if (size(res(i)%items) /= 1) error stop
  if (size(res(i)%items(1)%vals) /= 2) error stop
  if (abs(res(i)%items(1)%vals(1) - real(i)) > 0.01) error stop
  if (abs(res(i)%items(1)%vals(2) - real(i*2)) > 0.01) error stop
end do
print *, "PASS"
contains
pure function wrap(items) result(o)
  type(inner_t), intent(in) :: items(:)
  type(outer_t) :: o
  o%items = items
end function
end program
