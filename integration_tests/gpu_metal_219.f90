program gpu_metal_219
! Test: function returning derived type with allocatable component
! called inside do concurrent. The function allocates the component.
implicit none
type :: t
  real, allocatable :: v(:)
end type
type(t), allocatable :: b(:)
integer :: i
allocate(b(4))
do concurrent(i = 1:4)
  b(i) = make(real(i))
end do
if (abs(b(1)%v(1) - 1.0) > 0.001) error stop 1
if (abs(b(2)%v(1) - 2.0) > 0.001) error stop 2
if (abs(b(3)%v(1) - 3.0) > 0.001) error stop 3
if (abs(b(4)%v(1) - 4.0) > 0.001) error stop 4
print *, "PASS"
contains
  pure function make(x) result(r)
    real, intent(in) :: x
    type(t) :: r
    allocate(r%v(1))
    r%v(1) = x
  end function
end program
