program gpu_metal_213
! Test: assigning to an allocatable component of a derived type
! inside do concurrent with GPU Metal offloading.
implicit none
type :: dt_t
  real, allocatable :: v(:)
end type
type(dt_t), allocatable :: arr(:)
integer :: i

allocate(arr(3))
do i = 1, 3
  allocate(arr(i)%v(2))
end do
do concurrent(i = 1:3)
  arr(i)%v(1) = real(i)
  arr(i)%v(2) = real(i) * 2.0
end do

if (size(arr(1)%v) /= 2) error stop
if (size(arr(2)%v) /= 2) error stop
if (size(arr(3)%v) /= 2) error stop
if (abs(arr(1)%v(1) - 1.0) > 1e-6) error stop
if (abs(arr(1)%v(2) - 2.0) > 1e-6) error stop
if (abs(arr(2)%v(1) - 2.0) > 1e-6) error stop
if (abs(arr(2)%v(2) - 4.0) > 1e-6) error stop
if (abs(arr(3)%v(1) - 3.0) > 1e-6) error stop
if (abs(arr(3)%v(2) - 6.0) > 1e-6) error stop
print *, "PASS"
end program

