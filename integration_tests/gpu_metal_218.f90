program gpu_metal_218
! Test struct constructor with allocatable array slice inside do concurrent.
! The allocatable struct member must be pre-allocated before the kernel
! writes data into it via a StructConstructor pattern.
implicit none
type :: t
    real, allocatable :: v(:)
end type
integer, parameter :: n = 4
type(t), allocatable :: arr(:)
real, allocatable :: x(:,:)
integer :: i

allocate(x(2, n), arr(n))
x = reshape([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0], [2, n])

do concurrent(i = 1:n)
    arr(i) = t(x(:, i))
end do

if (abs(arr(1)%v(1) - 1.0) > 1e-6) error stop
if (abs(arr(1)%v(2) - 2.0) > 1e-6) error stop
if (abs(arr(2)%v(1) - 3.0) > 1e-6) error stop
if (abs(arr(2)%v(2) - 4.0) > 1e-6) error stop
if (abs(arr(3)%v(1) - 5.0) > 1e-6) error stop
if (abs(arr(3)%v(2) - 6.0) > 1e-6) error stop
if (abs(arr(4)%v(1) - 7.0) > 1e-6) error stop
if (abs(arr(4)%v(2) - 8.0) > 1e-6) error stop
print *, "ok"
end program
