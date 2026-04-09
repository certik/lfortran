program gpu_metal_246
! Test: nested function call returning struct with allocatable component
! inside do concurrent.  make_outer calls copy_inner, both returning
! derived types with allocatable array members.  Validates that the
! Metal shader passes the correct number of arguments (data + size
! companions) for the result struct at the inner call site.
implicit none

type :: inner_t
    real, allocatable :: v(:)
end type

type :: outer_t
    type(inner_t) :: a
end type

integer, parameter :: n = 2
type(inner_t) :: src(n)
type(outer_t) :: dst(n)
integer :: i

do i = 1, n
    allocate(src(i)%v(1))
    src(i)%v(1) = real(i)
    allocate(dst(i)%a%v(1))
    dst(i)%a%v(1) = 0.0
end do

do concurrent(i = 1:n)
    dst(i) = make_outer(src(i))
end do

if (abs(dst(1)%a%v(1) - 1.0) > 0.001) error stop
if (abs(dst(2)%a%v(1) - 2.0) > 0.001) error stop
print *, "ok"

contains

pure function copy_inner(x) result(r)
    type(inner_t), intent(in) :: x
    type(inner_t) :: r
    r%v = x%v
end function

pure function make_outer(a) result(r)
    type(inner_t), intent(in) :: a
    type(outer_t) :: r
    r%a = copy_inner(a)
end function

end program
