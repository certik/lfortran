! Test: scalar associate variables from enclosing scope must become
! direct kernel parameters, not pull the underlying array into the
! kernel.  Without the fix, associate(n => size(arr)) causes the GPU
! offload pass to inline size(arr) into the loop body, adding `arr`
! as a buffer parameter even though only the scalar size is needed.
! When arr is a derived-type array with allocatable components, the
! unnecessary buffer setup crashes on GPU.
program gpu_metal_256
implicit none

type :: inner_t
    real, allocatable :: vals(:)
end type

type :: item_t
    type(inner_t), allocatable :: nested(:)
end type

integer, parameter :: m = 4
type(item_t) :: items(m)
real :: x(m), expected(m)
integer :: i

! Initialize items (the array whose size is taken via associate)
do i = 1, m
    allocate(items(i)%nested(2))
    allocate(items(i)%nested(1)%vals(3))
    allocate(items(i)%nested(2)%vals(3))
    items(i)%nested(1)%vals = real(i)
    items(i)%nested(2)%vals = real(i) * 2.0
end do

x = 0.0
expected = [(real(i * m), i = 1, m)]

! The do concurrent is inside an associate that binds a scalar to
! size(items).  The loop body uses `n` (the scalar) but never
! accesses `items` directly.
associate(n => size(items))
    do concurrent(i = 1:m)
        x(i) = real(i) * real(n)
    end do
end associate

do i = 1, m
    if (abs(x(i) - expected(i)) > 1.0e-6) error stop
end do

print *, "PASS"
end program
