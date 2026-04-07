module gpu_metal_198_mod
implicit none
type :: vec_t
    real, allocatable :: v(:)
contains
    procedure :: values => get_values
end type
contains
    pure function get_values(self) result(r)
        class(vec_t), intent(in) :: self
        real, allocatable :: r(:)
        r = self%v
    end function
end module

program gpu_metal_198
use gpu_metal_198_mod
implicit none
integer :: i
type(vec_t) :: a(2)
real :: s(2)
a(1)%v = [1.0, 2.0]
a(2)%v = [3.0, 4.0]
do concurrent (i = 1:2)
    s(i) = my_sum(a(i))
end do
print *, s
if (abs(s(1) - 3.0) > 1e-6) error stop
if (abs(s(2) - 7.0) > 1e-6) error stop
contains
    pure function my_sum(x) result(r)
        type(vec_t), intent(in) :: x
        real :: r
        r = sum(x%values())
    end function
end program
