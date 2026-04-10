module gpu_metal_253_m
implicit none
type :: tensor_t
    real, allocatable :: v(:)
end type
contains
    pure function make(values) result(t)
        real, intent(in) :: values(:)
        type(tensor_t) :: t
        t%v = values
    end function
    pure function transform(x) result(y)
        type(tensor_t), intent(in) :: x
        type(tensor_t) :: y
        y = make([sum(x%v)])
    end function
end module

program gpu_metal_253
use gpu_metal_253_m
implicit none
type(tensor_t) :: a(4), b(4)
integer :: i

do i = 1, 4
    a(i) = make([real(i), real(i*10)])
end do

do concurrent(i=1:4)
    b(i) = transform(a(i))
end do

do i = 1, 4
    if (size(b(i)%v) /= 1) error stop
    if (abs(b(i)%v(1) - real(i + i*10)) > 1e-6) error stop
end do
print *, "ok"
end program
