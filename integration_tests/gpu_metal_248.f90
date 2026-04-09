program gpu_metal_248
! Test: do concurrent with elemental function returning struct with
! allocatable member, assigned via struct constructor to array of
! nested structs.  Verifies that companion buffer redirection works
! for elemental calls that pass whole arrays (not individual items).
implicit none

type :: dt_t
    real, allocatable :: v(:)
end type

type :: box_t
    type(dt_t), allocatable :: items(:)
end type

integer, parameter :: n = 4
type(box_t), allocatable :: arr(:)
type(dt_t), allocatable :: x(:,:)
integer :: i

allocate(x(1, n))
do i = 1, n
    x(1, i) = dt_t([real(i)])
end do

allocate(arr(n))
do concurrent(i = 1:n)
    arr(i) = box_t(id(x(:,i)))
end do

if (abs(arr(1)%items(1)%v(1) - 1.0) > 1e-6) error stop
if (abs(arr(2)%items(1)%v(1) - 2.0) > 1e-6) error stop
if (abs(arr(3)%items(1)%v(1) - 3.0) > 1e-6) error stop
if (abs(arr(4)%items(1)%v(1) - 4.0) > 1e-6) error stop
print *, "PASS"

contains

elemental function id(a) result(c)
    type(dt_t), intent(in) :: a
    type(dt_t) :: c
    c%v = a%v
end function

end program
