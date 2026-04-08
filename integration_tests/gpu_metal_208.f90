program gpu_metal_208
! Test: do concurrent with struct constructor containing allocatable member
! Verifies that allocating struct members inside a GPU kernel via
! StructConstructor works correctly on the Metal backend.
implicit none

type :: t
    real, allocatable :: v(:)
end type

type(t), allocatable :: arr(:)
real :: x(2, 3)
integer :: i

x(:, 1) = [1.0, 2.0]
x(:, 2) = [3.0, 4.0]
x(:, 3) = [5.0, 6.0]

allocate(arr(3))

do concurrent(i = 1:3)
    arr(i) = t(x(:, i) + 1.0)
end do

if (size(arr(1)%v) /= 2) error stop
if (size(arr(2)%v) /= 2) error stop
if (size(arr(3)%v) /= 2) error stop

if (abs(arr(1)%v(1) - 2.0) > 1e-6) error stop
if (abs(arr(1)%v(2) - 3.0) > 1e-6) error stop
if (abs(arr(2)%v(1) - 4.0) > 1e-6) error stop
if (abs(arr(2)%v(2) - 5.0) > 1e-6) error stop
if (abs(arr(3)%v(1) - 6.0) > 1e-6) error stop
if (abs(arr(3)%v(2) - 7.0) > 1e-6) error stop

print *, "ok"
end program
