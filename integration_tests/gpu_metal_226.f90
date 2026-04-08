module gpu_metal_226_m
implicit none
type :: inner_t
    real, allocatable :: v(:)
end type
type :: outer_t
    type(inner_t), allocatable :: items(:)
end type
contains
pure function make_inner(v) result(r)
    real, intent(in) :: v(:)
    type(inner_t) :: r
    r%v = v
end function
pure function make_outer(x) result(r)
    type(inner_t), intent(in) :: x(:)
    type(outer_t) :: r
    r%items = x
end function
end module

program gpu_metal_226
! Test nested struct constructors with allocatable components inside
! do concurrent. The outer struct contains an allocatable array of inner
! structs, each with an allocatable real array.
use gpu_metal_226_m
implicit none
integer, parameter :: n = 3
type(outer_t) :: a(n)
real :: d(2, n)
integer :: i

d(:,1) = [1.0, 2.0]
d(:,2) = [3.0, 4.0]
d(:,3) = [5.0, 6.0]

do concurrent (i = 1:n)
    a(i) = make_outer([make_inner(d(:, i))])
end do

if (abs(a(1)%items(1)%v(1) - 1.0) > 1e-6) error stop
if (abs(a(1)%items(1)%v(2) - 2.0) > 1e-6) error stop
if (abs(a(2)%items(1)%v(1) - 3.0) > 1e-6) error stop
if (abs(a(2)%items(1)%v(2) - 4.0) > 1e-6) error stop
if (abs(a(3)%items(1)%v(1) - 5.0) > 1e-6) error stop
if (abs(a(3)%items(1)%v(2) - 6.0) > 1e-6) error stop
print *, "ok"
end program
