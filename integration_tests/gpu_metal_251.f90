program gpu_metal_251
! Test: do concurrent with elemental function returning derived type
! with allocatable component, passed to another function.
! Verifies nested allocatable companion data is correctly propagated
! in Metal GPU offloading.
implicit none

type :: dt_t
    real, allocatable :: v(:)
end type dt_t

type :: wrapper_t
    type(dt_t), allocatable :: items(:)
end type wrapper_t

integer :: i
integer, parameter :: n = 3
type(wrapper_t) :: res(n)
type(dt_t) :: x(1, n)

do i = 1, n
    allocate(x(1, i)%v(1))
    x(1, i)%v(1) = real(i)
end do

do concurrent (i = 1:n)
    res(i) = make_wrapper(copy_dt(x(:, i)))
end do

do i = 1, n
    if (.not. allocated(res(i)%items)) error stop
    if (.not. allocated(res(i)%items(1)%v)) error stop
    if (abs(res(i)%items(1)%v(1) - real(i)) > 1e-6) error stop
end do
print *, "PASS"

contains

elemental function copy_dt(a) result(r)
    type(dt_t), intent(in) :: a
    type(dt_t) :: r
    r%v = a%v
end function copy_dt

pure function make_wrapper(items) result(r)
    type(dt_t), intent(in) :: items(:)
    type(wrapper_t) :: r
    r%items = items
end function make_wrapper

end program gpu_metal_251
